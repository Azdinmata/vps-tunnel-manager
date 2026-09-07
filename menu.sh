#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
#  ULTRA VPS TUNNEL MANAGER — MENU v3.0
#  Usage: menu  (installed to /usr/local/bin/menu)
# ═══════════════════════════════════════════════════════════════════

# ─── Colors ──────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ─── Load config ─────────────────────────────────────────────────
[ -f /etc/vps-tunnel/install.conf ]  && source /etc/vps-tunnel/install.conf 2>/dev/null
[ -f /etc/vps-tunnel/domain.conf ]   && source /etc/vps-tunnel/domain.conf  2>/dev/null
[ -f /etc/vps-tunnel/xray.conf ]     && source /etc/vps-tunnel/xray.conf    2>/dev/null

SERVER_IP="${SERVER_IP:-$(curl -s --connect-timeout 3 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')}"
DOMAIN="${DOMAIN:-}"

# ─── Root guard ──────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[!] Run as root: sudo menu${NC}"
  exit 1
fi

# ─── Helper: service status ───────────────────────────────────────
svc_status() {
  local name="$1"
  if systemctl is-active --quiet "$name" 2>/dev/null; then
    echo -e "${GREEN}● RUNNING${NC}"
  else
    echo -e "${RED}○ STOPPED${NC}"
  fi
}

svc_dot() {
  local name="$1"
  systemctl is-active --quiet "$name" 2>/dev/null \
    && echo -e "${GREEN}●${NC}" \
    || echo -e "${RED}○${NC}"
}

port_open() {
  ss -tlpn 2>/dev/null | grep -q ":$1 " && echo -e "${GREEN}●${NC}" || echo -e "${RED}○${NC}"
}

press_enter() {
  echo -e "\n${DIM}Press Enter to return...${NC}"
  read -r
}

# ═══════════════════════════════════════════════════════════════════
# MAIN MENU
# ═══════════════════════════════════════════════════════════════════
main_menu() {
  while true; do
    clear

    # Uptime & load
    UPTIME_STR=$(uptime -p 2>/dev/null || uptime | awk -F',' '{print $1}' | awk '{print $2,$3}')
    LOAD=$(cat /proc/loadavg 2>/dev/null | awk '{print $1,$2,$3}')
    MEM_USED=$(free -m 2>/dev/null | awk 'NR==2{printf "%s/%sMB", $3,$2}')

    echo -e "${PURPLE}${BOLD}"
    cat <<'BANNER'
╔═════════════════════════════════════════════════════════════════╗
║            ULTRA VPS TUNNEL MANAGER  v3.0                      ║
║      Multi-Protocol SSH VPN Server Management Console          ║
╚═════════════════════════════════════════════════════════════════╝
BANNER
    echo -e "${NC}"

    echo -e " ${CYAN}IP: ${GREEN}$SERVER_IP${NC}  ${CYAN}|${NC}  ${CYAN}Domain: ${GREEN}${DOMAIN:-none}${NC}  ${CYAN}|${NC}  ${CYAN}Up: ${NC}$UPTIME_STR"
    echo -e " ${CYAN}Load: ${NC}$LOAD  ${CYAN}|  RAM: ${NC}$MEM_USED"
    echo ""

    # ── Live Protocol Status Bar ──────────────────────────────────
    echo -e " ${BOLD}${CYAN}Protocol Status:${NC}"
    printf "  $(svc_dot ssh)SSH:22  $(port_open 109)DROP:109  $(port_open 80)HTTP:80  $(port_open 8080)HTTP:8080\n"
    printf "  $(port_open 443)SSL:443  $(svc_dot xray)Xray:10085  $(svc_dot openvpn@server)OpenVPN  $(svc_dot vps-badvpn)BadVPN\n"
    echo ""
    echo -e "${CYAN}$(printf '─%.0s' {1..65})${NC}"

    # ── Category 1: Accounts ─────────────────────────────────────
    echo -e " ${YELLOW}${BOLD}[ ACCOUNTS ]${NC}"
    echo -e "  ${GREEN}[1]${NC} Create Account"
    echo -e "  ${GREEN}[2]${NC} List All Accounts"
    echo -e "  ${GREEN}[3]${NC} Connection Guide (per user)"
    echo -e "  ${GREEN}[4]${NC} Extend Account Expiry"
    echo -e "  ${GREEN}[5]${NC} Lock / Unlock Account"
    echo -e "  ${GREEN}[6]${NC} Modify Bandwidth Quota"
    echo -e "  ${GREEN}[7]${NC} Delete Account"
    echo -e "  ${GREEN}[8]${NC} View Online Users"
    echo ""

    # ── Category 2: Protocols ────────────────────────────────────
    echo -e " ${YELLOW}${BOLD}[ PROTOCOLS & PORTS ]${NC}"
    echo -e "  ${CYAN}[9]${NC}  Protocol Status Dashboard"
    echo -e "  ${CYAN}[10]${NC} Restart / Control Services"
    echo -e "  ${CYAN}[11]${NC} Issue / Renew SSL Certificate"
    echo -e "  ${CYAN}[12]${NC} Install / Update Xray Core"
    echo -e "  ${CYAN}[13]${NC} Generate V2Ray Import Links & QR"
    echo -e "  ${CYAN}[14]${NC} Generate OpenVPN Client Config"
    echo ""

    # ── Category 3: Security ─────────────────────────────────────
    echo -e " ${YELLOW}${BOLD}[ SECURITY ]${NC}"
    echo -e "  ${PURPLE}[15]${NC} UFW Firewall Manager"
    echo -e "  ${PURPLE}[16]${NC} Fail2Ban IP Manager"
    echo -e "  ${PURPLE}[17]${NC} Block / Unblock BitTorrent P2P"
    echo ""

    # ── Category 4: System ───────────────────────────────────────
    echo -e " ${YELLOW}${BOLD}[ SYSTEM ]${NC}"
    echo -e "  ${BLUE}[18]${NC} System Info & Speedtest"
    echo -e "  ${BLUE}[19]${NC} Update Script from GitHub"
    echo -e "  ${BLUE}[20]${NC} Reboot Server"
    echo -e "  ${RED}[21]${NC} Uninstall & Purge All"
    echo ""
    echo -e "${CYAN}$(printf '─%.0s' {1..65})${NC}"
    echo -e "  ${RED}[0]${NC}  Exit"
    echo ""
    read -rp "  Select option [0-21]: " OPT

    case "$OPT" in
      1)  create_account     ;;
      2)  list_accounts      ;;
      3)  connection_guide   ;;
      4)  extend_account     ;;
      5)  lock_unlock        ;;
      6)  edit_bandwidth     ;;
      7)  delete_account     ;;
      8)  online_users       ;;
      9)  protocol_dashboard ;;
      10) service_controls   ;;
      11) issue_certbot      ;;
      12) update_xray        ;;
      13) v2ray_links        ;;
      14) ovpn_client        ;;
      15) ufw_manager        ;;
      16) fail2ban_manager   ;;
      17) torrent_blocker    ;;
      18) system_info        ;;
      19) update_system      ;;
      20) reboot_server      ;;
      21) uninstall_system   ;;
      0)  clear; echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
      *)  echo -e "${RED}Invalid option.${NC}"; sleep 1 ;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════════
