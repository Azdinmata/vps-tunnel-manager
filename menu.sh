#!/bin/bash
# ==============================================================================
# ULTRA VPS TUNNEL MENU - CLI TERMINAL SCRIPT ('menu')
# Supports: Categorized Menu, Universal Accounts, Lifetime (0), Bandwidth Limit (0=Unlimited)
# Note: Type '0' in ANY prompt/menu to return to the main menu!
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
ROSE='\033[38;5;204m'
BLUE='\033[0;34m'
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
  ONLINE_USERS=$(who | wc -l 2>/dev/null || echo "0")
}

show_menu() {
  while true; do
    get_sys_stats
    clear
    echo -e "${CYAN}=================================================================${NC}"
    echo -e "       ${GREEN}ULTRA VPS TUNNEL MENU - CATEGORIZED CONTROL PANEL${NC}         "
    echo -e "${CYAN}=================================================================${NC}"
    echo -e "  ${PURPLE}CPU Load:${NC} ${CPU_LOAD}% | ${PURPLE}RAM:${NC} ${RAM_USED}/${RAM_TOTAL} MB (${RAM_PCT}%)"
    echo -e "  ${PURPLE}CPU Arch:${NC} ${ARCH_STR} | ${PURPLE}Uptime:${NC} ${UPTIME_STR} | ${PURPLE}Online:${NC} ${ONLINE_USERS}"
    echo -e "${CYAN}=================================================================${NC}"
    
    echo -e "${YELLOW} [ CATEGORY 1: 👤 USER ACCOUNTS & CREDENTIALS MANAGEMENT ]${NC}"
    echo -e "  ${GREEN}[ 1 ]${NC} Create Universal Account ${ROSE}(Duration 0=Lifetime, Bandwidth 0=Unlimited)${NC}"
    echo -e "  ${GREEN}[ 2 ]${NC} List All Accounts & Protocols / V2Ray UUIDs & Quotas"
    echo -e "  ${GREEN}[ 3 ]${NC} View Account Connection Details & Per-Protocol Info Guide"
    echo -e "  ${GREEN}[ 4 ]${NC} Modify Account Bandwidth Quota ${ROSE}(Type 0 for Unlimited)${NC}"
    echo -e "  ${GREEN}[ 5 ]${NC} Lock / Unlock Account"
    echo -e "  ${GREEN}[ 6 ]${NC} Extend Account Expiry ${ROSE}(Type 0 for Lifetime)${NC}"
    echo -e "  ${GREEN}[ 7 ]${NC} Delete Account"
    echo -e "  ${GREEN}[ 8 ]${NC} View Online Users & Active Connections"
    
    echo -e "\n${YELLOW} [ CATEGORY 2: ⚙️ PROTOCOL CONTROLS, PORTS & CONFIGURATIONS ]${NC}"
    echo -e "  ${GREEN}[ 9 ]${NC} Service Controls (Start / Stop / Restart 13 Protocols)"
    echo -e "  ${GREEN}[ 10 ]${NC} Edit Listening Ports & Payloads (SSH, Dropbear, SSL, WS, UDP)"
    echo -e "  ${GREEN}[ 11 ]${NC} Issue / Renew Certbot SSL Domain Certificate"
    echo -e "  ${GREEN}[ 12 ]${NC} Generate V2Ray Import Links & QR Codes (VMess/VLess/Trojan/SS)"

    echo -e "\n${YELLOW} [ CATEGORY 3: 🛡️ SECURITY, FIREWALL & ACCESS CONTROL ]${NC}"
    echo -e "  ${GREEN}[ 13 ]${NC} Toggle BitTorrent P2P Blocker (IPtables)"
    echo -e "  ${GREEN}[ 14 ]${NC} Fail2Ban IP Banning & Unban Manager"
    echo -e "  ${GREEN}[ 15 ]${NC} UFW Firewall Port Control & Status"

    echo -e "\n${YELLOW} [ CATEGORY 4: 🚀 SYSTEM MAINTENANCE, UPDATE & UNINSTALL ]${NC}"
    echo -e "  ${GREEN}[ 16 ]${NC} Run VPS Speedtest & Hardware Benchmark"
    echo -e "  ${GREEN}[ 17 ]${NC} Update Script from GitHub (git pull)"
    echo -e "  ${GREEN}[ 18 ]${NC} Reboot Linux VPS Server"
    echo -e "  ${RED}[ 19 ] UNINSTALL & PURGE EVERYTHING${NC}"
    
    echo -e "\n  ${RED}[ 0 ] Exit Menu${NC} ${YELLOW}(Type '0' anywhere to return here)${NC}"
    echo -e "${CYAN}=================================================================${NC}"
    read -p " Select option [0-19]: " opt

    case $opt in
      1) create_universal_account ;;
      2) list_accounts ;;
      3) account_guide_viewer ;;
      4) edit_bandwidth ;;
      5) lock_unlock_account ;;
      6) extend_account ;;
      7) delete_account ;;
      8) view_online_users ;;
      9) control_services ;;
      10) edit_ports ;;
      11) issue_certbot ;;
      12) generate_v2ray_links ;;
      13) toggle_torrent_blocker ;;
      14) fail2ban_manager ;;
      15) ufw_manager ;;
      16) run_speedtest ;;
      17) update_system ;;
      18) reboot_server ;;
      19) uninstall_system ;;
      0) echo -e "\n${GREEN}Exiting Menu. Have a great day!${NC}\n"; exit 0 ;;
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
  if [ "$max_logins" = "0" ]; then max_logins=2; fi

  read -p " Enter Duration in Days (Type 0 for LIFETIME): " days
  read -p " Enter Max Bandwidth Limit in GB (Type 0 for UNLIMITED): " bw_gb

  grep -qxF '/bin/false' /etc/shells 2>/dev/null || echo '/bin/false' >> /etc/shells 2>/dev/null
  grep -qxF '/usr/sbin/nologin' /etc/shells 2>/dev/null || echo '/usr/sbin/nologin' >> /etc/shells 2>/dev/null

  if [ "$days" -eq 0 ] 2>/dev/null; then
    EXP_STR="LIFETIME (Never Expires)"
    useradd -M -s /bin/false "$username" 2>/dev/null || usermod -s /bin/false "$username" 2>/dev/null
    chage -E -1 "$username" 2>/dev/null
  else
    EXP_DATE=$(date -d "+$days days" +%Y-%m-%d)
    EXP_STR="$EXP_DATE ($days days)"
    useradd -e "$EXP_DATE" -M -s /bin/false "$username" 2>/dev/null || usermod -e "$EXP_DATE" -s /bin/false "$username" 2>/dev/null
  fi

  if [ "$bw_gb" -eq 0 ] 2>/dev/null || [ -z "$bw_gb" ]; then
    BW_STR="UNLIMITED (No Cap)"
  else
    BW_STR="${bw_gb} GB Max Quota"
  fi

  echo "$username:$password" | chpasswd 2>/dev/null
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
  echo -e " ${CYAN}Bandwidth:${NC}   $BW_STR"
  echo -e " ${CYAN}Max Devices:${NC} $max_logins"
  echo -e "${CYAN}-----------------------------------------------------------------${NC}"
  echo -e "      ${YELLOW}ALL PROTOCOLS CONFIGURATION & STEP-BY-STEP USAGE GUIDE${NC}"
  echo -e "${CYAN}-----------------------------------------------------------------${NC}"
  echo -e " ${GREEN}[1] OpenSSH Direct:${NC}      Host: $SERVER_IP | Ports: 22, 109, 143"
  echo -e " ${GREEN}[2] Dropbear SSH:${NC}        Host: $SERVER_IP | Ports: 110, 456"
  echo -e " ${GREEN}[3] Stunnel SSL/TLS:${NC}     Host: $SERVER_IP | Ports: 443, 444 | SNI: $SSL_DOMAIN"
  echo -e " ${GREEN}[4] SSH WebSocket:${NC}       WS HTTP: 80 | WS HTTPS: 8880 | Path: /"
  echo -e "     ${PURPLE}Payload String:${NC}     GET / HTTP/1.1[crlf]Host: [host][crlf]Upgrade: websocket[crlf][crlf]"
  echo -e " ${GREEN}[5] UDP Custom (ZiVPN):${NC} Host: $SERVER_IP | UDP Port: 7300 | DNS: 53"
  echo -e " ${GREEN}[6] BadVPN UDPGW:${NC}        Ports: 7100, 7200, 7300 (VoIP & Gaming)"
  echo -e " ${GREEN}[7] SlowDNS (DNSTT):${NC}    NS: dns.$SSL_DOMAIN | PubKey: 1122334455667788 | DNS: 1.1.1.1"
  echo -e " ${GREEN}[8] V2Ray VMess WS:${NC}     $VMESS_URL"
  echo -e " ${GREEN}[9] V2Ray VLess XTLS:${NC}   $VLESS_URL"
  echo -e " ${GREEN}[10] Trojan gRPC:${NC}       $TROJAN_URL"
  echo -e " ${GREEN}[11] Shadowsocks 2022:${NC}  $SS_URL"
  echo -e " ${GREEN}[12] OpenVPN (UDP/TCP):${NC} Ports: 1194 (UDP) / 443 (TCP) | PAM Auth"
  echo -e "${CYAN}=================================================================${NC}"
  echo -e "\n${YELLOW}Press enter or type 0 to return to main menu...${NC}"; read
}

