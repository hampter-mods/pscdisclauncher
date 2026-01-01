#!/bin/sh
set -e

MOD_DIR="$(cd "$(dirname "$0")" && pwd)"

PE_ROOT="/media/project_eris"
PE_ETC="${PE_ROOT}/etc/project_eris"
PE_OPT="${PE_ROOT}/opt/retroarch"
PE_GAMES="/media/games"

DB_BLEEM="${PE_ETC}/SYS/databases/BleemSync.db"
DB_REGIONAL="${PE_ETC}/SYS/databases/regional.db"

STATE_DIR="${PE_ETC}/SUP/drive2_mod"
STATE_FILE="${STATE_DIR}/state.conf"

mkdir -p "${STATE_DIR}"

log() { echo "[drive2-mod][install] $*"; }

need_bin() { command -v "$1" >/dev/null 2>&1 || { log "Missing required binary: $1"; exit 1; }; }

need_bin sqlite3
need_bin cp
need_bin mkdir
need_bin sed
need_bin chmod
need_bin date

timestamp="$(date +%Y%m%d-%H%M%S)"

backup_file() {
  src="$1"
  if [ -f "${src}" ]; then
    base="$(basename "${src}")"
    dst="${STATE_DIR}/${base}.bak.${timestamp}"
    cp -f "${src}" "${dst}"
    log "Backed up ${src} -> ${dst}"
  fi
}

# Init state file (must be valid shell assignments)
: > "${STATE_FILE}"

# Track whether RetroArch modules directory existed before install
if [ -d "${PE_OPT}/modules" ]; then
  printf "CREATED_RA_MODULES_DIR=0\n" >> "${STATE_FILE}"
else
  printf "CREATED_RA_MODULES_DIR=1\n" >> "${STATE_FILE}"
fi

# --- 1) Drop-in replacements (with backups) ---
# intercept
if [ -f "${MOD_DIR}/payload/intercept" ]; then
  backup_file "${PE_ETC}/SUP/scripts/intercept"
  mkdir -p "${PE_ETC}/SUP/scripts"
  cp -f "${MOD_DIR}/payload/intercept" "${PE_ETC}/SUP/scripts/intercept"
  chmod +x "${PE_ETC}/SUP/scripts/intercept"
  log "Installed intercept drop-in"
else
  log "payload/intercept missing in mod package - skipping intercept install"
fi

# 0030_retroarch.funcs
if [ -f "${MOD_DIR}/payload/0030_retroarch.funcs" ]; then
  backup_file "${PE_ETC}/FUNC/0030_retroarch.funcs"
  mkdir -p "${PE_ETC}/FUNC"
  cp -f "${MOD_DIR}/payload/0030_retroarch.funcs" "${PE_ETC}/FUNC/0030_retroarch.funcs"
  log "Installed 0030_retroarch.funcs drop-in"
else
  log "payload/0030_retroarch.funcs missing in mod package - skipping funcs install"
fi

# --- 2) Optional extras (only if present in payload) ---
copy_if_present() {
  rel="$1"
  dst="$2"

  # Make rel safe for shell variable name (no / or . etc.)
  safe_key="$(printf "%s" "$rel" | sed 's/[^A-Za-z0-9_]/_/g')"

  if [ -f "${MOD_DIR}/payload/${rel}" ]; then
    mkdir -p "$(dirname "${dst}")"
    cp -f "${MOD_DIR}/payload/${rel}" "${dst}"
    log "Installed ${rel}"
    printf "INSTALLED_%s=1\n" "${safe_key}" >> "${STATE_FILE}"
  else
    log "payload/${rel} missing - skipping"
    printf "INSTALLED_%s=0\n" "${safe_key}" >> "${STATE_FILE}"
  fi
}

# Kernel modules
copy_if_present "modules/cdrom.ko" "${PE_OPT}/modules/cdrom.ko"
copy_if_present "modules/sg.ko" "${PE_OPT}/modules/sg.ko"
copy_if_present "modules/sr_mod.ko" "${PE_OPT}/modules/sr_mod.ko"

# DiscProject core
copy_if_present "cores/pcsx_rearmed_discproject.so" "${PE_OPT}/config/retroarch/cores/pcsx_rearmed_discproject.so"

# Theme error images
copy_if_present "theme/ra_drive2_error.png" "${PE_ETC}/THEME/stock/menu_files/ra_drive2_error.png"
copy_if_present "theme/ra_drive2_invalid_disc.png" "${PE_ETC}/THEME/stock/menu_files/ra_drive2_invalid_disc.png"

# RetroArch cdrom config
copy_if_present "config/ra-game-cdrom.cfg" "${PE_OPT}/config/retroarch/ra-game-cdrom.cfg"

# --- 3) Create a new /media/games/<N> folder for drive2 launcher ---
# Pick a safe new id from MENU_ENTRIES (regional.db schema)
NEW_ID="$(sqlite3 "${DB_REGIONAL}" "SELECT COALESCE(MAX(GAME_ID),0)+1 FROM MENU_ENTRIES;")"
# Ensure folder doesn't exist; bump if needed
while [ -d "${PE_GAMES}/${NEW_ID}" ]; do
  NEW_ID="$((NEW_ID+1))"
done

mkdir -p "${PE_GAMES}/${NEW_ID}"

# Copy launcher files if present
LAUNCHER_OK=0
for f in drive2.bin drive2.cue drive2.png Game.ini; do
  if [ -f "${MOD_DIR}/payload/launcher/${f}" ]; then
    cp -f "${MOD_DIR}/payload/launcher/${f}" "${PE_GAMES}/${NEW_ID}/${f}"
    LAUNCHER_OK=1
  fi
done

