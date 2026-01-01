#!/bin/sh
set -e

PE_ROOT="/media/project_eris"
PE_ETC="${PE_ROOT}/etc/project_eris"
PE_OPT="${PE_ROOT}/opt/retroarch"
PE_GAMES="/media/games"

DB_BLEEM="${PE_ETC}/SYS/databases/BleemSync.db"
DB_REGIONAL="${PE_ETC}/SYS/databases/regional.db"

STATE_DIR="${PE_ETC}/SUP/drive2_mod"
STATE_FILE="${STATE_DIR}/state.conf"

log() { echo "[drive2-mod][uninstall] $*"; }

need_bin() { command -v "$1" >/dev/null 2>&1 || { log "Missing required binary: $1"; exit 1; }; }
need_bin sqlite3
need_bin rm
need_bin cp
need_bin mv
need_bin ls
need_bin head
need_bin sed

if [ ! -f "${STATE_FILE}" ]; then
  log "No state file found at ${STATE_FILE}. Nothing to uninstall."
  exit 0
fi

load_state() {
  file="$1"

  GAME_ID=""
  NODE_ID=""
  TITLE=""
  BASENAME=""
  CREATED_RA_MODULES_DIR="0"
  INSTALLED=0

  while IFS= read -r line || [ -n "$line" ]; do
    [ -z "$line" ] && continue
    case "$line" in \#*) continue ;; esac

    case "$line" in *=*)
      key=${line%%=*}
      val=${line#*=}
      ;;
    *) continue ;;
    esac

    key=$(printf "%s" "$key" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    val=$(printf "%s" "$val" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

    case "$key" in
      INSTALLED|TIMESTAMP|GAME_ID|NODE_ID|TITLE|BASENAME|CREATED_RA_MODULES_DIR)
        eval "$key=\"\$val\""
        ;;
      INSTALLED_*)
        safe_key=$(printf "%s" "$key" | sed 's/[^A-Za-z0-9_]/_/g')
        if [ "$safe_key" = "$key" ]; then
          case "$val" in 0|1) eval "$key=$val" ;; esac
        fi
        ;;
    esac
  done < "$file"
}

load_state "${STATE_FILE}"

TITLE="${TITLE:-PlayStation Format Disc}"
BASENAME="${BASENAME:-drive2}"

TITLE_SQL="$(printf "%s" "${TITLE}" | sed "s/'/''/g")"
BASENAME_SQL="$(printf "%s" "${BASENAME}" | sed "s/'/''/g")"

restore_latest_backup() {
  base="$1"
  target="$2"
  latest="$(ls -1t "${STATE_DIR}/${base}.bak."* 2>/dev/null | head -n 1 || true)"
  [ -f "$latest" ] && cp -f "$latest" "$target" && log "Restored ${target}"
}

restore_latest_backup "intercept" "${PE_ETC}/SUP/scripts/intercept"
restore_latest_backup "0030_retroarch.funcs" "${PE_ETC}/FUNC/0030_retroarch.funcs"

rm_if_installed() {
  rel="$1"
  dst="$2"
  safe_key="$(printf "%s" "$rel" | sed 's/[^A-Za-z0-9_]/_/g')"
  eval val="\${INSTALLED_${safe_key}:-0}"
  [ "$val" = "1" ] && [ -f "$dst" ] && rm -f "$dst" && log "Removed ${dst}"
}

rm_if_installed "modules/cdrom.ko" "${PE_OPT}/modules/cdrom.ko"
rm_if_installed "modules/sg.ko" "${PE_OPT}/modules/sg.ko"
rm_if_installed "modules/sr_mod.ko" "${PE_OPT}/modules/sr_mod.ko"
rm_if_installed "cores/pcsx_rearmed_discproject.so" "${PE_OPT}/config/retroarch/cores/pcsx_rearmed_discproject.so"
rm_if_installed "theme/ra_drive2_error.png" "${PE_ETC}/THEME/stock/menu_files/ra_drive2_error.png"
rm_if_installed "theme/ra_drive2_invalid_disc.png" "${PE_ETC}/THEME/stock/menu_files/ra_drive2_invalid_disc.png"
rm_if_installed "config/ra-game-cdrom.cfg" "${PE_OPT}/config/retroarch/ra-game-cdrom.cfg"

