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
need_bin ls
need_bin head
need_bin sed

if [ ! -f "${STATE_FILE}" ]; then
  log "No state file found at ${STATE_FILE}. Nothing to uninstall."
  exit 0
fi

# Robustly load state.conf even if it contains unexpected/unsafe lines.
# We only accept simple KEY=VALUE assignments for known keys and INSTALLED_* flags.
load_state() {
  file="$1"

  GAME_ID=""
  NODE_ID=""
  TITLE=""
  BASENAME=""
  CREATED_RA_MODULES_DIR="0"

  # shellcheck disable=SC2034
  INSTALLED=0

  # Read line-by-line to avoid executing arbitrary content.
  while IFS= read -r line || [ -n "$line" ]; do
    # skip empty lines and comments
    [ -z "$line" ] && continue
    case "$line" in
      \#*) continue ;;
    esac

    # Only allow KEY=VALUE format
    case "$line" in
      *=*)
        key=${line%%=*}
        val=${line#*=}
        ;;
      *)
        continue
        ;;
    esac

    # Trim whitespace around key
    key=$(printf "%s" "$key" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    # Trim leading/trailing whitespace for val (keep interior spaces)
    val=$(printf "%s" "$val" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

    # Accept only known keys and INSTALLED_* flags with safe key names
    case "$key" in
      INSTALLED|TIMESTAMP|GAME_ID|NODE_ID|TITLE|BASENAME|CREATED_RA_MODULES_DIR)
        case "$key" in
          INSTALLED) INSTALLED="$val" ;;
          TIMESTAMP) TIMESTAMP="$val" ;;
          GAME_ID) GAME_ID="$val" ;;
          NODE_ID) NODE_ID="$val" ;;
          TITLE) TITLE="$val" ;;
          BASENAME) BASENAME="$val" ;;
          CREATED_RA_MODULES_DIR) CREATED_RA_MODULES_DIR="$val" ;;
        esac
        ;;
      INSTALLED_*)
        # Only accept safe variable names (alnum + underscore)
        safe_key=$(printf "%s" "$key" | sed 's/[^A-Za-z0-9_]/_/g')
        if [ "$safe_key" = "$key" ]; then
          case "$val" in
            0|1)
              # We do need eval here to assign a dynamic *safe* var name.
              eval "${key}=${val}"
              ;;
          esac
        fi
        ;;
      *)
        # ignore anything else
        ;;
    esac
  done < "$file"
}

load_state "${STATE_FILE}"

TITLE="${TITLE:-PlayStation Format Disc}"
BASENAME="${BASENAME:-drive2}"

# Escape single quotes for SQL
TITLE_SQL="$(printf "%s" "${TITLE}" | sed "s/'/''/g")"
BASENAME_SQL="$(printf "%s" "${BASENAME}" | sed "s/'/''/g")"

# 1) Restore backups if present (latest backup wins)
restore_latest_backup() {
  base="$1"
  target="$2"
  latest="$(ls -1t "${STATE_DIR}/${base}.bak."* 2>/dev/null | head -n 1)"
  if [ -n "${latest}" ] && [ -f "${latest}" ]; then
    cp -f "${latest}" "${target}"
    log "Restored ${target} from ${latest}"
  else
    log "No backup found for ${target} (skipping restore)"
  fi
}

restore_latest_backup "intercept" "${PE_ETC}/SUP/scripts/intercept"
restore_latest_backup "0030_retroarch.funcs" "${PE_ETC}/FUNC/0030_retroarch.funcs"

# 2) Remove optional extras ONLY if we installed them
# NOTE: Installer writes flags like INSTALLED_modules_cdrom_ko=1 (sanitized).
rm_if_installed() {
  rel="$1"
  dst="$2"
  safe_key="$(printf "%s" "$rel" | sed 's/[^A-Za-z0-9_]/_/g')"
  key="INSTALLED_${safe_key}"
  eval val="\${${key}:-0}"
  if [ "${val}" = "1" ] && [ -f "${dst}" ]; then
    rm -f "${dst}"
    log "Removed ${dst}"
  fi
}

