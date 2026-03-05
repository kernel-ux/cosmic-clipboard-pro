#!/bin/bash
set -euo pipefail

# Open history only. User pastes manually with Ctrl+V after choosing item.
ringboard-egui || true
