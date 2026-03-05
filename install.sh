#!/bin/bash
# ==============================================================================
# COSMIC Clipboard Pro - Professional Installer (RAM Mode & Universal Support)
# Created by Jeevan (2026)
# ==============================================================================

set -euo pipefail

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
RAM_DB="$RUNTIME_DIR/clipboard-history-ram"
CLIP_HISTORY_PATH="$USER_HOME/.local/share/clipboard-history"
BACKUP_PATH="$USER_HOME/.local/share/clipboard-history.backup.$(date +%Y%m%d-%H%M%S)"

if [ ! -d "$RUNTIME_DIR" ]; then
  echo -e "${RED}Runtime directory $RUNTIME_DIR was not found.${NC}"
  echo -e "${RED}Please log in to your desktop session, then run installer again.${NC}"
  exit 1
fi

sudo -u "$ACTUAL_USER" mkdir -p "$USER_HOME/.local/share" "$RAM_DB"

# Move existing persistent history once instead of deleting user data.
if [ -L "$CLIP_HISTORY_PATH" ]; then
  sudo -u "$ACTUAL_USER" rm -f "$CLIP_HISTORY_PATH"
elif [ -d "$CLIP_HISTORY_PATH" ]; then
  if [ -n "$(sudo -u "$ACTUAL_USER" ls -A "$CLIP_HISTORY_PATH" 2>/dev/null)" ]; then
    sudo -u "$ACTUAL_USER" mv "$CLIP_HISTORY_PATH" "$BACKUP_PATH"
    echo -e "${BLUE}Backed up old clipboard history to: ${GREEN}$BACKUP_PATH${NC}"
  else
    sudo -u "$ACTUAL_USER" rmdir "$CLIP_HISTORY_PATH" || true
  fi
fi
sudo -u "$ACTUAL_USER" ln -sfn "$RAM_DB" "$CLIP_HISTORY_PATH"

# Helper for running commands as the user with correct environment
USER_CMD="sudo -u $ACTUAL_USER -H XDG_RUNTIME_DIR=$RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS=unix:path=$RUNTIME_DIR/bus"

echo -e "${BLUE}Installing for user: ${GREEN}$ACTUAL_USER${BLUE} (Home: $USER_HOME)${NC}"

# 3. Dependencies
echo -e "${BLUE}[1/6] Installing system dependencies...${NC}"
apt update && apt install -y build-essential git libwayland-dev libxkbcommon-dev \
               libdbus-1-dev wtype wl-clipboard pkg-config
echo -e "${GREEN}✓ Dependencies installed.${NC}"

# 4. Rust Nightly
echo -e "${BLUE}[2/6] Configuring Rust Nightly...${NC}"
$USER_CMD bash -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y" || true
$USER_CMD bash -c "source $USER_HOME/.cargo/env && rustup toolchain install nightly && rustup default nightly"
echo -e "${GREEN}✓ Rust ready.${NC}"

# 5. Ringboard
echo -e "${BLUE}[3/6] Installing Ringboard Suite...${NC}"
$USER_CMD bash -c "source $USER_HOME/.cargo/env && cargo install --force ringboard-server ringboard-wayland ringboard-egui"
echo -e "${GREEN}✓ Ringboard ready.${NC}"

# 6. Services (Ringboard-only to avoid clipboard ownership races)
echo -e "${BLUE}[4/6] Configuring Background RAM Services...${NC}"
if ! grep -q "COSMIC_DATA_CONTROL_ENABLED=1" /etc/environment; then
    echo "COSMIC_DATA_CONTROL_ENABLED=1" >> /etc/environment
fi

SYSTEMD_DIR="$USER_HOME/.config/systemd/user"
$USER_CMD mkdir -p "$SYSTEMD_DIR"