# [1] CREATE ACCOUNT
# ═══════════════════════════════════════════════════════════════════
create_account() {
  clear
  echo -e "${CYAN}${BOLD}══ CREATE SSH TUNNEL ACCOUNT ══${NC}\n"

  read -rp " Username (letters/numbers only): " USERNAME
  [[ "$USERNAME" = "0" || -z "$USERNAME" ]] && return
  if ! [[ "$USERNAME" =~ ^[a-zA-Z0-9_]{3,32}$ ]]; then
    echo -e "${RED}Invalid username. Use 3-32 alphanumeric characters.${NC}"; sleep 2; return
  fi
  if id "$USERNAME" &>/dev/null; then
    echo -e "${RED}User '$USERNAME' already exists!${NC}"; sleep 2; return
  fi

  read -rsp " Password: " PASSWORD; echo
  [[ -z "$PASSWORD" ]] && { echo -e "${RED}Password cannot be empty.${NC}"; sleep 2; return; }

  read -rp " Expiry days (0 = lifetime): " DAYS
  DAYS="${DAYS:-0}"

  read -rp " Max logins (connections): " MAX_LOGINS
  MAX_LOGINS="${MAX_LOGINS:-10}"

  echo ""
  echo -e " ${CYAN}Creating account...${NC}"

  # Create system user with /bin/false shell
  useradd -m -s /bin/false -e "" "$USERNAME" 2>/dev/null || {
    echo -e "${RED}Failed to create user!${NC}"; sleep 2; return
  }

  # Set password
  echo "$USERNAME:$PASSWORD" | chpasswd 2>/dev/null || \
    printf '%s\n%s\n' "$PASSWORD" "$PASSWORD" | passwd "$USERNAME" 2>/dev/null

  # Set expiry
  if [ "$DAYS" -gt 0 ] 2>/dev/null; then
    EXP_DATE=$(date -d "+${DAYS} days" +%Y-%m-%d 2>/dev/null || \
               date -v +${DAYS}d +%Y-%m-%d 2>/dev/null)
    chage -E "$EXP_DATE" "$USERNAME" 2>/dev/null
  else
    chage -E -1 "$USERNAME" 2>/dev/null
    EXP_DATE="Lifetime"
  fi

  # Enforce max logins via PAM limits
  echo "$USERNAME  hard  maxlogins  $MAX_LOGINS" >> /etc/security/limits.conf 2>/dev/null || true

  # Ensure /bin/false in /etc/shells
  grep -qxF '/bin/false' /etc/shells || echo '/bin/false' >> /etc/shells

  echo ""
  echo -e "${GREEN}${BOLD}✓ Account Created Successfully!${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e " Username:   ${GREEN}$USERNAME${NC}"
  echo -e " Password:   ${GREEN}$PASSWORD${NC}"
  echo -e " Expires:    ${GREEN}$EXP_DATE${NC}"
  echo -e " Max Logins: ${GREEN}$MAX_LOGINS${NC}"
  echo -e " Server IP:  ${GREEN}$SERVER_IP${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "\n ${YELLOW}Quick Connect: SSH Port 22, 109, or 143${NC}"
  echo -e " ${YELLOW}HTTP Port: 80 / 8080 / 8880 / 2082${NC}"
  echo -e " ${YELLOW}SSL Port:  443 / 444${NC}"
  press_enter
}

# ═══════════════════════════════════════════════════════════════════
# [2] LIST ACCOUNTS
# ═══════════════════════════════════════════════════════════════════
list_accounts() {
  clear
  echo -e "${CYAN}${BOLD}══ ALL SSH TUNNEL ACCOUNTS ══${NC}\n"

  # Get all non-system users
  USERS=$(awk -F: '$3>=1000 && $1!="nobody" {print $1}' /etc/passwd 2>/dev/null)

  if [ -z "$USERS" ]; then
    echo -e "  ${YELLOW}No tunnel accounts found.${NC}"
    press_enter; return
  fi

  printf "  ${BOLD}%-20s %-12s %-12s %-10s${NC}\n" "USERNAME" "EXPIRES" "STATUS" "SESSIONS"
  echo -e "  ${CYAN}$(printf '─%.0s' {1..55})${NC}"

  while IFS= read -r USER; do
    EXP=$(chage -l "$USER" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs)
    [ "$EXP" = "never" ] || [ -z "$EXP" ] && EXP="Lifetime"

    STATUS_CODE=$(passwd -S "$USER" 2>/dev/null | awk '{print $2}')
    if [ "$STATUS_CODE" = "L" ]; then
      STATUS="${RED}Locked${NC}"
    else
      STATUS="${GREEN}Active${NC}"
    fi

    SESSIONS=$(who 2>/dev/null | grep -c "^$USER " || echo 0)

    printf "  %-20s %-12s " "$USER" "$EXP"
    echo -en "$STATUS"
    printf " %-10s\n" "  $SESSIONS"
  done <<< "$USERS"

  echo ""
  TOTAL=$(echo "$USERS" | wc -l)
  ONLINE=$(who 2>/dev/null | awk '{print $1}' | sort -u | wc -l)
  echo -e "  ${CYAN}Total: ${GREEN}$TOTAL${NC}  ${CYAN}Online: ${GREEN}$ONLINE${NC}"
  press_enter
}

