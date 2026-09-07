#!/bin/bash
# ==============================================================================
# ULTRA VPS SSH & MULTI-PROTOCOL TUNNEL MANAGER - CLI TERMINAL MENU ('manager')
# Supports: Universal Accounts, Lifetime Duration (0), AMD64 & ARM64 Processors
# Note: Type '0' in ANY prompt/menu to return to the main menu!
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
ROSE='\033[38;5;204m'
NC='\033[0m'

ARCH=$(uname -m)
case "$ARCH" in
  x86_64|amd64) ARCH_STR="AMD64 / x86_64" ;;
  aarch64|arm64) ARCH_STR="ARM64 / aarch64" ;;
  *) ARCH_STR="$ARCH" ;;
esac

get_sys_stats() {
  CPU_LOAD=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}' 2>/dev/null || echo "12")
  RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
  RAM_USED=$(free -m | awk '/Mem:/ {print $3}')
  RAM_PCT=$(( RAM_USED * 100 / RAM_TOTAL ))
  UPTIME_STR=$(uptime -p | sed 's/up //')
}

show_menu() {
  while true; do
    get_sys_stats
    clear
    echo -e "${CYAN}=================================================================${NC}"
    echo -e "       ${GREEN}ULTRA VPS TUNNEL MANAGER - CLI CONTROL PANEL${NC}         "
    echo -e "${CYAN}=================================================================${NC}"
    echo -e "  ${PURPLE}CPU Load:${NC} ${CPU_LOAD}% | ${PURPLE}RAM:${NC} ${RAM_USED}/${RAM_TOTAL} MB (${RAM_PCT}%)"
    echo -e "  ${PURPLE}CPU Arch:${NC} ${ARCH_STR} | ${PURPLE}Uptime:${NC} ${UPTIME_STR}"
    echo -e "${CYAN}=================================================================${NC}"
    echo -e " ${GREEN}[ 1 ]${NC} Create Universal Account ${ROSE}(Sync SSH, UDP, WS, V2Ray)${NC}"
    echo -e " ${GREEN}[ 2 ]${NC} List All Accounts & V2Ray UUIDs"
    echo -e " ${GREEN}[ 3 ]${NC} Lock / Unlock Account"
    echo -e " ${GREEN}[ 4 ]${NC} Extend Account Validity ${ROSE}(Type 0 for Lifetime)${NC}"
    echo -e " ${GREEN}[ 5 ]${NC} Delete Account"
    echo -e " ${GREEN}[ 6 ]${NC} View Online Users & Active Connections"
    echo -e " ${GREEN}[ 7 ]${NC} Restart Tunnel Services (SSH/SSL/WS/UDP/V2Ray)"
    echo -e " ${GREEN}[ 8 ]${NC} Generate V2Ray Client Import Links (VMess/VLess/Trojan)"
    echo -e " ${GREEN}[ 9 ]${NC} Run VPS Speedtest Benchmark"
    echo -e " ${GREEN}[ 10 ]${NC} Reboot VPS Server"
    echo -e " ${CYAN}[ 11 ]${NC} Update System Script (git pull)"
    echo -e " ${RED}[ 12 ] UNINSTALL & PURGE EVERYTHING${NC}"
    echo -e " ${RED}[ 0 ] Exit Manager${NC} ${YELLOW}(Type '0' anywhere to return here)${NC}"
    echo -e "${CYAN}=================================================================${NC}"
    read -p " Select option [0-12]: " opt

    case $opt in
      1) create_universal_account ;;
      2) list_accounts ;;
      3) lock_unlock_account ;;
      4) extend_account ;;
      5) delete_account ;;
      6) view_online_users ;;
      7) restart_services ;;
      8) generate_v2ray_links ;;
      9) run_speedtest ;;
      10) reboot_server ;;
      11) update_system ;;
      12) uninstall_system ;;
      0) echo -e "\n${GREEN}Exiting Manager. Have a great day!${NC}\n"; exit 0 ;;
      *) echo -e "\n${RED}Invalid option! Press enter or 0 to return...${NC}"; read ;;
    esac
  done
}

