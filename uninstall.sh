#!/bin/bash
# ==============================================================================
# COSMIC Clipboard Pro - Professional Uninstaller
# Created by Jeevan (2026)
# ==============================================================================

set -e

# Colors for professional output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${RED}====================================================${NC}"
echo -e "${RED}🧹 Uninstalling COSMIC Clipboard Pro...${NC}"
echo -e "${RED}====================================================${NC}"

# 1. Check for Root Permission
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run this script with sudo or pkexec.${NC}"
  exit 1
fi

USER_HOME=$(eval echo "~$SUDO_USER")
USER_SYSTEMD_DIR="$USER_HOME/.config/systemd/user"

# 2. Stop and Disable Systemd Services
echo -e "${BLUE}[1/4] Stopping background services...${NC}"
sudo -u "$SUDO_USER" -H bash -c "systemctl --user stop wl-clip-persist.service ringboard-server.service ringboard-wayland.service" || true
sudo -u "$SUDO_USER" -H bash -c "systemctl --user disable wl-clip-persist.service ringboard-server.service ringboard-wayland.service" || true
echo -e "${GREEN}✓ Services stopped and disabled.${NC}"

# 3. Remove Binary and Script Files
echo -e "${BLUE}[2/4] Removing installed files...${NC}"
rm -f /usr/local/bin/wl-clip-persist
rm -f "$USER_HOME/.local/bin/paste-master.sh"
rm -f "$USER_SYSTEMD_DIR/wl-clip-persist.service"
rm -f "$USER_SYSTEMD_DIR/ringboard-server.service"
rm -f "$USER_SYSTEMD_DIR/ringboard-wayland.service"
echo -e "${GREEN}✓ Files removed.${NC}"

# 4. Clean up Environment Variables
echo -e "${BLUE}[3/4] Cleaning environment variables...${NC}"
sed -i '/COSMIC_DATA_CONTROL_ENABLED=1/d' /etc/environment
echo -e "${GREEN}✓ Environment cleaned.${NC}"

# 5. Finalize
echo -e "${BLUE}[4/4] Finalizing cleanup...${NC}"
sudo -u "$SUDO_USER" -H bash -c "systemctl --user daemon-reload"

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}✨ UNINSTALL COMPLETE!${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e "Note: Ringboard binaries (installed via Cargo) and history database"
echo -e "were left untouched. You can remove them with:"
echo -e "  cargo uninstall ringboard-server ringboard-wayland ringboard-egui"
echo -e "  rm -rf $USER_HOME/.local/share/clipboard-history"
echo -e ""
echo -e "Your system is back to normal! 🥂"
