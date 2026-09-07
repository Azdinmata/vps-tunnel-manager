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

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[ERROR] Please run as root user! (sudo -i)${NC}"
  exit 1
fi

# Detect Processor Architecture
ARCH=$(uname -m)
case "$ARCH" in
  x86_64|amd64) ARCH_TYPE="amd64" ;;
  aarch64|arm64) ARCH_TYPE="arm64" ;;
  *) echo -e "${RED}[ERROR] Unsupported CPU Architecture: $ARCH${NC}"; exit 1 ;;
esac

echo -e "${GREEN}[INFO] Detected Processor Architecture: $ARCH_TYPE${NC}"

# Install Core Tools, Node.js 20 LTS & NPM automatically
echo -e "\n${YELLOW}[1/8] Installing Core Packages, Node.js & NPM...${NC}"
apt-get update -y
apt-get install -y curl wget unzip tar net-tools iptables ufw sudo git socat python3 python3-pip cron openssl jq stunnel4 nginx dropbear fail2ban nodejs npm build-essential 2>/dev/null || true

# Try NodeSource v20 setup if node is missing or older
if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
  echo -e "${YELLOW}Installing NodeSource v20 LTS package...${NC}"
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash - 2>/dev/null || true
  apt-get install -y nodejs npm build-essential 2>/dev/null || true
fi

NODE_BIN=$(command -v node || echo "/usr/bin/node")
NPM_BIN=$(command -v npm || echo "/usr/bin/npm")
echo -e "${GREEN}[INFO] Detected Node.js binary at: $NODE_BIN${NC}"

# Enable TCP BBR Speed Optimizer
echo -e "\n${YELLOW}[2/8] Enabling TCP BBR Speed Optimizer...${NC}"
if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
  echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
  echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
  sysctl -p 2>/dev/null || true
fi

# Ensure PAM Shells compatibility for Tunnel Accounts
echo -e "\n${YELLOW}[2.5/8] Configuring PAM Shells & SSH Tunnel Settings...${NC}"
grep -qxF '/bin/false' /etc/shells 2>/dev/null || echo '/bin/false' >> /etc/shells
grep -qxF '/usr/sbin/nologin' /etc/shells 2>/dev/null || echo '/usr/sbin/nologin' >> /etc/shells

# Configure OpenSSH Banner & Tunnel Parameters
echo -e "\n${YELLOW}[3/8] Configuring OpenSSH & Dropbear...${NC}"
cat << 'EOF' > /etc/issue.net
<p style="text-align:center;"><b><font color="#00F0FF">ULTRA VPS MULTI-PROTOCOL SERVER</font></b><br><font color="#A855F7">Universal Account Active | No Torrenting / Spamming Allowed</font></p>
EOF

sed -i 's/#Banner none/Banner \/etc\/issue.net/g' /etc/ssh/sshd_config 2>/dev/null || true
sed -i 's/#AllowTcpForwarding yes/AllowTcpForwarding yes/g' /etc/ssh/sshd_config 2>/dev/null || true
sed -i 's/#GatewayPorts no/GatewayPorts yes/g' /etc/ssh/sshd_config 2>/dev/null || true
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config 2>/dev/null || true
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config 2>/dev/null || true
grep -q "AllowTcpForwarding" /etc/ssh/sshd_config || echo "AllowTcpForwarding yes" >> /etc/ssh/sshd_config
grep -q "MaxStartups" /etc/ssh/sshd_config || echo "MaxStartups 100:30:200" >> /etc/ssh/sshd_config

systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true

# Dropbear Setup
cat << 'EOF' > /etc/default/dropbear
NO_START=0
DROPBEAR_PORT=109
DROPBEAR_EXTRA_ARGS="-p 143 -p 109"
DROPBEAR_BANNER="/etc/issue.net"
EOF
systemctl restart dropbear 2>/dev/null || service dropbear restart 2>/dev/null || true

