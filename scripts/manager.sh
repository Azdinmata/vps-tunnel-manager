#!/bin/bash
# ==============================================================================
# ULTRA VPS TUNNEL MANAGER - COMPATIBILITY WRAPPER FOR 'menu'
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/menu.sh" ]; then
  bash "$SCRIPT_DIR/menu.sh" "$@"
elif [ -f "/usr/local/vps-manager/scripts/menu.sh" ]; then
  bash "/usr/local/vps-manager/scripts/menu.sh" "$@"
else
  echo "Error: menu.sh script not found!"
  exit 1
fi
