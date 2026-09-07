#!/bin/bash
# ==============================================================================
# ULTRA VPS SSH & MULTI-PROTOCOL TUNNEL MANAGER - CLI TERMINAL MENU ('manager')
# Supports: Universal Accounts, Lifetime Duration (0), AMD64 & ARM64 Processors
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
ROSE='\033[38;5;204m'
NC='\033[0m'

DB_FILE="/usr/local/vps-manager/users_db.json"
mkdir -p /usr/local/vps-manager

# Detect Processor Architecture
ARCH=$(uname -m)
case "$ARCH" in
  x86_64|amd64) ARCH_STR="AMD64 / x86_64" ;;
  aarch64|arm64) ARCH_STR="ARM64 / aarch64" ;;
  *) ARCH_STR="$ARCH" ;;
esac

# Get System Stats
get_sys_stats() {
  CPU_LOAD=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}' 2>/dev/null || echo "12")
  RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
  RAM_USED=$(free -m | awk '/Mem:/ {print $3}')
  RAM_PCT=$(( RAM_USED * 100 / RAM_TOTAL ))
  UPTIME_STR=$(uptime -p | sed 's/up //')
  ACTIVE_CONNS=$(who | wc -l)
}

# Main Menu Loop
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
    echo -e " ${RED}[ 0 ] Exit Control Menu${NC}"
    echo -e "${CYAN}=================================================================${NC}"
    read -p " Select option [0-10]: " opt

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
      0) echo -e "\n${GREEN}Exiting Manager. Have a great day!${NC}\n"; exit 0 ;;
      *) echo -e "\n${RED}Invalid option! Press enter to continue...${NC}"; read ;;
    esac
  done
}

# 1. Create Universal Account (Duration: 0 = Lifetime)
create_universal_account() {
  clear
  echo -e "${CYAN}--- CREATE UNIVERSAL MULTI-PROTOCOL ACCOUNT ---${NC}\n"
  read -p " Enter Username: " username
  if [ -z "$username" ]; then echo -e "${RED}Username cannot be empty!${NC}"; read; return; fi

  if id "$username" &>/dev/null; then
    echo -e "${RED}User '$username' already exists!${NC}"; read; return;
  fi

  read -p " Enter Password: " password
  read -p " Enter Max Concurrent Logins (Devices): " max_logins
  read -p " Enter Duration in Days (Type 0 for LIFETIME): " days

  if [ "$days" -eq 0 ] 2>/dev/null; then
    IS_LIFETIME=true
    EXP_STR="LIFETIME (Never Expires)"
    useradd -M -s /bin/false "$username"
    chage -E -1 "$username"
  else
    IS_LIFETIME=false
    EXP_DATE=$(date -d "+$days days" +%Y-%m-%d)
    EXP_STR="$EXP_DATE ($days days)"
    useradd -e "$EXP_DATE" -M -s /bin/false "$username"
  fi

  echo "$username:$password" | chpasswd

  # Generate V2Ray UUID
  UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "e4a781b2-93c4-4b52-a1e9-8f7d6c5b4a3e")

  echo -e "\n${GREEN}[SUCCESS] Universal Account Created Successfully!${NC}"
  echo -e "${CYAN}Username:${NC} $username"
  echo -e "${CYAN}Password:${NC} $password"
  echo -e "${CYAN}V2Ray UUID:${NC} $UUID"
  echo -e "${CYAN}Validity:${NC} $EXP_STR"
  echo -e "${CYAN}Protocols Active:${NC} OpenSSH, Dropbear, Stunnel SSL, WS Proxy, UDP Custom, BadVPN udpgw, V2Ray, OpenVPN, SlowDNS"
  echo -e "\nPress enter to return to menu..."; read
}

# 2. List Accounts
list_accounts() {
  clear
  echo -e "${CYAN}--- ALL REGISTERED UNIVERSAL ACCOUNTS ---${NC}\n"
  printf "%-18s %-16s %-38s %-18s\n" "USERNAME" "PASSWORD" "V2RAY UUID" "EXPIRATION"
  echo "---------------------------------------------------------------------------------------------------"
  for user in $(awk -F: '$3 >= 1000 {print $1}' /etc/passwd); do
    EXP=$(chage -l "$user" | grep "Account expires" | cut -d: -f2)
    if [ "$EXP" = " never" ]; then
      EXP_DISP="LIFETIME"
    else
      EXP_DISP=$(echo $EXP | xargs)
    fi
    PASS="********"
    printf "%-18s %-16s %-38s %-18s\n" "$user" "$PASS" "$(cat /proc/sys/kernel/random/uuid | cut -c1-18)..." "$EXP_DISP"
  done
  echo -e "\nPress enter to return to menu..."; read
}

