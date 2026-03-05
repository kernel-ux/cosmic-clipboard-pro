#!/bin/bash
# ==============================================================================
# COSMIC Clipboard Pro - Professional Uninstaller
# Created by Jeevan (2026)
# ==============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${RED}====================================================${NC}"
echo -e "${RED}🧹 Uninstalling COSMIC Clipboard Pro...${NC}"
echo -e "${RED}====================================================${NC}"

# 1. Root Check
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run this script with sudo or pkexec.${NC}"
  exit 1
fi

# 2. Precise User Detection
if [ -n "${SUDO_USER:-}" ]; then
    ACTUAL_USER="$SUDO_USER"
elif [ -n "${PKEXEC_UID:-}" ]; then
    ACTUAL_USER="$(id -nu "$PKEXEC_UID")"
else
    ACTUAL_USER=$(logname 2>/dev/null || echo "$USER")
fi

USER_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
USER_ID=$(getent passwd "$ACTUAL_USER" | cut -d: -f3)
RUNTIME_DIR="/run/user/$USER_ID"
USER_CMD="sudo -u $ACTUAL_USER -H XDG_RUNTIME_DIR=$RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS=unix:path=$RUNTIME_DIR/bus"

# 3. Stop and Disable Services
echo -e "${BLUE}[1/4] Stopping background services...${NC}"
$USER_CMD bash -c "systemctl --user stop ringboard-server.service ringboard-wayland.service wl-clip-persist.service" || true
$USER_CMD bash -c "systemctl --user disable ringboard-server.service ringboard-wayland.service wl-clip-persist.service" || true
echo -e "${GREEN}✓ Services stopped.${NC}"

# 4. Remove Files
echo -e "${BLUE}[2/4] Removing installed files...${NC}"
rm -f /usr/local/bin/wl-clip-persist
rm -f "$USER_HOME/.local/bin/paste-master.sh"
rm -f "$USER_HOME/.config/systemd/user/wl-clip-persist.service"
rm -f "$USER_HOME/.config/systemd/user/ringboard-server.service"
rm -f "$USER_HOME/.config/systemd/user/ringboard-wayland.service"
echo -e "${GREEN}✓ Files removed.${NC}"

# 5. Remove Shortcut
echo -e "${BLUE}[3/4] Removing keyboard shortcut...${NC}"
SHORTCUT_FILE="$USER_HOME/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom"
if [ -f "$SHORTCUT_FILE" ]; then
  TMP_SHORTCUT="$(mktemp)"
  awk '
    {
      lines[NR]=$0
      if ($0 ~ /description:[[:space:]]*Some\("Clipboard Pro"\)/) match_line=NR
    }
    END {
      if (match_line == 0) {
        for (i=1; i<=NR; i++) print lines[i]
        exit
      }

      start_line=0
      for (i=match_line; i>=1; i--) {
        if (lines[i] ~ /^[[:space:]]*\([[:space:]]*$/) { start_line=i; break }
      }

      end_line=0
      for (i=match_line; i<=NR; i++) {
        if (lines[i] ~ /^[[:space:]]*\):[[:space:]]*Spawn\(.*paste-master\.sh"\),?[[:space:]]*$/) { end_line=i; break }
      }

      if (start_line == 0 || end_line == 0) {
        for (i=1; i<=NR; i++) print lines[i]
        exit
      }

      for (i=1; i<start_line; i++) print lines[i]
      for (i=end_line+1; i<=NR; i++) print lines[i]
    }
  ' "$SHORTCUT_FILE" > "$TMP_SHORTCUT"
  mv "$TMP_SHORTCUT" "$SHORTCUT_FILE"
  chown "$ACTUAL_USER:$ACTUAL_USER" "$SHORTCUT_FILE"
fi
echo -e "${GREEN}✓ Shortcut removed.${NC}"

# 6. Clean Environment
echo -e "${BLUE}[4/4] Cleaning environment variables...${NC}"
sed -i '/COSMIC_DATA_CONTROL_ENABLED=1/d' /etc/environment
echo -e "${GREEN}✓ Environment cleaned.${NC}"

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}✨ UNINSTALL COMPLETE!${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e "Your system is back to normal! 🥂"