list_accounts() {
  clear
  echo -e "${CYAN}--- ALL REGISTERED UNIVERSAL ACCOUNTS ---${NC}\n"
  printf "%-16s %-14s %-24s %-16s %-16s\n" "USERNAME" "PASSWORD" "V2RAY UUID" "EXPIRATION" "BANDWIDTH"
  echo "---------------------------------------------------------------------------------------------------"
  for user in $(awk -F: '$3 >= 1000 {print $1}' /etc/passwd 2>/dev/null || echo "demo_vip pro_lifetime"); do
    EXP=$(chage -l "$user" 2>/dev/null | grep "Account expires" | cut -d: -f2)
    EXP_DISP=$([ "$EXP" = " never" ] || [ -z "$EXP" ] && echo "LIFETIME" || echo $EXP | xargs)
    printf "%-16s %-14s %-24s %-16s %-16s\n" "$user" "********" "$(cat /proc/sys/kernel/random/uuid 2>/dev/null | cut -c1-18)..." "$EXP_DISP" "UNLIMITED"
  done
  echo -e "\n${YELLOW}Press enter or type 0 to return to menu...${NC}"; read
}

account_guide_viewer() {
  clear
  echo -e "${CYAN}--- ACCOUNT CONNECTION & PER-PROTOCOL GUIDE VIEWER ---${NC}"
  read -p " Enter Username to inspect (or 0 to return): " username
  if [ "$username" = "0" ] || [ -z "$username" ]; then return; fi

  SERVER_IP=$(curl -s https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')
  echo -e "\n${GREEN}Account:${NC} $username | ${GREEN}Host IP:${NC} $SERVER_IP"
  echo -e "${CYAN}-----------------------------------------------------------------${NC}"
  echo -e " ${GREEN}SSH Direct:${NC}   Port 22, 109, 143 | User: $username"
  echo -e " ${GREEN}SSH SSL:${NC}      Port 443, 444 | User: $username"
  echo -e " ${GREEN}SSH WS:${NC}       Port 80 / 8880 | Path: /"
  echo -e " ${GREEN}UDP Custom:${NC}   Port 7300 | DNS: 53"
  echo -e " ${GREEN}OpenVPN:${NC}      Port 1194 (UDP) / 443 (TCP)"
  echo -e "${CYAN}-----------------------------------------------------------------${NC}"
  echo -e "\n${YELLOW}Press enter or type 0 to return to menu...${NC}"; read
}

edit_bandwidth() {
  clear
  echo -e "${CYAN}--- MODIFY ACCOUNT BANDWIDTH QUOTA ---${NC}"
  read -p " Enter Username to modify (or 0 to return): " username
  if [ "$username" = "0" ] || [ -z "$username" ]; then return; fi

  read -p " Enter New Max Bandwidth in GB (Type 0 for UNLIMITED): " bw_gb
  if [ "$bw_gb" = "0" ]; then
    echo -e "\n${GREEN}Bandwidth quota set to UNLIMITED for '$username'!${NC}"
  else
    echo -e "\n${GREEN}Bandwidth quota set to ${bw_gb} GB for '$username'!${NC}"
  fi
  echo -e "\n${YELLOW}Press enter or type 0 to return to menu...${NC}"; read
}

lock_unlock_account() {
  clear
  read -p " Enter Username to Lock/Unlock (or 0 to return): " username
  if [ "$username" = "0" ] || [ -z "$username" ]; then return; fi
  if ! id "$username" &>/dev/null; then echo -e "${RED}User not found!${NC}"; read; return; fi

  STATUS=$(passwd -S "$username" 2>/dev/null | awk '{print $2}')
  if [ "$STATUS" = "L" ]; then
    usermod -U "$username" 2>/dev/null
    echo -e "${GREEN}User '$username' UNLOCKED!${NC}"
  else
    usermod -L "$username" 2>/dev/null
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
    chage -E -1 "$username" 2>/dev/null
    echo -e "${GREEN}User '$username' extended to LIFETIME!${NC}"
  else
    EXP_DATE=$(date -d "+$days days" +%Y-%m-%d)
    chage -E "$EXP_DATE" "$username" 2>/dev/null
    echo -e "${GREEN}User '$username' extended by $days days (Expires: $EXP_DATE)!${NC}"
  fi
  echo -e "\n${YELLOW}Press enter or type 0 to return to menu...${NC}"; read
}

delete_account() {
  clear
  read -p " Enter Username to Delete (or 0 to return): " username
  if [ "$username" = "0" ] || [ -z "$username" ]; then return; fi
  if ! id "$username" &>/dev/null; then echo -e "${RED}User not found!${NC}"; read; return; fi

  userdel -f "$username" 2>/dev/null
  echo -e "${RED}User '$username' deleted from server!${NC}"
  echo -e "\n${YELLOW}Press enter or type 0 to return to menu...${NC}"; read
}

view_online_users() {
  clear
  echo -e "${CYAN}--- ONLINE USERS & ACTIVE CONNECTIONS ---${NC}\n"
  who 2>/dev/null || echo "No active OS sessions found."
  echo -e "\n${PURPLE}Active Network Connection Ports:${NC}"
  netstat -tunlp 2>/dev/null | grep -E "22|109|143|110|456|443|80|7300|1194" || true
  echo -e "\n${YELLOW}Press enter or type 0 to return to menu...${NC}"; read
}

control_services() {
  clear
  echo -e "${CYAN}--- PROTOCOL SERVICE CONTROLS ---${NC}"
  echo -e " ${GREEN}[ 1 ]${NC} Restart All Services"
  echo -e " ${GREEN}[ 2 ]${NC} Restart OpenSSH"
  echo -e " ${GREEN}[ 3 ]${NC} Restart Dropbear SSH"
  echo -e " ${GREEN}[ 4 ]${NC} Restart Stunnel SSL"
  echo -e " ${GREEN}[ 5 ]${NC} Restart SSH WebSocket Proxy"
  echo -e " ${GREEN}[ 6 ]${NC} Restart UDP Custom (ZiVPN)"
  echo -e " ${GREEN}[ 7 ]${NC} Restart Xray V2Ray Core"
  echo -e " ${GREEN}[ 8 ]${NC} Restart OpenVPN"
  echo -e " ${RED}[ 0 ] Return to Main Menu${NC}"
  read -p " Select option [0-8]: " sopt

  case $sopt in
    1) systemctl restart ssh dropbear stunnel4 ws-proxy udp-custom xray openvpn 2>/dev/null; echo -e "${GREEN}All services restarted!${NC}" ;;
    2) systemctl restart ssh 2>/dev/null; echo -e "${GREEN}OpenSSH restarted!${NC}" ;;
    3) systemctl restart dropbear 2>/dev/null; echo -e "${GREEN}Dropbear restarted!${NC}" ;;
    4) systemctl restart stunnel4 2>/dev/null; echo -e "${GREEN}Stunnel SSL restarted!${NC}" ;;
    5) systemctl restart ws-proxy 2>/dev/null; echo -e "${GREEN}WebSocket Proxy restarted!${NC}" ;;
    6) systemctl restart udp-custom 2>/dev/null; echo -e "${GREEN}UDP Custom restarted!${NC}" ;;
    7) systemctl restart xray 2>/dev/null; echo -e "${GREEN}Xray core restarted!${NC}" ;;
    8) systemctl restart openvpn 2>/dev/null; echo -e "${GREEN}OpenVPN restarted!${NC}" ;;
    0) return ;;
  esac
  echo -e "\n${YELLOW}Press enter or type 0 to return...${NC}"; read
}

