#!/bin/bash
# ==============================================================================
# COSMIC Clipboard Pro - Professional Uninstaller
# Created by Jeevan (2026)
# ==============================================================================

set -e

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
if [ "$SUDO_USER" ]; then
    ACTUAL_USER=$SUDO_USER
else
    ACTUAL_USER=$(logname 2>/dev/null || echo $USER)
fi

USER_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
USER_ID=$(getent passwd "$ACTUAL_USER" | cut -d: -f3)
RUNTIME_DIR="/run/user/$USER_ID"
USER_CMD="sudo -u $ACTUAL_USER -H XDG_RUNTIME_DIR=$RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS=unix:path=$RUNTIME_DIR/bus"

# 3. Stop and Disable Services
echo -e "${BLUE}[1/4] Stopping background services...${NC}"
$USER_CMD bash -c "systemctl --user stop wl-clip-persist.service ringboard-server.service ringboard-wayland.service" || true
$USER_CMD bash -c "systemctl --user disable wl-clip-persist.service ringboard-server.service ringboard-wayland.service" || true
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
rm -f "$SHORTCUT_FILE"
echo -e "${GREEN}✓ Shortcut removed.${NC}"

# 6. Clean Environment
echo -e "${BLUE}[4/4] Cleaning environment variables...${NC}"
sed -i '/COSMIC_DATA_CONTROL_ENABLED=1/d' /etc/environment
echo -e "${GREEN}✓ Environment cleaned.${NC}"

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}✨ UNINSTALL COMPLETE!${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e "Your system is back to normal! 🥂"