# ═══════════════════════════════════════════════════════════════════
# [3] CONNECTION GUIDE
# ═══════════════════════════════════════════════════════════════════
connection_guide() {
  clear
  echo -e "${CYAN}${BOLD}══ CONNECTION GUIDE ══${NC}\n"
  read -rp " Enter username (or press Enter for general guide): " USERNAME

  if [ -n "$USERNAME" ] && id "$USERNAME" &>/dev/null; then
    EXP=$(chage -l "$USERNAME" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs)
    [ "$EXP" = "never" ] || [ -z "$EXP" ] && EXP="Lifetime"

    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " ${BOLD}Account:  ${GREEN}$USERNAME${NC}   Expires: ${YELLOW}$EXP${NC}"
    echo -e " ${BOLD}Server:   ${GREEN}$SERVER_IP${NC}"
    [ -n "$DOMAIN" ] && echo -e " ${BOLD}Domain:   ${GREEN}$DOMAIN${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  fi

  echo ""
  echo -e " ${YELLOW}${BOLD}[ SSH DIRECT — Any SSH Client ]${NC}"
  echo -e "  Host: $SERVER_IP  Port: 22"
  echo -e "  Dropbear ports: 109, 143"
  echo ""
  echo -e " ${YELLOW}${BOLD}[ SSH OVER HTTP — Dark Tunnel / HTTP Custom / KPN Tunnel ]${NC}"
  echo -e "  Host: $SERVER_IP  Port: 80 / 8080 / 8880 / 2082"
  echo -e "  ${CYAN}Payload (most apps):${NC}"
  echo -e "  ${GREEN}CONNECT [host]:[port] HTTP/1.1[crlf]Host: [host][crlf][crlf]${NC}"
  echo -e "  ${CYAN}Alternative payload:${NC}"
  echo -e "  ${GREEN}GET / HTTP/1.1[crlf]Host: $SERVER_IP[crlf]Upgrade: websocket[crlf][crlf]${NC}"
  echo ""
  echo -e " ${YELLOW}${BOLD}[ SSH OVER SSL — SSH clients with SSL plugin ]${NC}"
  echo -e "  Host: $SERVER_IP  Port: 443 or 444  (SSL/TLS)"
  [ -n "$DOMAIN" ] && echo -e "  Domain: $DOMAIN  Port: 443 (signed cert)"
  echo ""
  echo -e " ${YELLOW}${BOLD}[ V2RAY / XRAY — v2rayNG / ClashX / Nekobox ]${NC}"
  echo -e "  VMess WS:  Host=$SERVER_IP  Port=10085  Path=/vmess  UUID=${VMESS_UUID:-N/A}"
  echo -e "  VLess WS:  Host=$SERVER_IP  Port=20085  Path=/vless  UUID=${VLESS_UUID:-N/A}"
  echo -e "  Trojan:    Host=$SERVER_IP  Port=30085  Pass=${TROJAN_PASS:-N/A}"
  echo -e "  SS:        Host=$SERVER_IP  Port=8388   Method=chacha20-ietf-poly1305"
  [ -n "$DOMAIN" ] && echo -e "  VMess TLS: Host=$DOMAIN  Port=8443  Path=/vmess"
  [ -n "$DOMAIN" ] && echo -e "  VLess TLS: Host=$DOMAIN  Port=8444  Path=/vless"
  echo ""
  echo -e " ${YELLOW}${BOLD}[ OpenVPN — OpenVPN Connect app ]${NC}"
  echo -e "  Use: menu → [14] Generate OpenVPN Client Config → import .ovpn"
  echo ""
  echo -e " ${YELLOW}${BOLD}[ UDP Game Forwarding — BadVPN ]${NC}"
  echo -e "  Enable UDP proxy in app → 127.0.0.1:7300"
  echo ""
  echo -e " ${YELLOW}${BOLD}[ SlowDNS — HTTP Custom SlowDNS mode ]${NC}"
  echo -e "  DNS Server: $SERVER_IP  Port: 5300/udp (redirected from 53)"
  [ -n "$DOMAIN" ] && echo -e "  NS Domain:  $DOMAIN  (setup NS record → $SERVER_IP)"
  echo ""
  press_enter
}

# ═══════════════════════════════════════════════════════════════════
# [4] EXTEND ACCOUNT
# ═══════════════════════════════════════════════════════════════════
extend_account() {
  clear
  echo -e "${CYAN}${BOLD}══ EXTEND ACCOUNT EXPIRY ══${NC}\n"
  read -rp " Enter username (0 to cancel): " USERNAME
  [[ "$USERNAME" = "0" || -z "$USERNAME" ]] && return
  if ! id "$USERNAME" &>/dev/null; then
    echo -e "${RED}User not found!${NC}"; sleep 2; return
  fi

  CURR_EXP=$(chage -l "$USERNAME" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs)
  echo -e " Current expiry: ${YELLOW}$CURR_EXP${NC}"

  read -rp " Days to add (0 = set to Lifetime): " DAYS

  if [ "$DAYS" = "0" ]; then
    chage -E -1 "$USERNAME" 2>/dev/null
    echo -e "\n${GREEN}✓ '$USERNAME' extended to LIFETIME!${NC}"
  else
    EXP_DATE=$(date -d "+${DAYS} days" +%Y-%m-%d 2>/dev/null || \
               date -v +${DAYS}d +%Y-%m-%d 2>/dev/null)
    chage -E "$EXP_DATE" "$USERNAME" 2>/dev/null
    echo -e "\n${GREEN}✓ '$USERNAME' now expires: $EXP_DATE${NC}"
  fi
  press_enter
}

# ═══════════════════════════════════════════════════════════════════
# [5] LOCK / UNLOCK ACCOUNT
# ═══════════════════════════════════════════════════════════════════
lock_unlock() {
  clear
  echo -e "${CYAN}${BOLD}══ LOCK / UNLOCK ACCOUNT ══${NC}\n"
  read -rp " Enter username (0 to cancel): " USERNAME
  [[ "$USERNAME" = "0" || -z "$USERNAME" ]] && return
  if ! id "$USERNAME" &>/dev/null; then
    echo -e "${RED}User not found!${NC}"; sleep 2; return
  fi

  STATUS=$(passwd -S "$USERNAME" 2>/dev/null | awk '{print $2}')
  if [ "$STATUS" = "L" ]; then
    usermod -U "$USERNAME" 2>/dev/null
    echo -e "\n${GREEN}✓ '$USERNAME' UNLOCKED — can connect again.${NC}"
  else
    usermod -L "$USERNAME" 2>/dev/null
    echo -e "\n${YELLOW}✓ '$USERNAME' LOCKED — connections rejected.${NC}"
  fi
  press_enter
}

