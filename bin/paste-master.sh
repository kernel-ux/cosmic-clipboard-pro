#!/bin/bash
# Master Clipboard Script for Jeevan (Improved)
# This script makes it work exactly like Windows Win+V
# and prevents pasting when deleting or canceling.

# 1. Get current clipboard content (to check if it changes)
OLD_CLIP=$(wl-paste --type text 2>/dev/null || echo "")

# 2. Open the Ringboard history picker
/home/jimmy/.cargo/bin/ringboard-egui

# 3. Wait for selection and focus shift
sleep 0.2

# 4. Get new clipboard content
NEW_CLIP=$(wl-paste --type text 2>/dev/null || echo "")

# 5. Only paste if the clipboard actually changed
if [ "$OLD_CLIP" != "$NEW_CLIP" ]; then
    wtype -M ctrl v
fi
