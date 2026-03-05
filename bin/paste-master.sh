#!/bin/bash
set -euo pipefail

# Master Clipboard Script for Jeevan (Improved)
# This script makes it work exactly like Windows Win+V
# and prevents pasting when deleting or canceling.

# 1. Get current clipboard signature (text + MIME types)
OLD_SIG=$( (wl-paste --type text 2>/dev/null; wl-paste --list-types 2>/dev/null) | sha1sum || echo "empty")

# 2. Open the Ringboard history picker
ringboard-egui || true

# 3. Wait for selection and focus shift
sleep 0.2

# 4. Get new clipboard signature
NEW_SIG=$( (wl-paste --type text 2>/dev/null; wl-paste --list-types 2>/dev/null) | sha1sum || echo "empty")

# 5. Only paste if the clipboard actually changed
if [ "$OLD_SIG" != "$NEW_SIG" ]; then
    wtype -M ctrl v
fi