cat <<EOM > "$SYSTEMD_DIR/ringboard-server.service"
[Unit]
Description=Ringboard Server (RAM Mode)
[Service]
ExecStartPre=/usr/bin/mkdir -p $RAM_DB
ExecStart=$USER_HOME/.cargo/bin/ringboard-server --database $RAM_DB
Restart=always
[Install]
WantedBy=graphical-session.target
EOM

cat <<EOM > "$SYSTEMD_DIR/ringboard-wayland.service"
[Unit]
Description=Ringboard Wayland Listener
After=graphical-session.target ringboard-server.service
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
set -euo pipefail

USER_ID=$(id -u)
RAM_DIR="/run/user/$USER_ID/clipboard-history-ram"

# Compare a combined signature so we only auto-paste if selection changed.
OLD_SIG=$( (wl-paste --type text 2>/dev/null; wl-paste --list-types 2>/dev/null) | sha1sum || echo "empty")
ringboard-egui --database "$RAM_DIR" || true
sleep 0.2
NEW_SIG=$( (wl-paste --type text 2>/dev/null; wl-paste --list-types 2>/dev/null) | sha1sum || echo "empty")

if [ "$OLD_SIG" != "$NEW_SIG" ]; then
    wtype -M ctrl v
fi
EOM
chmod +x "$BIN_DIR/paste-master.sh"
chown "$ACTUAL_USER:$ACTUAL_USER" "$BIN_DIR/paste-master.sh"

$USER_CMD bash -c "systemctl --user daemon-reload"
$USER_CMD bash -c "systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE" || true
$USER_CMD bash -c "systemctl --user disable wl-clip-persist.service" || true
$USER_CMD bash -c "systemctl --user stop wl-clip-persist.service" || true
$USER_CMD bash -c "systemctl --user enable ringboard-server.service ringboard-wayland.service"
$USER_CMD bash -c "systemctl --user restart ringboard-server.service"
sleep 1
$USER_CMD bash -c "systemctl --user restart ringboard-wayland.service"

# 9. Shortcut
echo -e "${BLUE}[5/6] Automating Keyboard Shortcut (Super + V)...${NC}"
SHORTCUT_FILE="$USER_HOME/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom"
$USER_CMD mkdir -p "$(dirname "$SHORTCUT_FILE")"

SHORTCUT_ENTRY='    (
        modifiers: [
            Super,
        ],
        key: "v",
        description: Some("Clipboard Pro"),
    ): Spawn("'"$BIN_DIR"'/paste-master.sh"),'

if [ ! -f "$SHORTCUT_FILE" ]; then
cat <<EOM > "$SHORTCUT_FILE"
{
$SHORTCUT_ENTRY
}
EOM
elif grep -q 'description: Some("Clipboard Pro")' "$SHORTCUT_FILE"; then
  echo -e "${BLUE}Clipboard Pro shortcut already exists. Keeping existing shortcut file.${NC}"
else
  TMP_SHORTCUT="$(mktemp)"
  awk -v entry="$SHORTCUT_ENTRY" '
    { lines[NR]=$0 }
    END {
      close_line=0
      for (i=NR; i>=1; i--) {
        if (lines[i] ~ /^[[:space:]]*}[[:space:]]*$/) { close_line=i; break }
      }
      if (close_line == 0) {
        print "{"
        print entry
        print "}"
        exit
      }
      for (i=1; i<close_line; i++) print lines[i]
      print entry
      for (i=close_line; i<=NR; i++) print lines[i]
    }
  ' "$SHORTCUT_FILE" > "$TMP_SHORTCUT"
  mv "$TMP_SHORTCUT" "$SHORTCUT_FILE"
fi
chown "$ACTUAL_USER:$ACTUAL_USER" "$SHORTCUT_FILE"

echo -e "${GREEN}✓ All steps complete!${NC}"
echo -e "${BLUE}[6/6] Finalizing...${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}🎉 UNIVERSAL INSTALLATION COMPLETE!${NC}"
echo -e "Restart your computer and press Win+V to start! 🥂"