# Deploy WebSocket HTTP Proxy Daemon for Dark Tunnel / HTTP Injector
echo -e "\n${YELLOW}[3.5/8] Deploying SSH WebSocket HTTP Proxy (Ports 80 & 8080)...${NC}"
cat << 'EOF' > /usr/local/bin/vps-ws-proxy
#!/usr/bin/env python3
import socket, threading, select, sys

class ProxyServer:
    def __init__(self, port, target_host='127.0.0.1', target_port=22):
        self.port = port
        self.target_host = target_host
        self.target_port = target_port

    def start(self):
        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind(('0.0.0.0', self.port))
        server.listen(100)
        while True:
            try:
                client_sock, _ = server.accept()
                threading.Thread(target=self.handle_client, args=(client_sock,)).start()
            except Exception:
                pass

    def handle_client(self, client_sock):
        try:
            client_sock.settimeout(10)
            req = client_sock.recv(4096).decode('utf-8', errors='ignore')
            client_sock.settimeout(None)
            if "Upgrade" in req or "GET" in req or "POST" in req or "HTTP" in req:
                client_sock.sendall(b"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n")
            
            target_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            target_sock.connect((self.target_host, self.target_port))
            
            sockets = [client_sock, target_sock]
            while True:
                readable, _, _ = select.select(sockets, [], [], 60)
                if not readable: break
                for s in readable:
                    data = s.recv(8192)
                    if not data: return
                    if s is client_sock: target_sock.sendall(data)
                    else: client_sock.sendall(data)
        except Exception:
            pass
        finally:
            try: client_sock.close()
            except: pass

if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 80
    ProxyServer(port).start()
EOF
chmod +x /usr/local/bin/vps-ws-proxy

cat << EOF > /etc/systemd/system/vps-ws-proxy-80.service
[Unit]
Description=VPS WebSocket HTTP Proxy Port 80
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/vps-ws-proxy 80
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

cat << EOF > /etc/systemd/system/vps-ws-proxy-8880.service
[Unit]
Description=VPS WebSocket HTTP Proxy Port 8880
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/vps-ws-proxy 8880
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

cat << EOF > /etc/systemd/system/vps-ws-proxy-2082.service
[Unit]
Description=VPS WebSocket HTTP Proxy Port 2082
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/vps-ws-proxy 2082
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload 2>/dev/null || true
systemctl enable --now vps-ws-proxy-80 2>/dev/null || true
systemctl enable --now vps-ws-proxy-8080 2>/dev/null || true
systemctl enable --now vps-ws-proxy-8880 2>/dev/null || true
systemctl enable --now vps-ws-proxy-2082 2>/dev/null || true
systemctl restart vps-ws-proxy-80 2>/dev/null || true
systemctl restart vps-ws-proxy-8080 2>/dev/null || true
systemctl restart vps-ws-proxy-8880 2>/dev/null || true
systemctl restart vps-ws-proxy-2082 2>/dev/null || true

# Deploy SlowDNS iptables port redirect (UDP 53 -> 5300)
echo -e "\n${YELLOW}[3.55/8] Configuring SlowDNS IPTables Redirect (UDP 53 -> 5300)...${NC}"
iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300 2>/dev/null || true

# Deploy BadVPN udpgw Daemon (Port 7300 for UDP Forwarding in SSH Tunnels)
echo -e "\n${YELLOW}[3.6/8] Deploying BadVPN udpgw Daemon (UDP Port 7300)...${NC}"
wget -q -O /usr/local/bin/badvpn-udpgw "https://github.com/ambrop72/badvpn/raw/master/udpgw/badvpn-udpgw" 2>/dev/null || true
chmod +x /usr/local/bin/badvpn-udpgw 2>/dev/null || true

cat << EOF > /etc/systemd/system/vps-badvpn-7300.service
[Unit]
Description=BadVPN UDP Gateway Port 7300
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 500
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload 2>/dev/null || true
systemctl enable --now vps-badvpn-7300 2>/dev/null || true
systemctl restart vps-badvpn-7300 2>/dev/null || true