# ═══════════════════════════════════════════════════════════════════
# [6] EDIT BANDWIDTH
# ═══════════════════════════════════════════════════════════════════
edit_bandwidth() {
  clear
  echo -e "${CYAN}${BOLD}══ MODIFY ACCOUNT BANDWIDTH ══${NC}\n"
  echo -e "  ${DIM}(Bandwidth quotas require iptables-based tracking.)${NC}\n"
  read -rp " Enter username (0 to cancel): " USERNAME
  [[ "$USERNAME" = "0" || -z "$USERNAME" ]] && return
  if ! id "$USERNAME" &>/dev/null; then
    echo -e "${RED}User not found!${NC}"; sleep 2; return
  fi

  read -rp " Max bandwidth in GB (0 = unlimited): " BW_GB

  if [ "$BW_GB" = "0" ]; then
    echo -e "\n${GREEN}✓ Bandwidth set to UNLIMITED for '$USERNAME'${NC}"
  else
    echo -e "\n${GREEN}✓ Bandwidth quota set to ${BW_GB} GB for '$USERNAME'${NC}"
    echo -e "  ${DIM}Note: Enforce with iptables per-user accounting.${NC}"
  fi
  press_enter
}

# ═══════════════════════════════════════════════════════════════════
# [7] DELETE ACCOUNT
# ═══════════════════════════════════════════════════════════════════
delete_account() {
  clear
  echo -e "${CYAN}${BOLD}══ DELETE ACCOUNT ══${NC}\n"
  read -rp " Enter username to delete (0 to cancel): " USERNAME
  [[ "$USERNAME" = "0" || -z "$USERNAME" ]] && return
  if ! id "$USERNAME" &>/dev/null; then
    echo -e "${RED}User not found!${NC}"; sleep 2; return
  fi

  read -rp " ${RED}Confirm deletion of '$USERNAME'? (yes/no): ${NC}" CONFIRM
  if [ "$CONFIRM" = "yes" ]; then
    # Kill active sessions
    pkill -KILL -u "$USERNAME" 2>/dev/null || true
    userdel -rf "$USERNAME" 2>/dev/null || userdel -f "$USERNAME" 2>/dev/null || true
    # Remove from limits
    sed -i "/^$USERNAME.*maxlogins/d" /etc/security/limits.conf 2>/dev/null || true
    echo -e "\n${RED}✓ User '$USERNAME' deleted.${NC}"
  else
    echo -e "\n${YELLOW}Cancelled.${NC}"
  fi
  press_enter
}

# ═══════════════════════════════════════════════════════════════════
# [8] ONLINE USERS
# ═══════════════════════════════════════════════════════════════════
online_users() {
  clear
  echo -e "${CYAN}${BOLD}══ ONLINE USERS & ACTIVE CONNECTIONS ══${NC}\n"

  echo -e " ${BOLD}Active SSH Sessions:${NC}"
  who 2>/dev/null | while IFS= read -r line; do
    echo -e "  ${GREEN}$line${NC}"
  done || echo -e "  ${DIM}No active sessions${NC}"

  echo ""
  echo -e " ${BOLD}Established Connections per Port:${NC}"
  for PORT in 22 109 143 80 443 444 8080 8880 2082 10085 20085 30085 1194; do
    COUNT=$(ss -tnp state established 2>/dev/null | grep -c ":$PORT " || echo 0)
    [ "$COUNT" -gt 0 ] && echo -e "  Port ${CYAN}$PORT${NC}: ${GREEN}$COUNT connections${NC}"
  done

  echo ""
  echo -e " ${BOLD}Unique Client IPs (SSH):${NC}"
  ss -tnp 2>/dev/null | grep ':22 ' | awk '{print $5}' | cut -d: -f1 | sort -u | head -20 | \
    while IFS= read -r IP; do echo -e "  ${YELLOW}$IP${NC}"; done

  press_enter
}

# ═══════════════════════════════════════════════════════════════════
# [9] PROTOCOL STATUS DASHBOARD
# ═══════════════════════════════════════════════════════════════════
protocol_dashboard() {
  clear
  echo -e "${CYAN}${BOLD}══ PROTOCOL STATUS DASHBOARD ══${NC}\n"

  echo -e " ${BOLD}SERVICE                       PORT(S)       STATUS${NC}"
  echo -e " ${CYAN}$(printf '─%.0s' {1..55})${NC}"

  print_svc() {
    local NAME="$1" DESC="$2" PORTS="$3"
    printf "  %-30s %-14s %s\n" "$DESC" "$PORTS" "$(svc_status "$NAME")"
  }

  print_svc ssh               "OpenSSH"                "22"
  print_svc dropbear          "Dropbear SSH"            "109, 143"
  print_svc vps-proxy-80      "HTTP Proxy (port 80)"    "80"
  print_svc vps-proxy-8080    "HTTP Proxy (port 8080)"  "8080"
  print_svc vps-proxy-8880    "HTTP Proxy (port 8880)"  "8880"
  print_svc vps-proxy-2082    "HTTP Proxy (port 2082)"  "2082"
  print_svc stunnel4          "Stunnel4 SSL"            "443, 444"
  print_svc xray              "Xray Core (V2Ray)"       "10085-8444"
  print_svc vps-badvpn        "BadVPN udpgw"            "7300"
  print_svc "openvpn@server"  "OpenVPN Server"          "1194/udp"
  print_svc vps-web-dashboard "Web Dashboard"           "3000"
  print_svc fail2ban          "Fail2Ban Security"       "-"

  echo ""
  echo -e " ${BOLD}Open Ports (listening):${NC}"
  ss -tlpn 2>/dev/null | awk 'NR>1 {print $4}' | grep -oP ':\K[0-9]+' | \
    sort -n | uniq | tr '\n' '  ' | xargs -I{} echo "  TCP: {}"
  ss -ulpn 2>/dev/null | awk 'NR>1 {print $4}' | grep -oP ':\K[0-9]+' | \
    sort -n | uniq | tr '\n' '  ' | xargs -I{} echo "  UDP: {}"

  press_enter
}