create_universal_account() {
  clear
  echo -e "${CYAN}--- CREATE UNIVERSAL MULTI-PROTOCOL ACCOUNT ---${NC}"
  echo -e "${YELLOW}(Type 0 at any prompt to cancel and return to main menu)${NC}\n"
  read -p " Enter Username (or 0 to cancel): " username
  if [ "$username" = "0" ] || [ -z "$username" ]; then return; fi

  if id "$username" &>/dev/null; then echo -e "${RED}User '$username' already exists!${NC}"; read -p "Press 0 to return..."; return; fi

  read -p " Enter Password: " password
  if [ "$password" = "0" ]; then return; fi

  read -p " Enter Max Concurrent Logins (Devices): " max_logins
  read -p " Enter Duration in Days (Type 0 for LIFETIME): " days

  if [ "$days" -eq 0 ] 2>/dev/null; then
    EXP_STR="LIFETIME (Never Expires)"
    useradd -M -s /bin/false "$username"
    chage -E -1 "$username"
  else
    EXP_DATE=$(date -d "+$days days" +%Y-%m-%d)
    EXP_STR="$EXP_DATE ($days days)"
    useradd -e "$EXP_DATE" -M -s /bin/false "$username"
  fi

  echo "$username:$password" | chpasswd
  UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "e4a781b2-93c4-4b52-a1e9-8f7d6c5b4a3e")
  SERVER_IP=$(curl -s https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')
  SSL_DOMAIN=$(cat /etc/vps-tunnel/ssl_domain 2>/dev/null || echo "$SERVER_IP")

  VMESS_JSON="{\"v\":\"2\",\"ps\":\"$username-VMess\",\"add\":\"$SSL_DOMAIN\",\"port\":8443,\"id\":\"$UUID\",\"aid\":0,\"net\":\"ws\",\"type\":\"none\",\"path\":\"/vmess\",\"tls\":\"tls\"}"
  VMESS_B64=$(echo -n "$VMESS_JSON" | base64 -w 0 2>/dev/null || echo -n "$VMESS_JSON" | base64)
  VMESS_URL="vmess://$VMESS_B64"
  VLESS_URL="vless://$UUID@$SSL_DOMAIN:8443?encryption=none&security=tls&type=ws&path=/vless#$username-VLess"
  TROJAN_URL="trojan://$password@$SSL_DOMAIN:443?security=tls&type=grpc&serviceName=trojan-grpc#$username-Trojan"
  SS_PASS_B64=$(echo -n "aes-128-gcm:$password" | base64 -w 0 2>/dev/null || echo -n "aes-128-gcm:$password" | base64)
  SS_URL="ss://$SS_PASS_B64@$SERVER_IP:8388#$username-SS2022"

  echo -e "\n${GREEN}=================================================================${NC}"
  echo -e "       ${GREEN}[SUCCESS] UNIVERSAL ACCOUNT CREATED SUCCESSFULLY!${NC}"
  echo -e "${GREEN}=================================================================${NC}"
  echo -e " ${CYAN}Username:${NC}    $username"
  echo -e " ${CYAN}Password:${NC}    $password"
  echo -e " ${CYAN}V2Ray UUID:${NC}  $UUID"
  echo -e " ${CYAN}Validity:${NC}    $EXP_STR"
  echo -e " ${CYAN}Max Devices:${NC} $max_logins"
  echo -e "${CYAN}-----------------------------------------------------------------${NC}"
  echo -e "      ${YELLOW}ALL PROTOCOLS CONFIGURATION & STEP-BY-STEP USAGE GUIDE${NC}"
  echo -e "${CYAN}-----------------------------------------------------------------${NC}"
  echo -e " ${GREEN}[1] OpenSSH Direct:${NC}      Host: $SERVER_IP | Ports: 22, 109, 143"
  echo -e "     ${PURPLE}How to use:${NC}         Select SSH Direct in HTTP Injector/Bitvise."
  echo -e " ${GREEN}[2] Dropbear SSH:${NC}        Host: $SERVER_IP | Ports: 110, 456"
  echo -e " ${GREEN}[3] Stunnel SSL/TLS:${NC}     Host: $SERVER_IP | Ports: 443, 444 | SNI: $SSL_DOMAIN"
  echo -e "     ${PURPLE}How to use:${NC}         Set Mode: SSL/TLS + SNI Bug Host."
  echo -e " ${GREEN}[4] SSH WebSocket:${NC}       WS HTTP: 80 | WS HTTPS: 8880 | Path: /"
  echo -e "     ${PURPLE}Payload String:${NC}     GET / HTTP/1.1[crlf]Host: [host][crlf]Upgrade: websocket[crlf][crlf]"
  echo -e " ${GREEN}[5] UDP Custom (ZiVPN):${NC} Host: $SERVER_IP | UDP Port: 7300 | DNS: 53"
  echo -e "     ${PURPLE}How to use:${NC}         Open ZiVPN App -> Enter IP, 7300, User, Pass -> Connect."
  echo -e " ${GREEN}[6] BadVPN UDPGW:${NC}        Ports: 7100, 7200, 7300 (VoIP & Gaming Forwarder)"
  echo -e " ${GREEN}[7] SlowDNS (DNSTT):${NC}    NS: dns.$SSL_DOMAIN | PubKey: 1122334455667788 | DNS: 1.1.1.1"
  echo -e "     ${PURPLE}How to use:${NC}         Open SlowDNS app -> Enter NS Subdomain & PubKey."
  echo -e " ${GREEN}[8] V2Ray VMess WS:${NC}     $VMESS_URL"
  echo -e " ${GREEN}[9] V2Ray VLess XTLS:${NC}   $VLESS_URL"
  echo -e " ${GREEN}[10] Trojan gRPC:${NC}       $TROJAN_URL"
  echo -e " ${GREEN}[11] Shadowsocks 2022:${NC}  $SS_URL"
  echo -e " ${GREEN}[12] OpenVPN (UDP/TCP):${NC} Ports: 1194 (UDP) / 443 (TCP) | PAM Auth"
  echo -e "      ${PURPLE}How to use:${NC}        Download .ovpn profile file from Web Dashboard."
  echo -e "${CYAN}=================================================================${NC}"
  echo -e "\n${YELLOW}Press enter or type 0 to return to main menu...${NC}"; read
}

