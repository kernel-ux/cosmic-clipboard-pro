#!/bin/bash
# ==============================================================================
# COSMIC Clipboard Pro - Professional Installer (RAM Mode & Universal Support)
# Created by Jeevan (2026)
# ==============================================================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}🚀 Welcome to COSMIC Clipboard Pro (Universal Mode)!${NC}"
echo -e "${BLUE}====================================================${NC}"

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

# Helper for running commands as the user with correct environment
USER_CMD="sudo -u $ACTUAL_USER -H XDG_RUNTIME_DIR=$RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS=unix:path=$RUNTIME_DIR/bus"

echo -e "${BLUE}Installing for user: ${GREEN}$ACTUAL_USER${BLUE} (Home: $USER_HOME)${NC}"

# 3. Dependencies
echo -e "${BLUE}[1/7] Installing system dependencies...${NC}"
apt update && apt install -y build-essential git libwayland-dev libxkbcommon-dev \
               libdbus-1-dev wtype wl-clipboard pkg-config
echo -e "${GREEN}✓ Dependencies installed.${NC}"

# 4. Rust Nightly
echo -e "${BLUE}[2/7] Configuring Rust Nightly...${NC}"
$USER_CMD bash -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y" || true
$USER_CMD bash -c "source $USER_HOME/.cargo/env && rustup toolchain install nightly && rustup default nightly"
echo -e "${GREEN}✓ Rust ready.${NC}"

# 5. Ringboard
echo -e "${BLUE}[3/7] Installing Ringboard Suite...${NC}"
$USER_CMD bash -c "source $USER_HOME/.cargo/env && cargo install --force ringboard-server ringboard-wayland ringboard-egui"
echo -e "${GREEN}✓ Ringboard ready.${NC}"

# 6. wl-clip-persist
echo -e "${BLUE}[4/7] Installing wl-clip-persist...${NC}"
TMP_BUILD="/tmp/clipboard-pro-build-$(date +%s)"
$USER_CMD mkdir -p "$TMP_BUILD"
$USER_CMD git clone https://github.com/Linus789/wl-clip-persist.git "$TMP_BUILD"
$USER_CMD bash -c "source $USER_HOME/.cargo/env && cd $TMP_BUILD && cargo build --release"
cp "$TMP_BUILD/target/release/wl-clip-persist" /usr/local/bin/
chmod +x /usr/local/bin/wl-clip-persist
rm -rf "$TMP_BUILD"
echo -e "${GREEN}✓ wl-clip-persist ready.${NC}"

# 7. Services
echo -e "${BLUE}[5/7] Configuring Background RAM Services...${NC}"
if ! grep -q "COSMIC_DATA_CONTROL_ENABLED=1" /etc/environment; then
    echo "COSMIC_DATA_CONTROL_ENABLED=1" >> /etc/environment
fi

SYSTEMD_DIR="$USER_HOME/.config/systemd/user"
$USER_CMD mkdir -p "$SYSTEMD_DIR"

cat <<EOM > "$SYSTEMD_DIR/wl-clip-persist.service"
[Unit]
Description=Wayland Clipboard Persistence
After=graphical-session.target
[Service]
ExecStart=/usr/local/bin/wl-clip-persist --clipboard regular
Restart=always
[Install]
WantedBy=graphical-session.target
EOM

RAM_DB="/run/user/$USER_ID/clipboard-history-ram"
$USER_CMD mkdir -p "$RAM_DB"

cat <<EOM > "$SYSTEMD_DIR/ringboard-server.service"
[Unit]
Description=Ringboard Server (RAM Mode)
After=graphical-session.target
[Service]
ExecStart=$USER_HOME/.cargo/bin/ringboard-server --database $RAM_DB
Restart=always
[Install]
WantedBy=graphical-session.target
EOM

cat <<EOM > "$SYSTEMD_DIR/ringboard-wayland.service"
[Unit]
Description=Ringboard Wayland Listener
After=ringboard-server.service
[Service]
ExecStart=$USER_HOME/.cargo/bin/ringboard-wayland
Restart=always
[Install]
WantedBy=graphical-session.target
EOM

# 8. Master Script
BIN_DIR="$USER_HOME/.local/bin"
$USER_CMD mkdir -p "$BIN_DIR"
cat <<'EOM' > "$BIN_DIR/paste-master.sh"
#!/bin/bash
USER_ID=$(id -u)
RAM_DB="/run/user/$USER_ID/clipboard-history-ram"
OLD_SIG=$( (wl-paste --type text 2>/dev/null; wl-paste --list-types 2>/dev/null) | sha1sum || echo "empty")
ringboard-egui --database "$RAM_DB"
sleep 0.2
NEW_SIG=$( (wl-paste --type text 2>/dev/null; wl-paste --list-types 2>/dev/null) | sha1sum || echo "empty")
if [ "$OLD_SIG" != "$NEW_SIG" ]; then
    wtype -M ctrl v
fi
EOM
chmod +x "$BIN_DIR/paste-master.sh"
chown "$ACTUAL_USER:$ACTUAL_USER" "$BIN_DIR/paste-master.sh"

$USER_CMD bash -c "systemctl --user daemon-reload"
$USER_CMD bash -c "systemctl --user enable wl-clip-persist.service ringboard-server.service ringboard-wayland.service"
$USER_CMD bash -c "systemctl --user restart wl-clip-persist.service ringboard-server.service ringboard-wayland.service"

# 9. Shortcut
echo -e "${BLUE}[6/7] Automating Keyboard Shortcut (Super + V)...${NC}"
SHORTCUT_FILE="$USER_HOME/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom"
$USER_CMD mkdir -p "$(dirname "$SHORTCUT_FILE")"
cat <<EOM > "$SHORTCUT_FILE"
{
    (
        modifiers: [
            Super,
        ],
        key: "v",
        description: Some("Clipboard Pro"),
    ): Spawn("$BIN_DIR/paste-master.sh"),
}
EOM

echo -e "${GREEN}✓ All steps complete!${NC}"
echo -e "${BLUE}[7/7] Finalizing...${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}🎉 UNIVERSAL INSTALLATION COMPLETE!${NC}"
echo -e "Restart your computer and press Win+V to start! 🥂"