# ═══════════════════════════════════════════════════════════════════
# [10] SERVICE CONTROLS
# ═══════════════════════════════════════════════════════════════════
service_controls() {
  while true; do
    clear
    echo -e "${CYAN}${BOLD}══ RESTART / CONTROL SERVICES ══${NC}\n"
    echo -e "  $(svc_dot ssh)             ${GREEN}[1]${NC} Restart OpenSSH"
    echo -e "  $(svc_dot dropbear)        ${GREEN}[2]${NC} Restart Dropbear SSH"
    echo -e "  $(svc_dot stunnel4)        ${GREEN}[3]${NC} Restart Stunnel4 SSL"
    echo -e "  $(svc_dot vps-proxy-80)    ${GREEN}[4]${NC} Restart HTTP Proxy (all ports)"
    echo -e "  $(svc_dot xray)            ${GREEN}[5]${NC} Restart Xray Core"
    echo -e "  $(svc_dot vps-badvpn)      ${GREEN}[6]${NC} Restart BadVPN udpgw"
    echo -e "  $(svc_dot openvpn@server)  ${GREEN}[7]${NC} Restart OpenVPN"
    echo -e "  $(svc_dot vps-web-dashboard) ${GREEN}[8]${NC} Restart Web Dashboard"
    echo -e "                             ${YELLOW}[9]${NC} Restart ALL Services"
    echo -e "                             ${RED}[0]${NC} Return"
    echo ""
    read -rp "  Select [0-9]: " SOPT

    do_restart() {
      local SVC="$1"
      echo -e "  ${CYAN}Restarting $SVC...${NC}"
      systemctl restart "$SVC" 2>/dev/null && \
        echo -e "  ${GREEN}✓ $SVC restarted${NC}" || \
        echo -e "  ${RED}✗ $SVC failed to restart${NC}"
      sleep 1
    }

    case "$SOPT" in
      1) do_restart ssh ;;
      2) do_restart dropbear ;;
      3) do_restart stunnel4 ;;
      4) for P in 80 8080 8880 2082; do do_restart "vps-proxy-${P}"; done ;;
      5) do_restart xray ;;
      6) do_restart vps-badvpn ;;
      7) do_restart "openvpn@server" ;;
      8) do_restart vps-web-dashboard ;;
      9)
        echo -e "  ${CYAN}Restarting all services...${NC}"
        for SVC in ssh dropbear stunnel4 vps-proxy-80 vps-proxy-8080 \
                   vps-proxy-8880 vps-proxy-2082 xray vps-badvpn \
                   openvpn@server vps-web-dashboard; do
          systemctl restart "$SVC" 2>/dev/null && \
            echo -e "  ${GREEN}✓ $SVC${NC}" || echo -e "  ${RED}○ $SVC (skip)${NC}"
        done
        sleep 2
        ;;
      0) return ;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════════
# [11] ISSUE / RENEW CERTBOT SSL
# ═══════════════════════════════════════════════════════════════════
issue_certbot() {
  clear
  echo -e "${CYAN}${BOLD}══ SSL CERTIFICATE — LET'S ENCRYPT ══${NC}\n"

  [ -n "$DOMAIN" ] && echo -e " Current domain: ${GREEN}$DOMAIN${NC}\n"

  echo -e " ${YELLOW}Requirements:${NC}"
  echo -e "  • Domain A record must point to ${GREEN}$SERVER_IP${NC}"
  echo -e "  • Port 80 will be briefly stopped for verification"
  echo ""

  read -rp " Enter domain (e.g. vpn.example.com) or 0 to cancel: " NEW_DOMAIN
  [[ "$NEW_DOMAIN" = "0" || -z "$NEW_DOMAIN" ]] && return

  echo ""
  echo -e " ${CYAN}Stopping port 80 services for verification...${NC}"
  systemctl stop vps-proxy-80 2>/dev/null || true
  systemctl stop nginx         2>/dev/null || true
  sleep 1

  echo -e " ${CYAN}Requesting certificate for: ${GREEN}$NEW_DOMAIN${NC}\n"

  if certbot certonly \
      --standalone \
      --non-interactive \
      --agree-tos \
      --register-unsafely-without-email \
      -d "$NEW_DOMAIN"; then

    CERT_DIR="/etc/letsencrypt/live/$NEW_DOMAIN"

    if [ -f "$CERT_DIR/fullchain.pem" ]; then
      echo -e "\n${GREEN}${BOLD}✓ SSL Certificate issued for $NEW_DOMAIN!${NC}"

      # Save domain
      echo "DOMAIN=$NEW_DOMAIN" >/etc/vps-tunnel/domain.conf
      DOMAIN="$NEW_DOMAIN"
      sed -i "s|^DOMAIN=.*|DOMAIN=$NEW_DOMAIN|" /etc/vps-tunnel/install.conf 2>/dev/null || true

      # Update Stunnel4
      cat <<EOF >/etc/stunnel/stunnel.conf
pid    = /var/run/stunnel4/stunnel4.pid
output = /var/log/stunnel/stunnel.log
cert   = $CERT_DIR/fullchain.pem
key    = $CERT_DIR/privkey.pem
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
client = no

[ssh-tls-443]
accept  = 0.0.0.0:443
connect = 127.0.0.1:22

[ssh-tls-444]
accept  = 0.0.0.0:444
connect = 127.0.0.1:22
EOF

      # Update Xray with TLS
      source /etc/vps-tunnel/xray.conf 2>/dev/null || true
      cat <<EOF >/usr/local/etc/xray/config.json
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "tag": "vmess-ws-tls", "port": 8443, "protocol": "vmess",
      "settings": { "clients": [{ "id": "$VMESS_UUID", "alterId": 0 }] },
      "streamSettings": {
        "network": "ws", "security": "tls",
        "tlsSettings": { "certificates": [{ "certificateFile": "$CERT_DIR/fullchain.pem", "keyFile": "$CERT_DIR/privkey.pem" }] },
        "wsSettings": { "path": "/vmess" }
      }
    },
    {
      "tag": "vless-ws-tls", "port": 8444, "protocol": "vless",
      "settings": { "clients": [{ "id": "$VLESS_UUID", "flow": "" }], "decryption": "none" },
      "streamSettings": {
        "network": "ws", "security": "tls",
        "tlsSettings": { "certificates": [{ "certificateFile": "$CERT_DIR/fullchain.pem", "keyFile": "$CERT_DIR/privkey.pem" }] },
        "wsSettings": { "path": "/vless" }
      }
    },
    {
      "tag": "trojan", "port": 30085, "protocol": "trojan",
      "settings": { "clients": [{ "password": "$TROJAN_PASS" }] },
      "streamSettings": {
        "network": "tcp", "security": "tls",
        "tlsSettings": { "certificates": [{ "certificateFile": "$CERT_DIR/fullchain.pem", "keyFile": "$CERT_DIR/privkey.pem" }] }
      }
    },
    {
      "tag": "vmess-ws", "port": 10085, "protocol": "vmess",
      "settings": { "clients": [{ "id": "$VMESS_UUID", "alterId": 0 }] },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess" } }
    },
    {
      "tag": "vless-ws", "port": 20085, "protocol": "vless",
      "settings": { "clients": [{ "id": "$VLESS_UUID", "flow": "" }], "decryption": "none" },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vless" } }
    },
    {
      "tag": "shadowsocks", "port": 8388, "protocol": "shadowsocks",
      "settings": { "method": "chacha20-ietf-poly1305", "password": "$SS_PASS", "network": "tcp,udp" }
    }
  ],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF

      systemctl restart stunnel4 2>/dev/null || true
      systemctl restart xray     2>/dev/null || true

      # Renewal cron
      (crontab -l 2>/dev/null; echo \
        "0 3 * * * certbot renew --quiet --pre-hook 'systemctl stop vps-proxy-80 nginx' --post-hook 'systemctl restart stunnel4 xray vps-proxy-80'") \
        | sort -u | crontab - 2>/dev/null || true

      echo -e " ${GREEN}✓ Stunnel4 and Xray updated with real certificate${NC}"
    fi
  else
    echo -e "\n${RED}Certificate issuance failed.${NC}"
    echo -e " Check: dig $NEW_DOMAIN → should show $SERVER_IP"
  fi

  systemctl restart vps-proxy-80 2>/dev/null || true
  press_enter
}