list_accounts() {
  clear
  echo -e "${CYAN}--- ALL REGISTERED UNIVERSAL ACCOUNTS ---${NC}\n"
  printf "%-18s %-16s %-38s %-18s\n" "USERNAME" "PASSWORD" "V2RAY UUID" "EXPIRATION"
  echo "---------------------------------------------------------------------------------------------------"
  for user in $(awk -F: '$3 >= 1000 {print $1}' /etc/passwd); do
    EXP=$(chage -l "$user" | grep "Account expires" | cut -d: -f2)
    EXP_DISP=$([ "$EXP" = " never" ] && echo "LIFETIME" || echo $EXP | xargs)
    printf "%-18s %-16s %-38s %-18s\n" "$user" "********" "$(cat /proc/sys/kernel/random/uuid | cut -c1-18)..." "$EXP_DISP"
  done
  echo -e "\n${YELLOW}Press enter or type 0 to return to menu...${NC}"; read
}

lock_unlock_account() {
  clear
  read -p " Enter Username to Lock/Unlock (or 0 to return): " username
  if [ "$username" = "0" ] || [ -z "$username" ]; then return; fi
  if ! id "$username" &>/dev/null; then echo -e "${RED}User not found!${NC}"; read; return; fi

  STATUS=$(passwd -S "$username" | awk '{print $2}')
  if [ "$STATUS" = "L" ]; then
    usermod -U "$username"
    echo -e "${GREEN}User '$username' UNLOCKED!${NC}"
  else
    usermod -L "$username"
    echo -e "${YELLOW}User '$username' LOCKED!${NC}"
  fi
  echo -e "\n${YELLOW}Press enter or type 0 to return to menu...${NC}"; read
}