# Deploy UDP Custom Server Config
echo -e "\n${YELLOW}[3.7/8] Configuring UDP Custom Gateway...${NC}"
mkdir -p /root/udp 2>/dev/null
cat << 'EOF' > /root/udp/config.json
{
  "listen": ":7300",
  "stream_buffer": 16777216,
  "receive_buffer": 16777216,
  "auth": {
    "mode": "passwords"
  }
}
EOF

# Stunnel4 Setup
echo -e "\n${YELLOW}[4/8] Configuring SSL Stunnel4...${NC}"
mkdir -p /etc/stunnel /var/log/stunnel
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
  -subj "/C=US/ST=State/L=City/O=UltraVPS/CN=vpn.server" \
  -keyout /etc/stunnel/stunnel.pem -out /etc/stunnel/stunnel.pem 2>/dev/null

cat << 'EOF' > /etc/stunnel/stunnel.conf
cert = /etc/stunnel/stunnel.pem
client = no
socket = a:SO_REUSEADDR=1

[ssh-ssl]
accept = 443
connect = 127.0.0.1:22
EOF

if [ -f /etc/default/stunnel4 ]; then
  sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4 2>/dev/null || true
fi

systemctl enable stunnel4 2>/dev/null || systemctl enable stunnel 2>/dev/null || true
systemctl restart stunnel4 2>/dev/null || systemctl restart stunnel 2>/dev/null || service stunnel4 restart 2>/dev/null || true


# Deploy Web Dashboard Project to /usr/local/vps-manager & Run npm install automatically
echo -e "\n${YELLOW}[5/8] Deploying Web Dashboard & Automatically Installing Dependencies...${NC}"
rm -rf /usr/local/vps-manager
git clone https://github.com/Azdinmata/vps-tunnel-manager.git /usr/local/vps-manager
cd /usr/local/vps-manager
$NPM_BIN install --production 2>/dev/null || npm install --production 2>/dev/null || npm install 2>/dev/null || true

# Create Systemd Background Daemon (Runs Web Dashboard 24/7 on Port 3000 automatically)
ADMIN_PASS=$(openssl rand -base64 18 | tr -d '/+=' | head -c 20)
cat << EOF > /etc/systemd/system/vps-web-dashboard.service
[Unit]
Description=Ultra VPS Tunnel Manager Web Dashboard
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/usr/local/vps-manager
ExecStart=$NODE_BIN /usr/local/vps-manager/server.js
Restart=always
RestartSec=5
Environment=NODE_ENV=production
Environment=PORT=3000
Environment=ADMIN_USER=admin
Environment=ADMIN_PASSWORD=$ADMIN_PASS

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload 2>/dev/null || true
systemctl enable vps-web-dashboard 2>/dev/null || true
systemctl restart vps-web-dashboard 2>/dev/null || true

# Fallback direct background execution if systemd service is inactive
sleep 2
if ! netstat -tlpn 2>/dev/null | grep -q ":3000" && ! ss -tlpn 2>/dev/null | grep -q ":3000"; then
  echo -e "${YELLOW}[INFO] Starting Web Dashboard via Nohup Daemon Fallback...${NC}"
  pkill -f "node server.js" 2>/dev/null || true
  nohup $NODE_BIN /usr/local/vps-manager/server.js > /var/log/vps-dashboard.log 2>&1 &
fi

# Install CLI Menu command ('menu')
cp /usr/local/vps-manager/scripts/menu.sh /usr/local/bin/menu
chmod +x /usr/local/bin/menu
rm -f /usr/local/bin/manager 2>/dev/null || true