[ -f "${PE_OPT}/config/retroarch/config/PCSX-ReARMed/drive2.opt" ] && rm -f "${PE_OPT}/config/retroarch/config/PCSX-ReARMed/drive2.opt"
[ -f "${PE_OPT}/saves/drive2.srm" ] && rm -f "${PE_OPT}/saves/drive2.srm"

if [ -d "${PE_OPT}/modules" ]; then
  only_known=1
  for f in "${PE_OPT}/modules/"*; do
    [ -e "$f" ] || continue
    case "$(basename "$f")" in cdrom.ko|sg.ko|sr_mod.ko) ;; *) only_known=0 ;; esac
  done
  [ "$only_known" -eq 1 ] && rm -rf "${PE_OPT}/modules" && log "Removed RetroArch modules directory"
fi

if [ -n "$GAME_ID" ] && [ -d "${PE_GAMES}/${GAME_ID}" ]; then
  rm -rf "${PE_GAMES:?}/${GAME_ID}"
  log "Removed launcher folder ${GAME_ID}"
fi

# Remove regional entries
sqlite3 "${DB_REGIONAL}" "DELETE FROM DISC WHERE BASENAME='${BASENAME_SQL}';"
sqlite3 "${DB_REGIONAL}" "DELETE FROM MENU_ENTRIES WHERE GAME_TITLE_STRING='${TITLE_SQL}';"
log "Removed regional.db entries"

# Remove BleemSync entries robustly:
# - by Name
# - AND by drive2 file paths (handles title mismatch / stale nodes)
NODE_IDS="$(sqlite3 "${DB_BLEEM}" "SELECT Id FROM GameManagerNodes WHERE Name='${TITLE_SQL}';")"
for nid in $NODE_IDS; do
  sqlite3 "${DB_BLEEM}" "DELETE FROM GameManagerFiles WHERE NodeId=${nid};"
done
sqlite3 "${DB_BLEEM}" "DELETE FROM GameManagerFiles WHERE Path LIKE '%/drive2.cue' OR Path LIKE '%/drive2.png' OR Path LIKE '%/Game.ini';"
sqlite3 "${DB_BLEEM}" "DELETE FROM GameManagerNodes WHERE Name='${TITLE_SQL}';"
log "Removed BleemSync.db entries"

# Rebuild menu ordering + folders
TMP_IDS="/tmp/pe_menu_ids.txt"
rm -f "${TMP_IDS}" || true

sqlite3 "${DB_REGIONAL}" <<EOF
.mode list
.output ${TMP_IDS}
SELECT GAME_ID FROM MENU_ENTRIES ORDER BY GAME_ID;
.output stdout
EOF

new_id=1
while read -r old_id; do
  [ -z "$old_id" ] && continue
  if [ "$old_id" != "$new_id" ]; then
    [ -d "${PE_GAMES}/${old_id}" ] && mv "${PE_GAMES}/${old_id}" "${PE_GAMES}/${new_id}"
    sqlite3 "${DB_REGIONAL}" "UPDATE MENU_ENTRIES SET GAME_ID=${new_id} WHERE GAME_ID=${old_id};"
    sqlite3 "${DB_REGIONAL}" "UPDATE DISC SET GAME_ID=${new_id} WHERE GAME_ID=${old_id};"
  fi
  new_id=$((new_id + 1))
done < "${TMP_IDS}"

rm -f "${TMP_IDS}"
log "Rebuilt game slot ordering"

rm -f "${PE_ETC}/SYS/databases/"*.bak* || true
log "Removed database backup files"

rm -rf "${STATE_DIR}"
log "Removed mod state directory"

log "Uninstall complete."
exit 0