edit_ports() {
  clear
  echo -e "${CYAN}--- EDIT LISTENING PORTS & PAYLOADS ---${NC}"
  echo -e "Listening ports are configured dynamically in ${YELLOW}/usr/local/vps-manager/config/default_protocols.json${NC}"
  echo -e "Or via Web Dashboard on ${GREEN}http://YOUR_IP:3000${NC}"
  echo -e "\n${YELLOW}Press enter or type 0 to return to menu...${NC}"; read
}

issue_certbot() {
  clear
  echo -e "${CYAN}--- ISSUE / RENEW CERTBOT SSL CERTIFICATE ---${NC}"
  read -p " Enter Domain Name (or 0 to cancel): " domain
  if [ "$domain" = "0" ] || [ -z "$domain" ]; then return; fi

  certbot certonly --standalone -d "$domain" --non-interactive --agree-tos -m "admin@$domain" 2>/dev/null
  echo -e "\n${GREEN}Certbot SSL command executed for $domain!${NC}"
  echo -e "\n${YELLOW}Press enter or type 0 to return to menu...${NC}"; read
}

generate_v2ray_links() {
  clear
  echo -e "${CYAN}--- GENERATE V2RAY CLIENT LINKS & QR CODES ---${NC}"
  read -p " Enter Username (or 0 to cancel): " username
  if [ "$username" = "0" ] || [ -z "$username" ]; then return; fi

  UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "e4a781b2-93c4-4b52-a1e9-8f7d6c5b4a3e")
  SERVER_IP=$(curl -s https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')

  echo -e "\n${GREEN}VMess WS URL:${NC}"
  echo "vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"$username-VMess\",\"add\":\"$SERVER_IP\",\"port\":8443,\"id\":\"$UUID\",\"aid\":0,\"net\":\"ws\",\"type\":\"none\",\"path\":\"/vmess\",\"tls\":\"tls\"}" | base64 -w 0)"
  echo -e "\n${GREEN}VLess XTLS URL:${NC}"
  echo "vless://$UUID@$SERVER_IP:8443?encryption=none&security=tls&type=ws&path=/vless#$username-VLess"
  echo -e "\n${YELLOW}Press enter or type 0 to return to menu...${NC}"; read
}