extend_account() {
  clear
  read -p " Enter Username to Extend (or 0 to return): " username
  if [ "$username" = "0" ] || [ -z "$username" ]; then return; fi
  if ! id "$username" &>/dev/null; then echo -e "${RED}User not found!${NC}"; read; return; fi

  read -p " Enter Days to Add (Type 0 for LIFETIME): " days
  if [ "$days" -eq 0 ] 2>/dev/null; then
    chage -E -1 "$username"
    echo -e "${GREEN}User '$username' set to LIFETIME!${NC}"
  else
    EXP_DATE=$(date -d "+$days days" +%Y-%m-%d)
    chage -E "$EXP_DATE" "$username"
    echo -e "${GREEN}User '$username' extended to $EXP_DATE!${NC}"
  fi
  echo -e "\n${YELLOW}Press enter or type 0 to return to menu...${NC}"; read
}

delete_account() {
  clear
  read -p " Enter Username to Delete (or 0 to return): " username
  if [ "$username" = "0" ] || [ -z "$username" ]; then return; fi
  if ! id "$username" &>/dev/null; then echo -e "${RED}User not found!${NC}"; read; return; fi
  userdel -f "$username"
  echo -e "${GREEN}User '$username' deleted!${NC}"
  echo -e "\n${YELLOW}Press enter or type 0 to return to menu...${NC}"; read
}

view_online_users() {
  clear
  echo -e "${CYAN}--- ACTIVE TUNNEL CONNECTIONS ---${NC}\n"
  who
  echo -e "\n${YELLOW}Press enter or type 0 to return to menu...${NC}"; read
}

restart_services() {
  clear
  echo -e "${YELLOW}Restarting OpenSSH, Stunnel, WS Proxy, BadVPN, and Xray...${NC}"
  systemctl restart ssh dropbear stunnel4 ws-proxy badvpn-7300 xray 2>/dev/null
  echo -e "${GREEN}All services restarted successfully!${NC}"
  echo -e "\n${YELLOW}Press enter or type 0 to return to menu...${NC}"; read
}

generate_v2ray_links() {
  clear
  read -p " Enter Username for V2Ray Links (or 0 to return): " username
  if [ "$username" = "0" ] || [ -z "$username" ]; then return; fi
  DOMAIN=$(curl -s ifconfig.me || echo "vpn.server.com")
  UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null)

  echo -e "\n${CYAN}--- V2RAY / XRAY CLIENT IMPORTS ($username) ---${NC}\n"
  echo -e "${PURPLE}VMess WS:${NC} vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"$username-VMess\",\"add\":\"$DOMAIN\",\"port\":10085,\"id\":\"$UUID\",\"net\":\"ws\",\"path\":\"/vmess\",\"tls\":\"tls\"}" | base64 -w 0)"
  echo -e "\n${PURPLE}VLess XTLS:${NC} vless://$UUID@$DOMAIN:20085?security=tls&type=ws&path=/vless#$username-VLess"
  echo -e "\n${PURPLE}Trojan gRPC:${NC} trojan://pass123@$DOMAIN:30085?security=tls&type=grpc#$username-Trojan"
  echo -e "\n${YELLOW}Press enter or type 0 to return to menu...${NC}"; read
}

run_speedtest() {
  clear
  echo -e "${YELLOW}Running Speedtest...${NC}\n"
  curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -
  echo -e "\n${YELLOW}Press enter or type 0 to return to menu...${NC}"; read
}

reboot_server() {
  clear
  read -p " Are you sure you want to REBOOT the VPS? (y/n or 0 to return): " confirm
  if [ "$confirm" = "y" ]; then reboot; fi
}

update_system() {
  clear
  echo -e "${CYAN}Updating VPS Manager codebase from GitHub...${NC}"
  cd /usr/local/vps-manager && git pull origin main && npm install --production
  systemctl restart vps-web-dashboard
  echo -e "${GREEN}Update completed! Dashboard restarted.${NC}"
  echo -e "\n${YELLOW}Press enter or type 0 to return to menu...${NC}"; read
}

uninstall_system() {
  clear
  echo -e "${RED}WARNING: This will purge all services and delete the manager!${NC}"
  read -p " Type 'PURGE' to confirm uninstallation (or 0 to cancel): " confirm
  if [ "$confirm" = "PURGE" ]; then
    bash /usr/local/vps-manager/scripts/uninstall.sh
    exit 0
  fi
}

show_menu
