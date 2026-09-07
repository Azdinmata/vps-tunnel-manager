#!/bin/bash
# ==============================================================================
# ULTRA VPS SSH & MULTI-PROTOCOL TUNNEL MANAGER - UNINSTALLER & PURGE SCRIPT
# Location: scripts/uninstall.sh
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${RED}=================================================================${NC}"
echo -e "${RED}       UNINSTALLING ULTRA VPS TUNNEL MANAGER & PURGING SYSTEM   ${NC}"
echo -e "${RED}=================================================================${NC}"

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[ERROR] Please run as root user! (sudo -i)${NC}"
  exit 1
fi

echo -e "\n${YELLOW}[1/4] Stopping and Disabling System Services...${NC}"
systemctl stop vps-web-dashboard ws-proxy badvpn-7300 stunnel4 2>/dev/null
systemctl disable vps-web-dashboard ws-proxy badvpn-7300 stunnel4 2>/dev/null
rm -f /etc/systemd/system/vps-web-dashboard.service /etc/systemd/system/ws-proxy.service /etc/systemd/system/badvpn-7300.service
systemctl daemon-reload

echo -e "\n${YELLOW}[2/4] Removing Executables & Project Directories...${NC}"
rm -rf /usr/local/vps-manager
rm -f /usr/local/bin/manager
rm -f /usr/local/bin/ws-proxy.py
rm -f /usr/local/bin/badvpn-udpgw /usr/local/bin/udp-custom
rm -f /usr/local/bin/auto-expire-cleaner.sh

echo -e "\n${YELLOW}[3/4] Cleaning Cron Tasks & Config Overrides...${NC}"
(crontab -l 2>/dev/null | grep -v "auto-expire-cleaner.sh") | crontab -
rm -f /etc/issue.net

echo -e "\n${YELLOW}[4/4] Restoring SSH Config...${NC}"
systemctl restart sshd || systemctl restart ssh

clear
echo -e "${GREEN}=================================================================${NC}"
echo -e "${GREEN}   ULTRA VPS TUNNEL MANAGER HAS BEEN COMPLETELY PURGED & REMOVED ${NC}"
echo -e "${GREEN}=================================================================${NC}"