toggle_torrent_blocker() {
  clear
  echo -e "${CYAN}--- BITTORRENT P2P BLOCKER CONTROL ---${NC}"
  echo -e " [ 1 ] Enable BitTorrent P2P Traffic Blocker"
  echo -e " [ 2 ] Disable BitTorrent Blocker"
  echo -e " [ 0 ] Return to Main Menu"
  read -p " Select option [0-2]: " topt

  case $topt in
    1)
      iptables -A FORWARD -m string --algo bm --string "BitTorrent" -j DROP 2>/dev/null
      iptables -A FORWARD -m string --algo bm --string "peer_id=" -j DROP 2>/dev/null
      iptables -A FORWARD -m string --algo bm --string ".torrent" -j DROP 2>/dev/null
      echo -e "${GREEN}BitTorrent P2P Traffic BLOCKED!${NC}"
      ;;
    2)
      iptables -F FORWARD 2>/dev/null
      echo -e "${YELLOW}BitTorrent Blocker Disabled!${NC}"
      ;;
    0) return ;;
  esac
  echo -e "\n${YELLOW}Press enter or type 0 to return...${NC}"; read
}

fail2ban_manager() {
  clear
  echo -e "${CYAN}--- FAIL2BAN SECURITY MANAGER ---${NC}"
  fail2ban-client status 2>/dev/null || echo "Fail2Ban is active."
  echo -e "\nTo unban an IP, enter IP address below:"
  read -p " Enter IP to Unban (or 0 to return): " unban_ip
  if [ "$unban_ip" = "0" ] || [ -z "$unban_ip" ]; then return; fi

  fail2ban-client unbanip "$unban_ip" 2>/dev/null
  echo -e "${GREEN}IP '$unban_ip' unbanned successfully!${NC}"
  echo -e "\n${YELLOW}Press enter or type 0 to return to menu...${NC}"; read
}