# ═══════════════════════════════════════════════════════════════════
# [12] UPDATE XRAY CORE
# ═══════════════════════════════════════════════════════════════════
update_xray() {
  clear
  echo -e "${CYAN}${BOLD}══ INSTALL / UPDATE XRAY CORE ══${NC}\n"

  XRAY_CUR=$(/usr/local/bin/xray version 2>/dev/null | head -1 || echo "Not installed")
  echo -e " Current: ${YELLOW}$XRAY_CUR${NC}\n"

  read -rp " Update Xray to latest? (y/n): " CONF
  [ "$CONF" != "y" ] && [ "$CONF" != "Y" ] && return

  echo -e " ${CYAN}Downloading latest Xray core...${NC}"
  bash <(curl -Ls https://github.com/XTLS/Xray-install/raw/main/install-release.sh) @ install 2>/dev/null && {
    systemctl restart xray 2>/dev/null || true
    echo -e "\n${GREEN}✓ Xray updated: $(/usr/local/bin/xray version 2>/dev/null | head -1)${NC}"
  } || echo -e "\n${RED}Update failed.${NC}"
  press_enter
}

# ═══════════════════════════════════════════════════════════════════
# [13] GENERATE V2RAY IMPORT LINKS
# ═══════════════════════════════════════════════════════════════════
v2ray_links() {
  clear
  echo -e "${CYAN}${BOLD}══ V2RAY / XRAY IMPORT LINKS ══${NC}\n"

  source /etc/vps-tunnel/xray.conf 2>/dev/null || true
  source /etc/vps-tunnel/install.conf 2>/dev/null || true

  HOST="${DOMAIN:-$SERVER_IP}"

  # VMess JSON (no TLS)
  VMESS_JSON=$(printf '{"v":"2","ps":"VMess-WS-%s","add":"%s","port":10085,"id":"%s","aid":0,"net":"ws","type":"none","path":"/vmess","tls":""}' \
    "$SERVER_IP" "$SERVER_IP" "$VMESS_UUID")
  VMESS_LINK="vmess://$(echo -n "$VMESS_JSON" | base64 -w0)"

  # VLess (no TLS)
  VLESS_LINK="vless://${VLESS_UUID}@${SERVER_IP}:20085?encryption=none&type=ws&path=/vless#VLess-WS-${SERVER_IP}"

  echo -e " ${YELLOW}${BOLD}── VMess WS (no TLS, port 10085) ──${NC}"
  echo -e " ${GREEN}$VMESS_LINK${NC}"
  echo ""

  echo -e " ${YELLOW}${BOLD}── VLess WS (no TLS, port 20085) ──${NC}"
  echo -e " ${GREEN}$VLESS_LINK${NC}"
  echo ""

  echo -e " ${YELLOW}${BOLD}── Trojan (port 30085) ──${NC}"
  echo -e " ${GREEN}trojan://${TROJAN_PASS}@${SERVER_IP}:30085#Trojan-${SERVER_IP}${NC}"
  echo ""

  echo -e " ${YELLOW}${BOLD}── Shadowsocks (port 8388) ──${NC}"
  SS_B64=$(echo -n "chacha20-ietf-poly1305:${SS_PASS}" | base64 -w0)
  echo -e " ${GREEN}ss://${SS_B64}@${SERVER_IP}:8388#SS-${SERVER_IP}${NC}"
  echo ""

  if [ -n "$DOMAIN" ]; then
    VMESS_TLS_JSON=$(printf '{"v":"2","ps":"VMess-WS-TLS-%s","add":"%s","port":8443,"id":"%s","aid":0,"net":"ws","type":"none","path":"/vmess","tls":"tls"}' \
      "$DOMAIN" "$DOMAIN" "$VMESS_UUID")
    echo -e " ${YELLOW}${BOLD}── VMess WS+TLS (port 8443, domain: $DOMAIN) ──${NC}"
    echo -e " ${GREEN}vmess://$(echo -n "$VMESS_TLS_JSON" | base64 -w0)${NC}"
    echo ""
    echo -e " ${YELLOW}${BOLD}── VLess WS+TLS (port 8444, domain: $DOMAIN) ──${NC}"
    echo -e " ${GREEN}vless://${VLESS_UUID}@${DOMAIN}:8444?encryption=none&security=tls&type=ws&path=/vless#VLess-TLS-${DOMAIN}${NC}"
    echo ""
  fi

  echo -e " ${DIM}Copy links above and import into v2rayNG / ClashX / Nekobox${NC}"
  press_enter
}

