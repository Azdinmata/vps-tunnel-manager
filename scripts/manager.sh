#!/bin/bash
# ==============================================================================
# ULTRA VPS SSH & MULTI-PROTOCOL TUNNEL MANAGER - CLI MENU ('manager')
# Location: scripts/manager.sh
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${CYAN}=================================================================${NC}"
echo -e "       ${GREEN}ULTRA VPS TUNNEL MANAGER - CLI CONTROL PANEL${NC}         "
echo -e "${CYAN}=================================================================${NC}"
echo -e " 1) Create Universal Account (Type 0 for Lifetime)"
echo -e " 2) List Accounts & V2Ray UUIDs"
echo -e " 3) Restart Services"
echo -e " 0) Exit"
echo -e "${CYAN}=================================================================${NC}"
