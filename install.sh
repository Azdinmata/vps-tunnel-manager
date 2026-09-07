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
echo -e "\n${YELLOW}[1/8] Installing Core Packages, Node.js v20 LTS & NPM...${NC}"
apt-get update -y
apt-get install -y curl wget unzip tar net-tools iptables ufw sudo git socat python3 python3-pip cron openssl jq stunnel4 nginx dropbear fail2ban

# Clean install Node.js 20 LTS and NPM from official NodeSource repository
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs build-essential

# Enable TCP BBR Speed Optimizer
echo -e "\n${YELLOW}[2/8] Enabling TCP BBR Speed Optimizer...${NC}"
if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
  echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
  echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
  sysctl -p
fi

# Configure OpenSSH Banner & Dropbear
echo -e "\n${YELLOW}[3/8] Configuring OpenSSH & Dropbear...${NC}"
cat << 'EOF' > /etc/issue.net
<p style="text-align:center;"><b><font color="#00F0FF">ULTRA VPS MULTI-PROTOCOL SERVER</font></b><br><font color="#A855F7">Universal Account Active | No Torrenting / Spamming Allowed</font></p>
EOF

sed -i 's/#Banner none/Banner \/etc\/issue.net/g' /etc/ssh/sshd_config
systemctl restart sshd || systemctl restart ssh

# Stunnel4 Setup
echo -e "\n${YELLOW}[4/8] Configuring SSL Stunnel4...${NC}"
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

sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4
systemctl restart stunnel4

# Deploy Web Dashboard Project to /usr/local/vps-manager & Run npm install automatically
echo -e "\n${YELLOW}[5/8] Deploying Web Dashboard & Automatically Installing Dependencies...${NC}"
rm -rf /usr/local/vps-manager
git clone https://github.com/Azdinmata/vps-tunnel-manager.git /usr/local/vps-manager
cd /usr/local/vps-manager
npm install --production

# Create Systemd Background Daemon (Runs Web Dashboard 24/7 on Port 3000 automatically)
cat << 'EOF' > /etc/systemd/system/vps-web-dashboard.service
[Unit]
Description=Ultra VPS Tunnel Manager Web Dashboard
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/usr/local/vps-manager
ExecStart=/usr/bin/node /usr/local/vps-manager/server.js
Restart=always
RestartSec=5
Environment=NODE_ENV=production
Environment=PORT=3000

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now vps-web-dashboard

# Install CLI Menu command ('menu' and 'manager' compatibility link)
cp /usr/local/vps-manager/scripts/menu.sh /usr/local/bin/menu
chmod +x /usr/local/bin/menu
ln -sf /usr/local/bin/menu /usr/local/bin/manager

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
echo -e "   Type '${GREEN}menu${CYAN}' (or 'manager') in root shell anytime."
echo -e "${GREEN}=================================================================${NC}"