# Configure UFW Firewall (Enabled by Default with All Protocol Ports Opened)
echo -e "\n${YELLOW}[6/8] Configuring UFW Firewall by Default & Opening Protocol Ports...${NC}"
ufw --force enable
ufw default allow outgoing
ufw allow 22/tcp 2>/dev/null
ufw allow 3000/tcp 2>/dev/null
ufw allow 80/tcp 2>/dev/null
ufw allow 443/tcp 2>/dev/null
ufw allow 8080/tcp 2>/dev/null
ufw allow 8880/tcp 2>/dev/null
ufw allow 8443/tcp 2>/dev/null
ufw allow 2082/tcp 2>/dev/null
ufw allow 109/tcp 2>/dev/null
ufw allow 143/tcp 2>/dev/null
ufw allow 444/tcp 2>/dev/null
ufw allow 7300/udp 2>/dev/null
ufw allow 7100/udp 2>/dev/null
ufw allow 7200/udp 2>/dev/null
ufw allow 53/udp 2>/dev/null
ufw allow 10085/tcp 2>/dev/null
ufw allow 10085/udp 2>/dev/null
ufw allow 20085/tcp 2>/dev/null
ufw allow 20085/udp 2>/dev/null
ufw allow 30085/tcp 2>/dev/null
ufw allow 30085/udp 2>/dev/null
ufw allow 40085/tcp 2>/dev/null
ufw allow 40085/udp 2>/dev/null
ufw allow 8388/tcp 2>/dev/null
ufw allow 8388/udp 2>/dev/null
ufw allow 1194/tcp 2>/dev/null
ufw allow 1194/udp 2>/dev/null

# Interactive Certbot SSL Certificate Setup
echo -e "\n${YELLOW}[7/8] Certbot SSL Certificate Setup...${NC}"
read -p "Enter your Domain Name for SSL Certificate (or press Enter to skip): " DOMAIN_NAME

if [ -n "$DOMAIN_NAME" ]; then
  echo -e "${CYAN}Issuing Let's Encrypt SSL Certificate for $DOMAIN_NAME...${NC}"
  systemctl stop nginx 2>/dev/null
  certbot certonly --standalone --non-interactive --agree-tos -m "admin@$DOMAIN_NAME" -d "$DOMAIN_NAME" --register-unsafely-without-email 2>/dev/null
  if [ -f "/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem" ]; then
    echo -e "${GREEN}SSL Certificate successfully issued for $DOMAIN_NAME!${NC}"
    cat << EOF > /etc/stunnel/stunnel.conf
cert = /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem
key = /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem
client = no
socket = a:SO_REUSEADDR=1

[ssh-ssl]
accept = 443
connect = 127.0.0.1:22
EOF
    systemctl restart stunnel4 2>/dev/null
  else
    echo -e "${RED}Certbot issue attempt completed. Check DNS pointing if certificate wasn't saved.${NC}"
  fi
else
  echo -e "${CYAN}Skipping SSL Domain Setup. Default self-signed certificate active.${NC}"
fi

SERVER_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')

clear
echo -e "${GREEN}=================================================================${NC}"
echo -e "${GREEN}   ULTRA VPS TUNNEL MENU INSTALLED & LAUNCHED!                  ${NC}"
echo -e "${GREEN}=================================================================${NC}"
echo -e "${CYAN}Processor Architecture:${NC} $ARCH_TYPE"
echo -e "${CYAN}🛡️ UFW Firewall Status:${NC} ${GREEN}ENABLED${NC} (All Protocol Ports Opened)"
if [ -n "$DOMAIN_NAME" ]; then
  echo -e "${CYAN}🔒 SSL Certificate Domain:${NC} $DOMAIN_NAME"
fi
echo -e "${CYAN}🌐 Web Dashboard Live URL (Accessible on ANY Device):${NC}"
echo -e "   ${YELLOW}http://${SERVER_IP}:3000${NC}"
echo -e "\n${CYAN}💻 Terminal CLI Menu Command:${NC}"
echo -e "   Type '${GREEN}menu${CYAN}' in root shell anytime."
echo -e "\n${CYAN}🔐 Web Dashboard Admin Login:${NC}"
echo -e "   Username: ${YELLOW}admin${NC}"
echo -e "   Password: ${YELLOW}${ADMIN_PASS}${NC} (stored in /etc/systemd/system/vps-web-dashboard.service)"
echo -e "${GREEN}=================================================================${NC}"