rm_if_installed "modules/cdrom.ko" "${PE_OPT}/modules/cdrom.ko"
rm_if_installed "modules/sg.ko" "${PE_OPT}/modules/sg.ko"
rm_if_installed "modules/sr_mod.ko" "${PE_OPT}/modules/sr_mod.ko"
rm_if_installed "cores/pcsx_rearmed_discproject.so" "${PE_OPT}/config/retroarch/cores/pcsx_rearmed_discproject.so"
rm_if_installed "theme/ra_drive2_error.png" "${PE_ETC}/THEME/stock/menu_files/ra_drive2_error.png"
rm_if_installed "theme/ra_drive2_invalid_disc.png" "${PE_ETC}/THEME/stock/menu_files/ra_drive2_invalid_disc.png"
rm_if_installed "config/ra-game-cdrom.cfg" "${PE_OPT}/config/retroarch/ra-game-cdrom.cfg"

# Also remove per-core override if present
DRIVE2_OPT="${PE_OPT}/config/retroarch/config/PCSX-ReARMed/drive2.opt"
if [ -f "${DRIVE2_OPT}" ]; then
  rm -f "${DRIVE2_OPT}"
  log "Removed RetroArch override ${DRIVE2_OPT}"
fi

# Also remove save RAM if present (requested)
DRIVE2_SRM="${PE_OPT}/saves/drive2.srm"
if [ -f "${DRIVE2_SRM}" ]; then
  rm -f "${DRIVE2_SRM}"
  log "Removed RetroArch save ${DRIVE2_SRM}"
fi

# User-friendly cleanup: ALWAYS try to delete the RetroArch modules directory.
# - If empty: delete it.
# - If non-empty: delete it ONLY if it contains only our known module filenames.
if [ -d "${PE_OPT}/modules" ]; then
  if [ -z "$(ls -A "${PE_OPT}/modules" 2>/dev/null)" ]; then
    rm -rf "${PE_OPT}/modules"
    log "Removed RetroArch modules directory ${PE_OPT}/modules (empty)"
  else
    only_known=1
    for p in "${PE_OPT}/modules/"*; do
      [ -e "$p" ] || continue
      b="$(basename "$p")"
      case "$b" in
        cdrom.ko|sg.ko|sr_mod.ko) ;;
        *) only_known=0 ;;
      esac
    done

    if [ "${only_known}" -eq 1 ]; then
      rm -rf "${PE_OPT}/modules"
      log "Removed RetroArch modules directory ${PE_OPT}/modules (contained only known mod files)"
    else
      log "RetroArch modules directory ${PE_OPT}/modules contains non-mod files; not removing."
    fi
  fi
fi

# 3) Remove launcher folder (if it still looks like ours)
if [ -n "${GAME_ID}" ] && [ -d "${PE_GAMES}/${GAME_ID}" ]; then
  if [ -f "${PE_GAMES}/${GAME_ID}/drive2.cue" ] || [ -f "${PE_GAMES}/${GAME_ID}/drive2.bin" ]; then
    rm -rf "${PE_GAMES}/${GAME_ID}"
    log "Removed launcher folder ${PE_GAMES}/${GAME_ID}"
  else
    log "Game folder ${PE_GAMES}/${GAME_ID} doesn't look like drive2 launcher; not deleting."
  fi
fi

# 4) Remove DB entries (scoped, schema-correct)
# regional.db uses MENU_ENTRIES and DISC (DISC FK -> MENU_ENTRIES)
sqlite3 "${DB_REGIONAL}" "DELETE FROM DISC WHERE BASENAME='${BASENAME_SQL}';"
sqlite3 "${DB_REGIONAL}" "DELETE FROM MENU_ENTRIES WHERE GAME_TITLE_STRING='${TITLE_SQL}';"
log "Removed regional.db entries"

# BleemSync.db
# Delete files tied to node first (FK cascade may already handle it, but be explicit)
NODE_ID_BY_NAME="$(sqlite3 "${DB_BLEEM}" "SELECT Id FROM GameManagerNodes WHERE Name='${TITLE_SQL}' LIMIT 1;")"
if [ -n "${NODE_ID_BY_NAME}" ]; then
  sqlite3 "${DB_BLEEM}" "DELETE FROM GameManagerFiles WHERE NodeId=${NODE_ID_BY_NAME};"
fi
sqlite3 "${DB_BLEEM}" "DELETE FROM GameManagerNodes WHERE Name='${TITLE_SQL}';"
log "Removed BleemSync.db entries"

# 5) Cleanup state + backups by removing the entire mod state directory
if [ -d "${STATE_DIR}" ]; then
  rm -rf "${STATE_DIR}"
  log "Removed mod state directory ${STATE_DIR} (state + backups)"
fi

log "Uninstall complete."
exit 0