if [ "${LAUNCHER_OK}" -eq 1 ]; then
  log "Installed launcher files to ${PE_GAMES}/${NEW_ID}"
else
  log "No launcher files found in payload/launcher - created empty game folder ${PE_GAMES}/${NEW_ID} (you must supply drive2.* + Game.ini)"
fi

# --- 4) Append database entries (id-safe inserts) ---
# regional.db: add MENU_ENTRIES + DISC if missing (DISC FK -> MENU_ENTRIES)
TITLE="PlayStation® Format Disc"
BASENAME="drive2"
TITLE_SQL="$(printf "%s" "${TITLE}" | sed "s/'/''/g")"

# Avoid duplicate installs:
EXISTS_GAME="$(sqlite3 "${DB_REGIONAL}" "SELECT COUNT(*) FROM MENU_ENTRIES WHERE GAME_TITLE_STRING='${TITLE_SQL}';")"
EXISTS_DISC="$(sqlite3 "${DB_REGIONAL}" "SELECT COUNT(*) FROM DISC WHERE BASENAME='${BASENAME}';")"

if [ "${EXISTS_GAME}" -eq 0 ]; then
  sqlite3 "${DB_REGIONAL}" "INSERT INTO MENU_ENTRIES
    (GAME_ID, GAME_TITLE_STRING, PUBLISHER_NAME, RELEASE_YEAR, PLAYERS, RATING_IMAGE, GAME_MANUAL_QR_IMAGE, LINK_GAME_ID, POSITION)
    VALUES
    (${NEW_ID}, '${TITLE_SQL}', 'Sony', 1994, 4, 'CERO_A', 'QR_Code_GM', '', ${NEW_ID});"
  log "Inserted MENU_ENTRIES row into regional.db (GAME_ID=${NEW_ID})"
else
  log "regional.db already has a MENU_ENTRIES row titled '${TITLE}' - reusing existing GAME_ID"
  NEW_ID="$(sqlite3 "${DB_REGIONAL}" "SELECT GAME_ID FROM MENU_ENTRIES WHERE GAME_TITLE_STRING='${TITLE_SQL}' LIMIT 1;")"
fi

if [ "${EXISTS_DISC}" -eq 0 ]; then
  NEW_DISC_ID="$(sqlite3 "${DB_REGIONAL}" "SELECT COALESCE(MAX(DISC_ID),0)+1 FROM DISC;")"
  sqlite3 "${DB_REGIONAL}" "INSERT INTO DISC (DISC_ID, GAME_ID, DISC_NUMBER, BASENAME)
    VALUES (${NEW_DISC_ID}, ${NEW_ID}, 1, '${BASENAME}');"
  log "Inserted DISC row into regional.db (DISC_ID=${NEW_DISC_ID})"
else
  log "regional.db already has a DISC row with BASENAME='${BASENAME}' - skipping DISC insert"
fi

# BleemSync.db: add GameManagerNodes + GameManagerFiles if missing (schema-safe)
EXISTS_NODE="$(sqlite3 "${DB_BLEEM}" "SELECT COUNT(*) FROM GameManagerNodes WHERE Name='${TITLE_SQL}';")"
if [ "${EXISTS_NODE}" -eq 0 ]; then
  NEW_NODE_ID="$(sqlite3 "${DB_BLEEM}" "SELECT COALESCE(MAX(Id),0)+1 FROM GameManagerNodes;")"
  sqlite3 "${DB_BLEEM}" "INSERT INTO GameManagerNodes (Id, Name, Type, ParentId, Position)
    VALUES (${NEW_NODE_ID}, '${TITLE_SQL}', 3, 0, ${NEW_NODE_ID});"
  log "Inserted GameManagerNodes row (Id=${NEW_NODE_ID})"

  # Insert files (GameManagerFiles: Id, Name, Path, NodeId)
  NEW_FILE_ID="$(sqlite3 "${DB_BLEEM}" "SELECT COALESCE(MAX(Id),0)+1 FROM GameManagerFiles;")"
  sqlite3 "${DB_BLEEM}" "INSERT INTO GameManagerFiles (Id, Name, Path, NodeId)
    VALUES (${NEW_FILE_ID}, 'drive2.cue', '${PE_GAMES}/${NEW_ID}/drive2.cue', ${NEW_NODE_ID});"
  NEW_FILE_ID="$((NEW_FILE_ID+1))"
  sqlite3 "${DB_BLEEM}" "INSERT INTO GameManagerFiles (Id, Name, Path, NodeId)
    VALUES (${NEW_FILE_ID}, 'drive2.png', '${PE_GAMES}/${NEW_ID}/drive2.png', ${NEW_NODE_ID});"
  NEW_FILE_ID="$((NEW_FILE_ID+1))"
  sqlite3 "${DB_BLEEM}" "INSERT INTO GameManagerFiles (Id, Name, Path, NodeId)
    VALUES (${NEW_FILE_ID}, 'Game.ini', '${PE_GAMES}/${NEW_ID}/Game.ini', ${NEW_NODE_ID});"
  log "Inserted GameManagerFiles rows for launcher"
else
  log "BleemSync.db already has a node named '${TITLE}' - skipping BleemSync inserts"
  NEW_NODE_ID="$(sqlite3 "${DB_BLEEM}" "SELECT Id FROM GameManagerNodes WHERE Name='${TITLE_SQL}' LIMIT 1;")"
fi

# --- 5) Save state for uninstall ---
cat >> "${STATE_FILE}" <<EOF
INSTALLED=1
TIMESTAMP=${timestamp}
GAME_ID=${NEW_ID}
NODE_ID=${NEW_NODE_ID}
TITLE=${TITLE}
BASENAME=${BASENAME}
EOF

log "Install complete. State saved to ${STATE_FILE}"
exit 0