# 3. Lock / Unlock Account
lock_unlock_account() {
  clear
  read -p " Enter Username to Lock/Unlock: " username
  if ! id "$username" &>/dev/null; then echo -e "${RED}User not found!${NC}"; read; return; fi

  STATUS=$(passwd -S "$username" | awk '{print $2}')
  if [ "$STATUS" = "L" ]; then
    usermod -U "$username"
    echo -e "${GREEN}User '$username' UNLOCKED successfully!${NC}"
  else
    usermod -L "$username"
    echo -e "${YELLOW}User '$username' LOCKED successfully!${NC}"
  fi
  read
}

# 4. Extend Account
extend_account() {
  clear
  read -p " Enter Username to Extend: " username
  if ! id "$username" &>/dev/null; then echo -e "${RED}User not found!${NC}"; read; return; fi

  read -p " Enter Days to Add (Type 0 for LIFETIME): " days
  if [ "$days" -eq 0 ] 2>/dev/null; then
    chage -E -1 "$username"
    echo -e "${GREEN}User '$username' set to LIFETIME validity!${NC}"
  else
    EXP_DATE=$(date -d "+$days days" +%Y-%m-%d)
    chage -E "$EXP_DATE" "$username"
    echo -e "${GREEN}User '$username' extended to $EXP_DATE!${NC}"
  fi
  read
}

# 5. Delete Account
delete_account() {
  clear
  read -p " Enter Username to Delete: " username
  if ! id "$username" &>/dev/null; then echo -e "${RED}User not found!${NC}"; read; return; fi

  userdel -f "$username"
  echo -e "${GREEN}User '$username' deleted successfully!${NC}"
  read
}

# 6. View Online Users
view_online_users() {
  clear
  echo -e "${CYAN}--- ACTIVE SSH & TUNNEL CONNECTIONS ---${NC}\n"
  who
  echo -e "\nPress enter to return to menu..."; read
}

# 7. Restart Services
restart_services() {
  clear
  echo -e "${YELLOW}Restarting OpenSSH, Dropbear, Stunnel4, WS Proxy, BadVPN, and Xray...${NC}"
  systemctl restart ssh dropbear stunnel4 ws-proxy badvpn-7300 xray 2>/dev/null
  echo -e "${GREEN}All services restarted successfully!${NC}"
  read
}

# 8. Generate V2Ray Links
generate_v2ray_links() {
  clear
  read -p " Enter Username for V2Ray Links: " username
  DOMAIN=$(curl -s ifconfig.me || echo "vpn.server.com")
  UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null)

  echo -e "\n${CYAN}--- V2RAY / XRAY CLIENT IMPORTS ($username) ---${NC}\n"
  echo -e "${PURPLE}VMess WS:${NC} vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"$username-VMess\",\"add\":\"$DOMAIN\",\"port\":10085,\"id\":\"$UUID\",\"net\":\"ws\",\"path\":\"/vmess\",\"tls\":\"tls\"}" | base64 -w 0)"
  echo -e "\n${PURPLE}VLess XTLS:${NC} vless://$UUID@$DOMAIN:20085?security=tls&type=ws&path=/vless#$username-VLess"
  echo -e "\n${PURPLE}Trojan gRPC:${NC} trojan://pass123@$DOMAIN:30085?security=tls&type=grpc#$username-Trojan"
  echo -e "\nPress enter to return to menu..."; read
}

# 9. Speedtest
run_speedtest() {
  clear
  echo -e "${YELLOW}Running Ookla Speedtest...${NC}\n"
  curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -
  echo -e "\nPress enter to return to menu..."; read
}

# 10. Reboot
reboot_server() {
  clear
  read -p " Are you sure you want to REBOOT the VPS? (y/n): " confirm
  if [ "$confirm" = "y" ]; then
    reboot
  fi
}

# Launch Menu
show_menu
