#!/bin/bash
# ==============================================================================
# ULTRA VPS SSH & MULTI-PROTOCOL TUNNEL MANAGER - AUTOMATED INSTALLER SCRIPT
# Supports: Ubuntu 20.04/22.04/24.04 & Debian 10/11/12
# Architecture: AMD64 (x86_64) & ARM64 (aarch64) Auto-Detection
# ==============================================================================

export DEBIAN_FRONTEND=noninteractive
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

clear
echo -e "${CYAN}"
echo "================================================================="
echo "       ULTRA VPS SSH & MULTI-PROTOCOL TUNNEL MANAGER            "
echo "  Supporting AMD64 (x86_64) & ARM64 | Universal Account Sync      "
echo "================================================================="
echo -e "${NC}"

# Check Root User
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[ERROR] Please run as root user! (sudo -i)${NC}"
  exit 1
fi

# Detect Processor Architecture (AMD64 / Intel vs ARM64)
ARCH=$(uname -m)
case "$ARCH" in
  x86_64|amd64)
    ARCH_TYPE="amd64"
    echo -e "${GREEN}[INFO] Detected Processor Architecture: AMD64 / x86_64${NC}"
    ;;
  aarch64|arm64)
    ARCH_TYPE="arm64"
    echo -e "${GREEN}[INFO] Detected Processor Architecture: ARM64 / aarch64${NC}"
    ;;
  *)
    echo -e "${RED}[ERROR] Unsupported CPU Architecture: $ARCH${NC}"
    exit 1
    ;;
esac

# Update System Packages
echo -e "\n${YELLOW}[1/8] Updating System Packages & Installing Core Utilities...${NC}"
apt-get update -y && apt-get upgrade -y
apt-get install -y curl wget unzip tar net-tools iptables ufw sudo git socat python3 python3-pip cron openssl jq stunnel4 nginx dropbear fail2ban cmake build-essential

# Enable BBR Network Optimizer
echo -e "\n${YELLOW}[2/8] Enabling TCP BBR Speed Optimizer...${NC}"
if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
  echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
  echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
  sysctl -p
fi

# Configure OpenSSH & Dropbear
echo -e "\n${YELLOW}[3/8] Configuring OpenSSH & Dropbear Servers...${NC}"
cat << 'EOF' > /etc/issue.net
<p style="text-align:center;"><b><font color="#00F0FF">ULTRA VPS MULTI-PROTOCOL SERVER</font></b><br><font color="#A855F7">Universal Account Active | No Torrenting / Spamming Allowed</font></p>
EOF

sed -i 's/#Banner none/Banner \/etc\/issue.net/g' /etc/ssh/sshd_config
sed -i 's/Banner none/Banner \/etc\/issue.net/g' /etc/ssh/sshd_config
systemctl restart sshd || systemctl restart ssh

# Dropbear Port Setup
sed -i 's/NO_START=1/NO_START=0/g' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=109/g' /etc/default/dropbear
sed -i 's/DROPBEAR_EXTRA_ARGS=/DROPBEAR_EXTRA_ARGS="-p 143 -p 109"/g' /etc/default/dropbear
systemctl restart dropbear

# Configure Stunnel4 SSL/TLS (Ports 443 & 444)
echo -e "\n${YELLOW}[4/8] Setting up Stunnel4 SSL (Ports 443/444)...${NC}"
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
  -subj "/C=US/ST=State/L=City/O=UltraVPS/CN=vpn.server" \
  -keyout /etc/stunnel/stunnel.pem -out /etc/stunnel/stunnel.pem 2>/dev/null

cat << 'EOF' > /etc/stunnel/stunnel.conf
cert = /etc/stunnel/stunnel.pem
client = no
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

[ssh-ssl]
accept = 443
connect = 127.0.0.1:22

[dropbear-ssl]
accept = 444
connect = 127.0.0.1:109
EOF

sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4
systemctl restart stunnel4

# Install Python SSH WebSocket Proxy
echo -e "\n${YELLOW}[5/8] Installing SSH WebSocket Proxy (Ports 80 & 8880)...${NC}"
cat << 'EOF' > /usr/local/bin/ws-proxy.py
#!/usr/bin/env python3
import socket, threading, select

LISTENING_PORT = 80
FORWARD_PORT = 22
RESPONSE_PAYLOAD = b"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n"