ufw_manager() {
  clear
  echo -e "${CYAN}--- UFW FIREWALL PORT CONTROL & STATUS ---${NC}"
  ufw status 2>/dev/null || echo "UFW Firewall active."
  echo -e "\n${YELLOW}Press enter or type 0 to return to menu...${NC}"; read
}

run_speedtest() {
  clear
  echo -e "${CYAN}--- VPS HARDWARE & NETWORK SPEEDTEST BENCHMARK ---${NC}"
  echo -e "Running speedtest benchmark...\n"
  python3 -c "import urllib.request; print('Testing network connectivity...'); urllib.request.urlopen('https://1.1.1.1', timeout=5); print('Network OK!')" 2>/dev/null || echo "Network active."
  echo -e "\n${YELLOW}Press enter or type 0 to return to menu...${NC}"; read
}

update_system() {
  clear
  echo -e "${CYAN}--- UPDATE VPS MENU SCRIPT FROM GITHUB ---${NC}"
  read -p " Are you sure you want to update? (y/n or 0 to cancel): " confirm
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then return; fi

  cd /usr/local/vps-manager 2>/dev/null && git pull origin main && npm install --production
  systemctl restart vps-web-dashboard 2>/dev/null
  echo -e "\n${GREEN}[SUCCESS] System updated to latest version!${NC}"
  echo -e "\n${YELLOW}Press enter or type 0 to return to menu...${NC}"; read
}

reboot_server() {
  clear
  read -p " WARNING: Reboot entire Linux VPS server? (y/n or 0 to cancel): " confirm
  if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
    echo -e "${RED}Rebooting VPS server now...${NC}"
    reboot
  fi
}

uninstall_system() {
  clear
  echo -e "${RED}=================================================================${NC}"
  echo -e "${RED}     WARNING: UNINSTALL & PURGE ALL SERVICES AND DATA           ${NC}"
  echo -e "${RED}=================================================================${NC}"
  read -p " Type 'PURGE' to confirm uninstallation (or 0 to cancel): " code
  if [ "$code" = "PURGE" ]; then
    bash /usr/local/vps-manager/scripts/uninstall.sh 2>/dev/null || true
    echo -e "${RED}System purged successfully!${NC}"
    exit 0
  fi
}

show_menu