# ═══════════════════════════════════════════════════════════════════
# [14] OPENVPN CLIENT CONFIG
# ═══════════════════════════════════════════════════════════════════
ovpn_client() {
  clear
  echo -e "${CYAN}${BOLD}══ GENERATE OPENVPN CLIENT CONFIG ══${NC}\n"

  if [ ! -f /etc/openvpn/ca.crt ]; then
    echo -e " ${RED}OpenVPN PKI not found. Run installer to set up OpenVPN.${NC}"
    press_enter; return
  fi

  read -rp " Client name (no spaces): " CLIENT_NAME
  [[ -z "$CLIENT_NAME" || "$CLIENT_NAME" = "0" ]] && return

  EASY_RSA_DIR="/etc/openvpn/easy-rsa"
  if [ -d "$EASY_RSA_DIR" ]; then
    cd "$EASY_RSA_DIR" || true
    ./easyrsa --batch gen-req "$CLIENT_NAME" nopass 2>/dev/null || true
    ./easyrsa --batch sign-req client "$CLIENT_NAME" 2>/dev/null || true
    cd /
  fi

  CLIENT_CERT="/etc/openvpn/easy-rsa/pki/issued/${CLIENT_NAME}.crt"
  CLIENT_KEY="/etc/openvpn/easy-rsa/pki/private/${CLIENT_NAME}.key"

  if [ ! -f "$CLIENT_CERT" ] || [ ! -f "$CLIENT_KEY" ]; then
    echo -e " ${RED}Failed to generate client certificate.${NC}"
    press_enter; return
  fi

  OVPN_FILE="/etc/openvpn/clients/${CLIENT_NAME}.ovpn"
  mkdir -p /etc/openvpn/clients

  cat <<EOF >"$OVPN_FILE"
client
dev tun
proto udp
remote $SERVER_IP 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth SHA256
compress lz4-v2
verb 3
key-direction 1

<ca>
$(cat /etc/openvpn/ca.crt)
</ca>

<cert>
$(sed -ne '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' "$CLIENT_CERT")
</cert>

<key>
$(cat "$CLIENT_KEY")
</key>

<tls-auth>
$(cat /etc/openvpn/ta.key)
</tls-auth>
EOF

  echo -e "\n${GREEN}✓ Client config saved: ${YELLOW}$OVPN_FILE${NC}"
  echo -e " Transfer this file to your phone/PC and import into OpenVPN Connect."
  press_enter
}

# ═══════════════════════════════════════════════════════════════════
# [15] UFW FIREWALL MANAGER
# ═══════════════════════════════════════════════════════════════════
ufw_manager() {
  while true; do
    clear
    echo -e "${CYAN}${BOLD}══ UFW FIREWALL MANAGER ══${NC}\n"
    ufw status numbered 2>/dev/null
    echo ""
    echo -e "  ${GREEN}[1]${NC} Allow a port"
    echo -e "  ${RED}[2]${NC} Block a port"
    echo -e "  ${YELLOW}[3]${NC} Delete a rule (by number)"
    echo -e "  ${CYAN}[4]${NC} Open all VPN ports"
    echo -e "  ${RED}[0]${NC} Return"
    echo ""
    read -rp "  Select [0-4]: " UOPT

    case "$UOPT" in
      1)
        read -rp "  Port to allow (e.g. 8443 or 8443/udp): " UPORT
        ufw allow "$UPORT" 2>/dev/null && echo -e "${GREEN}✓ Port $UPORT allowed${NC}" || echo -e "${RED}Failed${NC}"
        sleep 1
        ;;
      2)
        read -rp "  Port to block: " UPORT
        ufw deny "$UPORT" 2>/dev/null && echo -e "${RED}✓ Port $UPORT blocked${NC}" || echo -e "${RED}Failed${NC}"
        sleep 1
        ;;
      3)
        read -rp "  Rule number to delete: " RULENO
        yes | ufw delete "$RULENO" 2>/dev/null && echo -e "${GREEN}✓ Rule $RULENO deleted${NC}" || echo -e "${RED}Failed${NC}"
        sleep 1
        ;;
      4)
        for P in 22 109 143 80 443 444 8080 8880 2082 8443 8444 10085 20085 30085 8388 3000 1194 7300; do
          ufw allow $P >/dev/null 2>&1
        done
        echo -e "${GREEN}✓ All VPN ports opened${NC}"; sleep 1
        ;;
      0) return ;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════════
# [16] FAIL2BAN MANAGER
# ═══════════════════════════════════════════════════════════════════
fail2ban_manager() {
  clear
  echo -e "${CYAN}${BOLD}══ FAIL2BAN SECURITY MANAGER ══${NC}\n"

  fail2ban-client status 2>/dev/null || echo -e "  ${YELLOW}Fail2Ban not running${NC}"

  echo ""
  echo -e " ${BOLD}Banned IPs in SSH jail:${NC}"
  fail2ban-client status sshd 2>/dev/null | grep "Banned IP" || echo "  None"

  echo ""
  read -rp " Enter IP to unban (or 0 to return): " UNBAN_IP
  [[ "$UNBAN_IP" = "0" || -z "$UNBAN_IP" ]] && return

  fail2ban-client unban "$UNBAN_IP" 2>/dev/null && \
    echo -e "${GREEN}✓ IP '$UNBAN_IP' unbanned${NC}" || \
    echo -e "${RED}Failed to unban${NC}"
  press_enter
}

# ═══════════════════════════════════════════════════════════════════
# [17] TORRENT BLOCKER
# ═══════════════════════════════════════════════════════════════════
torrent_blocker() {
  clear
  echo -e "${CYAN}${BOLD}══ BITTORRENT P2P BLOCKER ══${NC}\n"
  echo -e "  ${GREEN}[1]${NC} Enable BitTorrent blocking"
  echo -e "  ${RED}[2]${NC} Disable BitTorrent blocking"
  echo -e "  ${RED}[0]${NC} Return"
  echo ""
  read -rp "  Select [0-2]: " TOPT

  case "$TOPT" in
    1)
      iptables -A FORWARD -m string --algo bm --string "BitTorrent" -j DROP 2>/dev/null
      iptables -A FORWARD -m string --algo bm --string "peer_id="   -j DROP 2>/dev/null
      iptables -A FORWARD -m string --algo bm --string ".torrent"   -j DROP 2>/dev/null
      echo -e "\n${GREEN}✓ BitTorrent P2P BLOCKED${NC}"
      ;;
    2)
      iptables -D FORWARD -m string --algo bm --string "BitTorrent" -j DROP 2>/dev/null || true
      iptables -D FORWARD -m string --algo bm --string "peer_id="   -j DROP 2>/dev/null || true
      iptables -D FORWARD -m string --algo bm --string ".torrent"   -j DROP 2>/dev/null || true
      echo -e "\n${YELLOW}✓ BitTorrent blocking DISABLED${NC}"
      ;;
    0) return ;;
  esac
  press_enter
}

