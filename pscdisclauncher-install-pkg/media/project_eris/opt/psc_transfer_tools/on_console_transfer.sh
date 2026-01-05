#!/bin/sh
#
#  Copyright 2020 ModMyClassic (https://modmyclassic.com/license)
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
###############################################################################
# PlayStation Classic On-Console Transfer Tool Launch Script
# ModMyClassic.com / https://discordapp.com/invite/8gygsrw
###############################################################################

source "/var/volatile/project_eris.cfg"
source "${PROJECT_ERIS_PATH}/etc/project_eris/FUNC/0000_shared.funcs"

[ ! -d "${MOUNTPOINT}/games/" ] && mkdir -p "${MOUNTPOINT}/games/"
[ ! -d "${MOUNTPOINT}/transfer/" ] && mkdir -p "${MOUNTPOINT}/transfer/"
chmod +x "${PROJECT_ERIS_PATH}/opt/psc_transfer_tools/psc_game_add"
cd "${PROJECT_ERIS_PATH}/opt/psc_transfer_tools" || exit 1

sdl_text "Scanning transfer directory for games..."

"${PROJECT_ERIS_PATH}/opt/psc_transfer_tools/psc_game_add" \
  "${MOUNTPOINT}/transfer/" \
  "${PROJECT_ERIS_PATH}/etc/project_eris/SYS/databases/" \
  "${MOUNTPOINT}/games/" \
  &> "${RUNTIME_LOG_PATH}/transfer.log"

RET=$?

# --- Inject Game.ini into the transferred drive2 launcher directory (only for our serial) ---
if [ "$RET" -eq 0 ]; then
  TLOG="${RUNTIME_LOG_PATH}/transfer.log"
  SRC_INI="${PROJECT_ERIS_PATH}/opt/psc_transfer_tools/Game.ini"

  # Robust serial check:
  # - tolerate CRLF logs
  # - tolerate minor formatting changes (match just the serial token)
  if [ -f "$TLOG" ] && tr -d '\r' < "$TLOG" 2>/dev/null | grep -Fq "SLUS-99998"; then
    if [ -f "$SRC_INI" ]; then
      FOUND_DIR=""

      # Only scan game dirs if we've positively detected our serial.
      for d in "${MOUNTPOINT}/games/"*; do
        [ -d "$d" ] || continue

        # Detect our launcher folder by its assets
        if [ -f "$d/drive2.cue" ] && [ -f "$d/drive2.bin" ] && [ -f "$d/drive2.png" ]; then
          FOUND_DIR="$d"
          break
        fi
      done

      if [ -n "$FOUND_DIR" ]; then
        # Optional safety: don't overwrite if already present
        if [ ! -f "$FOUND_DIR/Game.ini" ]; then
          cp -f "$SRC_INI" "$FOUND_DIR/Game.ini" 2>/dev/null || true
          chmod 0644 "$FOUND_DIR/Game.ini" 2>/dev/null || true
          sync 2>/dev/null || true
          # Optional: log success
          # echo "[psc_transfer_launch] injected Game.ini into $FOUND_DIR" >> "$TLOG" 2>/dev/null || true
        fi
      fi
    fi
  fi
fi
# --- End injection ---

if [ ! "$RET" -eq 0 ]; then
  sdl_text "Failed to transfer games! Check transfer.log"
  wait 1
fi

exit 0
