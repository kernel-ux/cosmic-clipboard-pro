#!/bin/bash
# ==============================================================================
# COSMIC Clipboard Pro - Professional Installer (RAM Mode & Universal Support)
# Created by Jeevan (2026)
# ==============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}🚀 Welcome to COSMIC Clipboard Pro (Universal Mode)!${NC}"
echo -e "${BLUE}====================================================${NC}"

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run this script with sudo or pkexec.${NC}"
  exit 1
fi

echo -e "${BLUE}[1/7] Installing system dependencies...${NC}"
apt update
apt install -y build-essential git libwayland-dev libxkbcommon-dev \
               libdbus-1-dev wtype wl-clipboard pkg-config
echo -e "${GREEN}✓ Dependencies installed.${NC}"

echo -e "${BLUE}[2/7] Configuring Rust Nightly...${NC}"
USER_HOME=$(eval echo "~$SUDO_USER")
USER_ID=$(id -u "$SUDO_USER")
sudo -u "$SUDO_USER" -H bash -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"
sudo -u "$SUDO_USER" -H bash -c "source \$HOME/.cargo/env && rustup toolchain install nightly && rustup default nightly"
echo -e "${GREEN}✓ Rust ready.${NC}"

echo -e "${BLUE}[3/7] Installing Ringboard Suite...${NC}"
sudo -u "$SUDO_USER" -H bash -c "source \$HOME/.cargo/env && cargo install ringboard-server ringboard-wayland ringboard-egui"
echo -e "${GREEN}✓ Ringboard ready.${NC}"

echo -e "${BLUE}[4/7] Installing wl-clip-persist...${NC}"
TMP_DIR=$(mktemp -d)
sudo -u "$SUDO_USER" git clone https://github.com/Linus789/wl-clip-persist.git "$TMP_DIR"
cd "$TMP_DIR"
sudo -u "$SUDO_USER" -H bash -c "source \$HOME/.cargo/env && cargo build --release"
cp target/release/wl-clip-persist /usr/local/bin/
chmod +x /usr/local/bin/wl-clip-persist
rm -rf "$TMP_DIR"
echo -e "${GREEN}✓ wl-clip-persist ready.${NC}"

echo -e "${BLUE}[5/7] Configuring Universal Background RAM Services...${NC}"

# Set COSMIC_DATA_CONTROL_ENABLED
if ! grep -q "COSMIC_DATA_CONTROL_ENABLED=1" /etc/environment; then
    echo "COSMIC_DATA_CONTROL_ENABLED=1" >> /etc/environment
fi

USER_SYSTEMD_DIR="$USER_HOME/.config/systemd/user"
sudo -u "$SUDO_USER" mkdir -p "$USER_SYSTEMD_DIR"

# wl-clip-persist Service
cat <<EOF > "$USER_SYSTEMD_DIR/wl-clip-persist.service"
[Unit]
Description=Wayland Clipboard Persistence
After=graphical-session.target

[Service]
ExecStart=/usr/local/bin/wl-clip-persist --clipboard regular
Restart=always

[Install]
WantedBy=graphical-session.target
EOF

# Ringboard Server (RAM ONLY)
RAM_DB="/run/user/\$USER_ID/clipboard-history-ram"
sudo -u "\$SUDO_USER" mkdir -p "\$RAM_DB"
cat <<EOF > "$USER_SYSTEMD_DIR/ringboard-server.service"
[Unit]
Description=Ringboard Server (RAM Mode)
After=graphical-session.target

[Service]
ExecStart=$USER_HOME/.cargo/bin/ringboard-server --database $RAM_DB
Restart=always

[Install]
WantedBy=graphical-session.target
EOF

# Ringboard Wayland Service
cat <<EOF > "$USER_SYSTEMD_DIR/ringboard-wayland.service"
[Unit]
Description=Ringboard Wayland Listener
After=ringboard-server.service

[Service]
ExecStart=$USER_HOME/.cargo/bin/ringboard-wayland
Restart=always

[Install]
WantedBy=graphical-session.target
EOF

# Universal Master Script (Supports Text, Images, GIFs)
BIN_DIR="$USER_HOME/.local/bin"
sudo -u "$SUDO_USER" mkdir -p "$BIN_DIR"
cat <<EOF > "$BIN_DIR/paste-master.sh"
#!/bin/bash
USER_ID=\$(id -u)
RAM_DB="/run/user/\$USER_ID/clipboard-history-ram"
OLD_SIG=\$( (wl-paste --type text 2>/dev/null; wl-paste --list-types 2>/dev/null) | sha1sum || echo "empty")
$USER_HOME/.cargo/bin/ringboard-egui --database "\$RAM_DB"
sleep 0.2
NEW_SIG=\$( (wl-paste --type text 2>/dev/null; wl-paste --list-types 2>/dev/null) | sha1sum || echo "empty")
if [ "\$OLD_SIG" != "\$NEW_SIG" ]; then
    wtype -M ctrl v
fi
EOF
chmod +x "$BIN_DIR/paste-master.sh"
chown "$SUDO_USER:$SUDO_USER" "$BIN_DIR/paste-master.sh"

sudo -u "$SUDO_USER" -H bash -c "systemctl --user daemon-reload"
sudo -u "$SUDO_USER" -H bash -c "systemctl --user enable wl-clip-persist.service ringboard-server.service ringboard-wayland.service"

echo -e "${GREEN}✓ Universal services ready.${NC}"

# 6. Automate Keyboard Shortcut (Super + V)
echo -e "${BLUE}[6/7] Automating Keyboard Shortcut (Super + V)...${NC}"
SHORTCUT_FILE="$USER_HOME/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom"
sudo -u "$SUDO_USER" mkdir -p "$(dirname "$SHORTCUT_FILE")"

# We use a simple RON (Rusty Object Notation) template for COSMIC
cat <<EOF > "$SHORTCUT_FILE"
{
    (
        modifiers: [
            Super,
        ],
        key: "v",
        description: Some("Clipboard Pro"),
    ): Spawn("$BIN_DIR/paste-master.sh"),
}
EOF
echo -e "${GREEN}✓ Super + V shortcut automated.${NC}"

echo -e "${BLUE}[7/7] Finalizing...${NC}"
echo -e "${GREEN}🎉 UNIVERSAL INSTALLATION COMPLETE!${NC}"
echo -e "Your history is now 100% in RAM and Super+V is set! Reboot and enjoy! 🥂"