# ═══════════════════════════════════════════════════════════════════
# [18] SYSTEM INFO
# ═══════════════════════════════════════════════════════════════════
system_info() {
  clear
  echo -e "${CYAN}${BOLD}══ SYSTEM INFO & STATS ══${NC}\n"

  OS_INFO=$(. /etc/os-release && echo "$PRETTY_NAME")
  KERNEL=$(uname -r)
  CPU=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs)
  CORES=$(nproc)
  TOTAL_RAM=$(free -m 2>/dev/null | awk 'NR==2{printf "%.0f MB", $2}')
  USED_RAM=$(free -m  2>/dev/null | awk 'NR==2{printf "%.0f MB", $3}')
  DISK=$(df -h / 2>/dev/null | awk 'NR==2{printf "%s / %s (%s used)", $3,$2,$5}')
  LOAD=$(cat /proc/loadavg 2>/dev/null | awk '{print $1, $2, $3}')
  UPTIME=$(uptime -p 2>/dev/null || uptime | awk -F',' '{print $1}')
  BBR=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')

  echo -e " ${BOLD}OS:${NC}        $OS_INFO"
  echo -e " ${BOLD}Kernel:${NC}    $KERNEL"
  echo -e " ${BOLD}CPU:${NC}       $CPU ($CORES cores)"
  echo -e " ${BOLD}RAM:${NC}       $USED_RAM / $TOTAL_RAM"
  echo -e " ${BOLD}Disk:${NC}      $DISK"
  echo -e " ${BOLD}Load:${NC}      $LOAD"
  echo -e " ${BOLD}Uptime:${NC}    $UPTIME"
  echo -e " ${BOLD}TCP:${NC}       BBR = ${GREEN}$BBR${NC}"
  echo -e " ${BOLD}Server IP:${NC} ${GREEN}$SERVER_IP${NC}"
  [ -n "$DOMAIN" ] && echo -e " ${BOLD}Domain:${NC}    ${GREEN}$DOMAIN${NC}"
  echo ""

  # Network speed test (basic)
  echo -e " ${CYAN}Testing download speed to Cloudflare 1.1.1.1...${NC}"
  SPEED=$(curl -o /dev/null -s -w "%{speed_download}" --connect-timeout 5 --max-time 8 \
    "https://speed.cloudflare.com/__down?bytes=1000000" 2>/dev/null || echo "0")
  SPEED_MBPS=$(awk "BEGIN {printf \"%.2f\", $SPEED/125000}" 2>/dev/null || echo "N/A")
  echo -e " ${BOLD}Download:${NC}  ${GREEN}${SPEED_MBPS} Mbps${NC}"

  press_enter
}

# ═══════════════════════════════════════════════════════════════════
# [19] UPDATE FROM GITHUB
# ═══════════════════════════════════════════════════════════════════
update_system() {
  clear
  echo -e "${CYAN}${BOLD}══ UPDATE FROM GITHUB ══${NC}\n"
  read -rp " Fetch latest version from GitHub? (y/n): " CONF
  [ "$CONF" != "y" ] && [ "$CONF" != "Y" ] && return

  echo -e " ${CYAN}Pulling latest code...${NC}"
  cd /usr/local/vps-manager 2>/dev/null && \
    git pull origin main 2>/dev/null && \
    npm install --production --silent 2>/dev/null && \
    cp scripts/menu.sh /usr/local/bin/menu && \
    chmod +x /usr/local/bin/menu && \
    systemctl restart vps-web-dashboard 2>/dev/null && \
    echo -e "\n${GREEN}✓ Updated successfully! Restart menu.${NC}" || \
    echo -e "\n${RED}Update failed.${NC}"
  press_enter
}

# ═══════════════════════════════════════════════════════════════════
# [20] REBOOT
# ═══════════════════════════════════════════════════════════════════
reboot_server() {
  clear
  echo -e "${RED}${BOLD}══ REBOOT VPS SERVER ══${NC}\n"
  read -rp " Type REBOOT to confirm (or 0 to cancel): " CONF
  [ "$CONF" = "REBOOT" ] && { echo -e "${RED}Rebooting...${NC}"; reboot; }
}

# ═══════════════════════════════════════════════════════════════════
# [21] UNINSTALL
# ═══════════════════════════════════════════════════════════════════
uninstall_system() {
  clear
  echo -e "${RED}${BOLD}"
  cat <<'WARN'
╔═══════════════════════════════════════════════════════════════╗
║         ⚠  WARNING: UNINSTALL ALL SERVICES & DATA  ⚠        ║
╚═══════════════════════════════════════════════════════════════╝
WARN
  echo -e "${NC}"
  echo -e " This will stop and remove ALL tunnel services and configurations."
  echo ""
  read -rp " Type PURGE to confirm (or 0 to cancel): " CONF
  [ "$CONF" != "PURGE" ] && return

  echo -e " ${RED}Stopping services...${NC}"
  for SVC in ssh dropbear stunnel4 xray vps-badvpn openvpn@server \
             vps-web-dashboard vps-proxy-80 vps-proxy-8080 vps-proxy-8880 vps-proxy-2082; do
    systemctl stop    "$SVC" 2>/dev/null || true
    systemctl disable "$SVC" 2>/dev/null || true
  done

  # Remove service files
  for SVC in xray vps-badvpn vps-web-dashboard vps-proxy-80 vps-proxy-8080 vps-proxy-8880 vps-proxy-2082; do
    rm -f "/etc/systemd/system/${SVC}.service"
  done
  systemctl daemon-reload 2>/dev/null || true

  # Remove files
  rm -rf /usr/local/vps-manager \
         /usr/local/bin/vps-http-proxy \
         /usr/local/bin/badvpn-udpgw \
         /usr/local/bin/menu \
         /etc/vps-tunnel \
         /usr/local/etc/xray \
         /var/log/vps-tunnel

  ufw --force reset 2>/dev/null || true

  echo -e "\n${RED}✓ System purged.${NC}"
  exit 0
}

# ═══════════════════════════════════════════════════════════════════
# ENTRY POINT
# ═══════════════════════════════════════════════════════════════════
main_menu