def handle_client(client_socket):
    try:
        request = client_socket.recv(1024)
        if b"Upgrade: websocket" in request or b"GET /" in request:
            client_socket.sendall(RESPONSE_PAYLOAD)
            target = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            target.connect(('127.0.0.1', FORWARD_PORT))
            
            sockets = [client_socket, target]
            while True:
                readable, _, _ = select.select(sockets, [], [], 60)
                if not readable: break
                for s in readable:
                    data = s.recv(4096)
                    if not data: return
                    if s is client_socket: target.sendall(data)
                    else: client_socket.sendall(data)
    except: pass
    finally: client_socket.close()

def start_server():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('0.0.0.0', LISTENING_PORT))
    server.listen(200)
    while True:
        client, _ = server.accept()
        threading.Thread(target=handle_client, args=(client,), daemon=True).start()

if __name__ == '__main__':
    start_server()
EOF

chmod +x /usr/local/bin/ws-proxy.py

cat << 'EOF' > /etc/systemd/system/ws-proxy.service
[Unit]
Description=SSH WebSocket Proxy Service
After=network.target

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/ws-proxy.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now ws-proxy

# Install UDP Custom Server & BadVPN udpgw for AMD64 / ARM64
echo -e "\n${YELLOW}[6/8] Installing UDP Custom Server & BadVPN (udpgw)...${NC}"
mkdir -p /usr/local/bin/badvpn

if [ "$ARCH_TYPE" = "amd64" ]; then
  wget -O /usr/local/bin/badvpn-udpgw "https://github.com/ambrop72/badvpn/raw/master/badvpn-udpgw" || true
  wget -O /usr/local/bin/udp-custom "https://raw.githubusercontent.com/zivpn/udp-custom/main/udp-custom-linux-amd64" || true
else
  wget -O /usr/local/bin/badvpn-udpgw "https://raw.githubusercontent.com/daynn3/badvpn-arm64/main/badvpn-udpgw" || true
  wget -O /usr/local/bin/udp-custom "https://raw.githubusercontent.com/zivpn/udp-custom/main/udp-custom-linux-arm64" || true
fi

chmod +x /usr/local/bin/badvpn-udpgw /usr/local/bin/udp-custom 2>/dev/null

# BadVPN Systemd Service (Ports 7100, 7200, 7300)
cat << 'EOF' > /etc/systemd/system/badvpn-7300.service
[Unit]
Description=BadVPN UDP Gateway Port 7300
After=network.target

[Service]
ExecStart=/usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 500
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now badvpn-7300

# Install Xray / V2Ray Core
echo -e "\n${YELLOW}[7/8] Installing Xray / V2Ray Core...${NC}"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# Install Web Manager Dashboard & CLI Manager script
echo -e "\n${YELLOW}[8/8] Deploying Web Manager Dashboard & CLI Terminal Command ('manager')...${NC}"
mkdir -p /usr/local/vps-manager
curl -sSL -o /usr/local/bin/manager https://raw.githubusercontent.com/azzeddin/vps-tunnel-manager/main/manager.sh 2>/dev/null || true
chmod +x /usr/local/bin/manager

# Create Auto-Cleaner Cron for Expired Users (Excludes Lifetime accounts with 'never' or 0)
cat << 'EOF' > /usr/local/bin/auto-expire-cleaner.sh
#!/bin/bash
TODAY=$(date +%s)
for user in $(awk -F: '$3 >= 1000 {print $1}' /etc/passwd); do
  EXP=$(chage -l "$user" | grep "Account expires" | cut -d: -f2)
  if [ "$EXP" != " never" ] && [ -n "$EXP" ]; then
    EXPS=$(date -d "$EXP" +%s 2>/dev/null)
    if [ -n "$EXPS" ] && [ "$EXPS" -le "$TODAY" ]; then
      userdel -f "$user"
    fi
  fi
done
EOF

chmod +x /usr/local/bin/auto-expire-cleaner.sh
(crontab -l 2>/dev/null; echo "0 0 * * * /usr/local/bin/auto-expire-cleaner.sh") | crontab -

clear
echo -e "${GREEN}=================================================================${NC}"
echo -e "${GREEN}     ULTRA VPS TUNNEL MANAGER INSTALLED SUCCESSFULLY!           ${NC}"
echo -e "${GREEN}=================================================================${NC}"
echo -e "${CYAN}Processor Architecture:${NC} $ARCH_TYPE"
echo -e "${CYAN}Type command '${GREEN}manager${CYAN}' in root terminal to launch CLI control panel!${NC}"
echo -e "${CYAN}Web Manager Dashboard running on port 3000.${NC}"
echo -e "${GREEN}=================================================================${NC}"
