#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
#  ULTRA VPS TUNNEL MANAGER — COMPLETE INSTALLER
#  Supports: Ubuntu 20.04 / 22.04 / 24.04  |  Debian 10 / 11 / 12
#  Arch:     amd64 (x86_64)  |  arm64 (aarch64)
#
#  Protocols: OpenSSH · Dropbear · HTTP-CONNECT · Stunnel4 SSL
#             Xray (VMess/VLess/Trojan) · OpenVPN · BadVPN · SlowDNS
#
#  Usage: curl -sSL https://raw.githubusercontent.com/Azdinmata/vps-tunnel-manager/main/scripts/install.sh | bash
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# ─── Colors ──────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; }
step() { echo -e "\n${CYAN}${BOLD}══════════════════════════════════════${NC}"; \
         echo -e "${CYAN}${BOLD}  $1${NC}"; \
         echo -e "${CYAN}${BOLD}══════════════════════════════════════${NC}"; }

# ─── Banner ──────────────────────────────────────────────────────
clear
echo -e "${PURPLE}${BOLD}"
cat <<'BANNER'
╔═══════════════════════════════════════════════════════════════╗
║         ULTRA VPS TUNNEL MANAGER — INSTALLER v3.0            ║
║   SSH · SSL · WS · Xray · OpenVPN · BadVPN · SlowDNS         ║
╚═══════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"
echo -e "  ${CYAN}Multi-protocol VPN server for Dark Tunnel, HTTP Custom,${NC}"
echo -e "  ${CYAN}v2rayNG, HTTP Injector, KPN Tunnel, OpenVPN Connect${NC}"
echo ""

# ─── Root check ──────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  err "This installer must be run as root. Run: sudo -i"
  exit 1
fi

# ─── Architecture ────────────────────────────────────────────────
ARCH=$(uname -m)
case "$ARCH" in
  x86_64|amd64)   ARCH_TYPE="amd64"   ;;
  aarch64|arm64)  ARCH_TYPE="arm64"   ;;
  armv7l)         ARCH_TYPE="armv7"   ;;
  *)              err "Unsupported CPU: $ARCH"; exit 1 ;;
esac

OS_ID=$(. /etc/os-release && echo "$ID")
OS_VER=$(. /etc/os-release && echo "$VERSION_ID")
log "OS: $OS_ID $OS_VER ($ARCH_TYPE)"

# ─── Config dirs ─────────────────────────────────────────────────
mkdir -p /etc/vps-tunnel /var/log/vps-tunnel

# ─── Server IP ───────────────────────────────────────────────────
SERVER_IP=$(curl -s --connect-timeout 5 https://api.ipify.org 2>/dev/null \
  || curl -s --connect-timeout 5 https://ipv4.icanhazip.com 2>/dev/null \
  || hostname -I | awk '{print $1}')
log "Server IP: $SERVER_IP"

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}[!] IMPORTANT: After installation you MUST configure your tunnel${NC}"
echo -e "${YELLOW}    app to connect to: ${GREEN}$SERVER_IP${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
sleep 2

# ═══════════════════════════════════════════════════════════════════
# STEP 1: System Packages
# ═══════════════════════════════════════════════════════════════════
step "[1/11] Installing System Packages"

apt-get update -qq 2>/dev/null
apt-get install -y --no-install-recommends \
  curl wget git unzip tar zip gnupg lsb-release \
  iptables iptables-persistent \
  ufw \
  net-tools iproute2 \
  python3 python3-pip \
  openssl jq screen cron \
  build-essential cmake git \
  openssh-server \
  dropbear \
  stunnel4 \
  nginx \
  certbot \
  openvpn easy-rsa \
  fail2ban \
  2>/dev/null || true

# Try to install certbot nginx plugin (non-fatal)
apt-get install -y python3-certbot-nginx 2>/dev/null || true

# Stop nginx for now (we'll configure later or use as optional)
systemctl stop nginx 2>/dev/null || true

log "System packages installed"

# ═══════════════════════════════════════════════════════════════════
# STEP 2: Node.js v20 LTS
# ═══════════════════════════════════════════════════════════════════
step "[2/11] Installing Node.js v20 LTS"

NODE_OK=false
if command -v node &>/dev/null; then
  NODE_VER=$(node --version 2>/dev/null | cut -d. -f1 | tr -d 'v')
  [ "${NODE_VER:-0}" -ge 18 ] && NODE_OK=true
fi

if [ "$NODE_OK" = false ]; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash - 2>/dev/null || \
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash - 2>/dev/null || true
  apt-get install -y nodejs 2>/dev/null || true
fi

NODE_BIN=$(command -v node 2>/dev/null || echo "/usr/bin/node")
NPM_BIN=$(command -v npm 2>/dev/null || echo "/usr/bin/npm")
log "Node.js: $(node --version 2>/dev/null || echo 'installed')"

# ═══════════════════════════════════════════════════════════════════
# STEP 3: Xray Core (VMess / VLess / Trojan / Shadowsocks)
# ═══════════════════════════════════════════════════════════════════
step "[3/11] Installing Xray Core"

XRAY_BIN="/usr/local/bin/xray"

install_xray_manual() {
  local ZIP_NAME
  case "$ARCH_TYPE" in
    amd64)  ZIP_NAME="Xray-linux-64.zip"        ;;
    arm64)  ZIP_NAME="Xray-linux-arm64-v8a.zip" ;;
    armv7)  ZIP_NAME="Xray-linux-arm32-v7a.zip" ;;
  esac
  XRAY_LATEST=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest \
    | grep tag_name | cut -d'"' -f4 2>/dev/null || echo "v24.9.30")
  wget -qO /tmp/xray.zip \
    "https://github.com/XTLS/Xray-core/releases/download/${XRAY_LATEST}/${ZIP_NAME}" 2>/dev/null || return 1
  mkdir -p /tmp/xray-install
  unzip -qo /tmp/xray.zip -d /tmp/xray-install 2>/dev/null || return 1
  cp /tmp/xray-install/xray "$XRAY_BIN" 2>/dev/null || return 1
  chmod +x "$XRAY_BIN"
  rm -rf /tmp/xray-install /tmp/xray.zip
}

if [ ! -x "$XRAY_BIN" ]; then
  # Try official script
  bash <(curl -Ls https://github.com/XTLS/Xray-install/raw/main/install-release.sh) \
    @ install 2>/dev/null || install_xray_manual || warn "Xray install failed, skipping"
fi

if [ -x "$XRAY_BIN" ]; then
  log "Xray Core: $($XRAY_BIN version 2>/dev/null | head -1 || echo 'installed')"
else
  warn "Xray binary not found. V2Ray protocols disabled."
fi

# Generate Xray UUIDs / passwords
mkdir -p /usr/local/etc/xray

if [ -f /etc/vps-tunnel/xray.conf ]; then
  source /etc/vps-tunnel/xray.conf
else
  VMESS_UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || openssl rand -hex 16)
  VLESS_UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || openssl rand -hex 16)
  TROJAN_PASS=$(openssl rand -base64 16 | tr -d '/+=')
  SS_PASS=$(openssl rand -base64 16 | tr -d '/+=')
  cat <<EOF >/etc/vps-tunnel/xray.conf
VMESS_UUID=$VMESS_UUID
VLESS_UUID=$VLESS_UUID
TROJAN_PASS=$TROJAN_PASS
SS_PASS=$SS_PASS
EOF
fi

# Basic Xray config (no TLS — will be upgraded when domain is added)
cat <<EOF >/usr/local/etc/xray/config.json
{
  "log": { "loglevel": "warning", "access": "/var/log/vps-tunnel/xray-access.log", "error": "/var/log/vps-tunnel/xray-error.log" },
  "inbounds": [
    {
      "tag": "vmess-ws",
      "port": 10085,
      "protocol": "vmess",
      "settings": { "clients": [{ "id": "$VMESS_UUID", "alterId": 0 }] },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess" } }
    },
    {
      "tag": "vless-ws",
      "port": 20085,
      "protocol": "vless",
      "settings": { "clients": [{ "id": "$VLESS_UUID", "flow": "" }], "decryption": "none" },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vless" } }
    },
    {
      "tag": "trojan-tcp",
      "port": 30085,
      "protocol": "trojan",
      "settings": { "clients": [{ "password": "$TROJAN_PASS" }] },
      "streamSettings": { "network": "tcp" }
    },
    {
      "tag": "shadowsocks",
      "port": 8388,
      "protocol": "shadowsocks",
      "settings": { "method": "chacha20-ietf-poly1305", "password": "$SS_PASS", "network": "tcp,udp" }
    }
  ],
  "outbounds": [{ "protocol": "freedom", "tag": "direct" }]
}
EOF

if [ -x "$XRAY_BIN" ]; then
  cat <<'EOF' >/etc/systemd/system/xray.service
[Unit]
Description=Xray Service (V2Ray Engine)
Documentation=https://xtls.github.io
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/xray run -config /usr/local/etc/xray/config.json
Restart=always
RestartSec=3
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload 2>/dev/null
  systemctl enable xray 2>/dev/null
  systemctl restart xray 2>/dev/null || true
  log "Xray running (VMess:10085 | VLess:20085 | Trojan:30085 | SS:8388)"
fi

# ═══════════════════════════════════════════════════════════════════
# STEP 4: OpenSSH & Dropbear
# ═══════════════════════════════════════════════════════════════════
step "[4/11] Configuring OpenSSH & Dropbear"

# Register shells for PAM — required so /bin/false accounts can auth
grep -qxF '/bin/false'        /etc/shells || echo '/bin/false'        >> /etc/shells
grep -qxF '/usr/sbin/nologin' /etc/shells || echo '/usr/sbin/nologin' >> /etc/shells

# SSH banner
cat <<'BANNER' >/etc/issue.net
══════════════════════════════════════════
  ULTRA VPS TUNNEL MANAGER — Active
  Unauthorized access is prohibited.
══════════════════════════════════════════
BANNER

# Patch sshd_config (idempotent)
SSHD_CONF="/etc/ssh/sshd_config"

apply_sshd() {
  local KEY="$1" VAL="$2"
  if grep -q "^${KEY}" "$SSHD_CONF"; then
    sed -i "s|^${KEY}.*|${KEY} ${VAL}|" "$SSHD_CONF"
  elif grep -q "^#${KEY}" "$SSHD_CONF"; then
    sed -i "s|^#${KEY}.*|${KEY} ${VAL}|" "$SSHD_CONF"
  else
    echo "${KEY} ${VAL}" >> "$SSHD_CONF"
  fi
}

apply_sshd PasswordAuthentication     yes
apply_sshd AllowTcpForwarding          yes
apply_sshd GatewayPorts               yes
apply_sshd X11Forwarding              no
apply_sshd PrintMotd                  no
apply_sshd Banner                     /etc/issue.net
apply_sshd MaxStartups                "100:30:200"
apply_sshd MaxSessions                100
apply_sshd ClientAliveInterval        60
apply_sshd ClientAliveCountMax        3
apply_sshd TCPKeepAlive               yes
apply_sshd UseDNS                     no
apply_sshd Compression                yes
apply_sshd LoginGraceTime             30

# Restart SSH (Ubuntu calls it ssh, Debian/CentOS calls it sshd)
systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || service ssh restart 2>/dev/null || true
log "OpenSSH configured on port 22"

# Dropbear on ports 109 and 143
if command -v dropbear &>/dev/null || dpkg -l dropbear &>/dev/null 2>&1; then
  # Generate Dropbear host keys
  mkdir -p /etc/dropbear
  [ -f /etc/dropbear/dropbear_rsa_host_key ] || \
    dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key 2>/dev/null || true

  # Overwrite default config
  if [ -f /etc/default/dropbear ]; then
    sed -i 's/NO_START=1/NO_START=0/' /etc/default/dropbear
    sed -i 's/DROPBEAR_PORT=.*/DROPBEAR_PORT=109/' /etc/default/dropbear
    grep -q 'DROPBEAR_EXTRA_ARGS' /etc/default/dropbear && \
      sed -i 's/DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS="-p 109 -p 143"/' /etc/default/dropbear || \
      echo 'DROPBEAR_EXTRA_ARGS="-p 109 -p 143"' >> /etc/default/dropbear
  fi

  systemctl enable dropbear 2>/dev/null || true
  systemctl restart dropbear 2>/dev/null || service dropbear restart 2>/dev/null || true
  log "Dropbear SSH configured on ports 109, 143"
else
  warn "Dropbear not installed — skipping"
fi

# ═══════════════════════════════════════════════════════════════════
# STEP 5: SSH HTTP CONNECT Proxy (ports 80, 8080, 8880, 2082)
# ═══════════════════════════════════════════════════════════════════
step "[5/11] Deploying SSH HTTP CONNECT Proxy"

# This is the critical component for Dark Tunnel & HTTP Custom.
# It accepts HTTP CONNECT, WebSocket Upgrade, and raw HTTP tunneling,
# then bridges the connection directly to OpenSSH on 127.0.0.1:22

cat <<'PYEOF' >/usr/local/bin/vps-http-proxy
#!/usr/bin/env python3
"""
VPS SSH HTTP CONNECT Proxy v2.0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Supports:
  - HTTP CONNECT method (Dark Tunnel, HTTP Custom, KPN Tunnel, etc.)
  - WebSocket Upgrade (WS-mode apps)
  - Raw HTTP tunneling (HTTP Injector style)

All connections are bridged to local OpenSSH (127.0.0.1:22)
"""

import socket
import threading
import select
import sys
import os
import signal

TARGET_HOST = '127.0.0.1'
TARGET_PORT = 22
LISTEN_BACKLOG = 512
BUFFER_SIZE = 16384
SOCKET_TIMEOUT = 60  # seconds

def pipe_sockets(src, dst):
    """Bidirectional proxy between two sockets until one closes."""
    fds = [src.fileno(), dst.fileno()]
    fd_to_sock = {src.fileno(): (src, dst), dst.fileno(): (dst, src)}
    try:
        while True:
            readable, _, exceptional = select.select(fds, [], fds, SOCKET_TIMEOUT)
            if not readable or exceptional:
                break
            for fd in readable:
                reader, writer = fd_to_sock[fd]
                try:
                    data = reader.recv(BUFFER_SIZE)
                    if not data:
                        return
                    writer.sendall(data)
                except (OSError, socket.error):
                    return
    except Exception:
        pass

def handle_client(client_sock, client_addr):
    target = None
    try:
        client_sock.settimeout(15)

        # Read HTTP header block (up to \r\n\r\n)
        raw = b''
        while b'\r\n\r\n' not in raw:
            chunk = client_sock.recv(4096)
            if not chunk:
                return
            raw += chunk
            if len(raw) > 32768:
                break

        client_sock.settimeout(None)

        header_str = raw.decode('utf-8', errors='ignore')
        first_line = header_str.split('\r\n')[0]
        method = first_line.split(' ')[0].upper() if ' ' in first_line else ''

        # Connect to SSH backend
        target = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        target.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        target.connect((TARGET_HOST, TARGET_PORT))

        if method == 'CONNECT':
            # HTTP CONNECT tunnel — used by Dark Tunnel, HTTP Custom, KPN Tunnel
            client_sock.sendall(
                b'HTTP/1.1 200 Connection Established\r\n'
                b'Proxy-Agent: UltraVPS-Proxy/2.0\r\n'
                b'Connection: keep-alive\r\n'
                b'\r\n'
            )

        elif 'Upgrade: websocket' in header_str or 'upgrade: websocket' in header_str:
            # WebSocket Upgrade — used by WS-mode tunnel apps
            # Grab the Sec-WebSocket-Key if present
            ws_key = ''
            for line in header_str.split('\r\n'):
                if line.lower().startswith('sec-websocket-key:'):
                    ws_key = line.split(':', 1)[1].strip()
                    break
            client_sock.sendall(
                b'HTTP/1.1 101 Switching Protocols\r\n'
                b'Upgrade: websocket\r\n'
                b'Connection: Upgrade\r\n'
                b'\r\n'
            )

        else:
            # Any other HTTP request — treat as tunnel (HTTP Injector "payload" style)
            client_sock.sendall(
                b'HTTP/1.1 200 OK\r\n'
                b'Content-Type: application/octet-stream\r\n'
                b'Connection: keep-alive\r\n'
                b'\r\n'
            )

        # Bridge
        pipe_sockets(client_sock, target)

    except Exception:
        pass
    finally:
        for s in (client_sock, target):
            if s:
                try:
                    s.close()
                except Exception:
                    pass

def start_server(port):
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        srv.bind(('0.0.0.0', port))
    except OSError as e:
        print(f'[!] Cannot bind port {port}: {e}', flush=True)
        sys.exit(1)
    srv.listen(LISTEN_BACKLOG)
    print(f'[*] VPS HTTP Proxy :{port} → SSH {TARGET_HOST}:{TARGET_PORT}', flush=True)

    signal.signal(signal.SIGTERM, lambda s, f: sys.exit(0))

    while True:
        try:
            client, addr = srv.accept()
            client.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            t = threading.Thread(target=handle_client, args=(client, addr), daemon=True)
            t.start()
        except KeyboardInterrupt:
            break
        except Exception:
            pass

if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 80
    start_server(port)
PYEOF
chmod +x /usr/local/bin/vps-http-proxy

# Remove any old WS proxy services
for OLD_SVC in ws-proxy vps-ws-proxy vps-ws-proxy-80 vps-ws-proxy-8080 vps-ws-proxy-8880 udp-custom; do
  systemctl stop "$OLD_SVC" 2>/dev/null || true
  systemctl disable "$OLD_SVC" 2>/dev/null || true
  rm -f "/etc/systemd/system/${OLD_SVC}.service"
done

# Create a systemd service per proxy port
for PORT in 80 8080 8880 2082; do
  # Kill anything occupying the port
  fuser -k "${PORT}/tcp" 2>/dev/null || true

  cat <<EOF >/etc/systemd/system/vps-proxy-${PORT}.service
[Unit]
Description=VPS SSH HTTP CONNECT Proxy on port ${PORT}
After=network.target ssh.service
Wants=ssh.service

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/vps-http-proxy ${PORT}
Restart=always
RestartSec=5
LimitNOFILE=65536
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
done

systemctl daemon-reload 2>/dev/null
for PORT in 80 8080 8880 2082; do
  systemctl enable  vps-proxy-${PORT} 2>/dev/null || true
  systemctl restart vps-proxy-${PORT} 2>/dev/null || true
done

sleep 1
PROXY_STATUS=""
for PORT in 80 8080 8880 2082; do
  ss -tlpn 2>/dev/null | grep -q ":${PORT} " && PROXY_STATUS+=" ${PORT}" || PROXY_STATUS+=" ${RED}${PORT}(fail)${NC}"
done
log "HTTP CONNECT Proxy running on ports:${PROXY_STATUS}"

# ═══════════════════════════════════════════════════════════════════
# STEP 6: Stunnel4 SSL/TLS Wrapper (SSH over TLS)
# ═══════════════════════════════════════════════════════════════════
step "[6/11] Configuring Stunnel4 SSL"

mkdir -p /etc/stunnel /var/log/stunnel

# Self-signed cert as fallback (Let's Encrypt will override later)
if [ ! -f /etc/stunnel/stunnel-selfsigned.pem ]; then
  openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
    -subj "/C=US/ST=VPS/L=Server/O=UltraVPS/CN=vpn.server" \
    -out /etc/stunnel/stunnel-selfsigned.pem \
    -keyout /etc/stunnel/stunnel-selfsigned.key \
    2>/dev/null
  cat /etc/stunnel/stunnel-selfsigned.key \
      /etc/stunnel/stunnel-selfsigned.pem \
    > /etc/stunnel/stunnel.pem
fi

cat <<'EOF' >/etc/stunnel/stunnel.conf
; Stunnel4 — SSH over TLS/SSL
; cert will be updated to Let's Encrypt after certbot step

pid = /var/run/stunnel4/stunnel4.pid
output = /var/log/stunnel/stunnel.log

cert = /etc/stunnel/stunnel.pem
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

# Ensure service is enabled
if [ -f /etc/default/stunnel4 ]; then
  sed -i 's/^ENABLED=.*/ENABLED=1/' /etc/default/stunnel4
fi

systemctl enable stunnel4 2>/dev/null || true
systemctl restart stunnel4 2>/dev/null || service stunnel4 restart 2>/dev/null || true
log "Stunnel4 SSL configured → ports 443, 444 → SSH:22"

# ═══════════════════════════════════════════════════════════════════
# STEP 7: BadVPN UDP Gateway (port 7300)
# ═══════════════════════════════════════════════════════════════════
step "[7/11] Installing BadVPN udpgw"

BADVPN_BIN=""

# Method 1: apt
if apt-get install -y badvpn 2>/dev/null; then
  BADVPN_BIN=$(command -v badvpn-udpgw 2>/dev/null || echo "")
fi

# Method 2: pre-built binary from reliable source
if [ -z "$BADVPN_BIN" ] || [ ! -x "$BADVPN_BIN" ]; then
  case "$ARCH_TYPE" in
    amd64)
      BADVPN_URL="https://raw.githubusercontent.com/daybreakersx/premscript/master/badvpn-udpgw64"
      ;;
    arm64)
      BADVPN_URL="https://raw.githubusercontent.com/daybreakersx/premscript/master/badvpn-udpgw"
      ;;
    *)
      BADVPN_URL="https://raw.githubusercontent.com/daybreakersx/premscript/master/badvpn-udpgw"
      ;;
  esac
  wget -qO /usr/local/bin/badvpn-udpgw "$BADVPN_URL" 2>/dev/null || true
  chmod +x /usr/local/bin/badvpn-udpgw 2>/dev/null || true
  [ -x /usr/local/bin/badvpn-udpgw ] && BADVPN_BIN="/usr/local/bin/badvpn-udpgw"
fi

if [ -n "$BADVPN_BIN" ] && [ -x "$BADVPN_BIN" ]; then
  cat <<EOF >/etc/systemd/system/vps-badvpn.service
[Unit]
Description=BadVPN UDP Gateway (port 7300)
After=network.target

[Service]
Type=simple
ExecStart=$BADVPN_BIN --listen-addr 127.0.0.1:7300 --max-clients 1000 --max-connections-for-client 100
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload 2>/dev/null
  systemctl enable vps-badvpn 2>/dev/null
  systemctl restart vps-badvpn 2>/dev/null || true
  log "BadVPN udpgw listening on 127.0.0.1:7300"
else
  warn "BadVPN binary unavailable — UDP game forwarding disabled (optional)"
fi

# ═══════════════════════════════════════════════════════════════════
# STEP 8: OpenVPN Server (PKI + Client Template)
# ═══════════════════════════════════════════════════════════════════
step "[8/11] Setting Up OpenVPN Server"

# IP forwarding (required by OpenVPN)
echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null || true
grep -q "^net.ipv4.ip_forward" /etc/sysctl.conf \
  && sed -i 's|^net.ipv4.ip_forward.*|net.ipv4.ip_forward = 1|' /etc/sysctl.conf \
  || echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p 2>/dev/null || true

NET_IFACE=$(ip route show default 2>/dev/null | awk '/default/ {print $5}' | head -1)
EASY_RSA_DIR="/etc/openvpn/easy-rsa"

if command -v openvpn &>/dev/null && [ ! -d "$EASY_RSA_DIR/pki" ]; then
  # Setup Easy-RSA
  if command -v make-cadir &>/dev/null; then
    make-cadir "$EASY_RSA_DIR" 2>/dev/null || true
  elif [ -d /usr/share/easy-rsa ]; then
    cp -r /usr/share/easy-rsa "$EASY_RSA_DIR"
  fi

  if [ -d "$EASY_RSA_DIR" ]; then
    cd "$EASY_RSA_DIR" || true

    # Write vars
    cat <<'VARS' >vars
set_var EASYRSA_REQ_COUNTRY    "US"
set_var EASYRSA_REQ_PROVINCE   "State"
set_var EASYRSA_REQ_CITY       "City"
set_var EASYRSA_REQ_ORG        "UltraVPS"
set_var EASYRSA_REQ_EMAIL      "admin@vpn.server"
set_var EASYRSA_REQ_OU         "VPN"
set_var EASYRSA_CA_EXPIRE      3650
set_var EASYRSA_CERT_EXPIRE    3650
set_var EASYRSA_ALGO           rsa
set_var EASYRSA_KEY_SIZE       2048
VARS

    # Build PKI silently
    ./easyrsa --batch init-pki          2>/dev/null || true
    ./easyrsa --batch build-ca nopass   2>/dev/null || true
    ./easyrsa --batch gen-req server nopass 2>/dev/null || true
    ./easyrsa --batch sign-req server server 2>/dev/null || true
    ./easyrsa --batch gen-dh            2>/dev/null || true

    # Copy certs
    cp pki/ca.crt          /etc/openvpn/ 2>/dev/null || true
    cp pki/issued/server.crt /etc/openvpn/ 2>/dev/null || true
    cp pki/private/server.key /etc/openvpn/ 2>/dev/null || true
    cp pki/dh.pem          /etc/openvpn/ 2>/dev/null || true

    # TLS auth key
    openvpn --genkey secret /etc/openvpn/ta.key 2>/dev/null || true

    cd /
  fi

  # Server config
  cat <<EOF >/etc/openvpn/server.conf
port 1194
proto udp
dev tun

ca   /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key  /etc/openvpn/server.key
dh   /etc/openvpn/dh.pem
tls-auth /etc/openvpn/ta.key 0

server 10.8.0.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 1.1.1.1"

keepalive 10 120
cipher AES-256-GCM
auth SHA256
compress lz4-v2
push "compress lz4-v2"
max-clients 100
persist-key
persist-tun
user nobody
group nogroup
status /var/log/openvpn-status.log
log-append /var/log/openvpn.log
verb 3
explicit-exit-notify 1
EOF

  # Client .ovpn template (run menu → Generate Client Config to embed PKI)
  mkdir -p /etc/openvpn/clients
  cat <<EOF >/etc/openvpn/clients/client-template.ovpn
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
$(cat /etc/openvpn/ca.crt 2>/dev/null || echo '# CA cert here')
</ca>
<cert>
# PLACEHOLDER — replaced per client
</cert>
<key>
# PLACEHOLDER — replaced per client
</key>
<tls-auth>
$(cat /etc/openvpn/ta.key 2>/dev/null || echo '# TA key here')
</tls-auth>
EOF

  # NAT
  [ -n "$NET_IFACE" ] && \
    iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o "$NET_IFACE" -j MASQUERADE 2>/dev/null || true

  systemctl enable openvpn@server 2>/dev/null || true
  systemctl restart openvpn@server 2>/dev/null || true
  log "OpenVPN server configured on port 1194/udp"
elif [ -d "$EASY_RSA_DIR/pki" ]; then
  log "OpenVPN PKI already exists — skipping re-init"
  systemctl restart openvpn@server 2>/dev/null || true
else
  warn "OpenVPN setup skipped (openvpn not installed or already configured)"
fi

# ═══════════════════════════════════════════════════════════════════
# STEP 9: Kernel Tuning + UFW Firewall + Fail2Ban
# ═══════════════════════════════════════════════════════════════════
step "[9/11] Firewall, BBR & Security Hardening"

# TCP BBR
{
  grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf || \
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
  grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf || \
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
  sysctl -p 2>/dev/null
  log "TCP BBR congestion control enabled"
} 2>/dev/null || warn "BBR not supported on this kernel"

# SlowDNS: redirect external UDP 53 → local dnstt-server port 5300
iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300 2>/dev/null || true
iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300 2>/dev/null || true

# UFW — allow all VPN/tunnel ports
ufw --force reset 2>/dev/null
ufw default deny incoming
ufw default allow outgoing

# TCP ports
for PORT in 22 109 143 80 443 444 8080 8880 2082 \
            8443 8444 10085 20085 30085 8388 \
            3000 1080 8000; do
  ufw allow ${PORT}/tcp >/dev/null 2>&1 || true
done

# UDP ports
for PORT in 1194 7300 7100 7200 53 5300 \
            8388 10085 20085; do
  ufw allow ${PORT}/udp >/dev/null 2>&1 || true
done

ufw --force enable 2>/dev/null
log "UFW firewall enabled — all protocol ports opened"

# Fail2Ban
cat <<'EOF' >/etc/fail2ban/jail.local
[sshd]
enabled  = true
maxretry = 5
bantime  = 3600
findtime = 600
logpath  = %(sshd_log)s
EOF

systemctl enable fail2ban 2>/dev/null || true
systemctl restart fail2ban 2>/dev/null || true
log "Fail2Ban active — SSH brute-force protection enabled"

# ═══════════════════════════════════════════════════════════════════
# STEP 10: Certbot SSL Certificate (Interactive)
# ═══════════════════════════════════════════════════════════════════
step "[10/11] SSL Certificate (Let's Encrypt)"

echo ""
echo -e "  ${CYAN}A domain name with an A record pointing to ${GREEN}$SERVER_IP${CYAN} is required.${NC}"
echo -e "  ${CYAN}This enables TLS for Stunnel4 (SSH-SSL) and Xray (V2Ray TLS).${NC}"
echo -e "  ${YELLOW}Press Enter to skip and use a self-signed certificate.${NC}"
echo ""
read -rp "  Enter domain name (e.g. vpn.example.com) or press Enter to skip: " DOMAIN_NAME

DOMAIN_NAME=$(echo "${DOMAIN_NAME}" | tr -d '[:space:]')

if [ -n "$DOMAIN_NAME" ]; then
  echo -e "  ${CYAN}Stopping port 80 services temporarily for domain verification...${NC}"
  systemctl stop vps-proxy-80 2>/dev/null || true
  systemctl stop nginx 2>/dev/null || true
  sleep 1

  echo -e "  ${CYAN}Requesting certificate for: ${GREEN}$DOMAIN_NAME${NC}"
  
  if certbot certonly \
      --standalone \
      --non-interactive \
      --agree-tos \
      --register-unsafely-without-email \
      -d "$DOMAIN_NAME" 2>&1; then

    CERT_DIR="/etc/letsencrypt/live/$DOMAIN_NAME"

    if [ -f "$CERT_DIR/fullchain.pem" ]; then
      log "SSL certificate issued for $DOMAIN_NAME!"
      echo "DOMAIN=$DOMAIN_NAME" >/etc/vps-tunnel/domain.conf

      # ── Update Stunnel4 with real cert ────────────────────────
      cat <<EOF >/etc/stunnel/stunnel.conf
; Stunnel4 — SSH over TLS/SSL (Let's Encrypt: $DOMAIN_NAME)
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

      # ── Update Xray with TLS inbounds ─────────────────────────
      cat <<EOF >/usr/local/etc/xray/config.json
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/vps-tunnel/xray-access.log",
    "error":  "/var/log/vps-tunnel/xray-error.log"
  },
  "inbounds": [
    {
      "tag": "vmess-ws-tls",
      "port": 8443,
      "protocol": "vmess",
      "settings": { "clients": [{ "id": "$VMESS_UUID", "alterId": 0 }] },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "certificates": [{
            "certificateFile": "$CERT_DIR/fullchain.pem",
            "keyFile":         "$CERT_DIR/privkey.pem"
          }]
        },
        "wsSettings": { "path": "/vmess" }
      }
    },
    {
      "tag": "vless-ws-tls",
      "port": 8444,
      "protocol": "vless",
      "settings": { "clients": [{ "id": "$VLESS_UUID", "flow": "" }], "decryption": "none" },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "certificates": [{
            "certificateFile": "$CERT_DIR/fullchain.pem",
            "keyFile":         "$CERT_DIR/privkey.pem"
          }]
        },
        "wsSettings": { "path": "/vless" }
      }
    },
    {
      "tag": "trojan",
      "port": 30085,
      "protocol": "trojan",
      "settings": { "clients": [{ "password": "$TROJAN_PASS" }] },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "certificates": [{
            "certificateFile": "$CERT_DIR/fullchain.pem",
            "keyFile":         "$CERT_DIR/privkey.pem"
          }]
        }
      }
    },
    {
      "tag": "vmess-ws",
      "port": 10085,
      "protocol": "vmess",
      "settings": { "clients": [{ "id": "$VMESS_UUID", "alterId": 0 }] },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess" } }
    },
    {
      "tag": "vless-ws",
      "port": 20085,
      "protocol": "vless",
      "settings": { "clients": [{ "id": "$VLESS_UUID", "flow": "" }], "decryption": "none" },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vless" } }
    },
    {
      "tag": "shadowsocks",
      "port": 8388,
      "protocol": "shadowsocks",
      "settings": { "method": "chacha20-ietf-poly1305", "password": "$SS_PASS", "network": "tcp,udp" }
    }
  ],
  "outbounds": [{ "protocol": "freedom", "tag": "direct" }]
}
EOF

      systemctl restart stunnel4 2>/dev/null || true
      systemctl restart xray    2>/dev/null || true

      # Auto-renewal cron
      (crontab -l 2>/dev/null; echo \
        "0 3 * * * certbot renew --quiet --pre-hook 'systemctl stop vps-proxy-80 nginx' --post-hook 'systemctl restart stunnel4 xray vps-proxy-80'") \
        | sort -u | crontab - 2>/dev/null || true

      log "Certbot auto-renewal configured"
    fi
  else
    warn "Certificate issuance failed — ensure DNS A record for $DOMAIN_NAME points to $SERVER_IP"
    warn "Using self-signed certificate. You can re-run: menu → option 12"
    DOMAIN_NAME=""
  fi

  # Restart HTTP proxy on port 80
  systemctl restart vps-proxy-80 2>/dev/null || true
else
  echo -e "  ${YELLOW}Skipped — using self-signed certificate.${NC}"
  DOMAIN_NAME=""
fi

# Save all config
cat <<EOF >/etc/vps-tunnel/install.conf
SERVER_IP=$SERVER_IP
DOMAIN=${DOMAIN_NAME:-}
ARCH=$ARCH_TYPE
INSTALL_DATE=$(date '+%Y-%m-%d %H:%M:%S')
VMESS_UUID=$VMESS_UUID
VLESS_UUID=$VLESS_UUID
TROJAN_PASS=$TROJAN_PASS
SS_PASS=${SS_PASS:-}
EOF

# ═══════════════════════════════════════════════════════════════════
# STEP 11: Web Dashboard + menu CLI
# ═══════════════════════════════════════════════════════════════════
step "[11/11] Deploying Web Dashboard"

INSTALL_DIR="/usr/local/vps-manager"
rm -rf "$INSTALL_DIR"

# Clone repository
if git clone https://github.com/Azdinmata/vps-tunnel-manager.git "$INSTALL_DIR" 2>/dev/null; then
  cd "$INSTALL_DIR"
  $NPM_BIN install --production --silent 2>/dev/null || \
    npm install --production 2>/dev/null || true
  cd /
else
  warn "Git clone failed — creating minimal directory"
  mkdir -p "$INSTALL_DIR"
fi

# Set random admin password
ADMIN_PASS=$(openssl rand -base64 12 | tr -d '/+=')
[ -f /etc/vps-tunnel/install.conf ] && \
  grep -q "^ADMIN_PASS" /etc/vps-tunnel/install.conf || \
  echo "ADMIN_PASS=$ADMIN_PASS" >> /etc/vps-tunnel/install.conf

# Web dashboard systemd service
if [ -f "$INSTALL_DIR/server.js" ]; then
  cat <<EOF >/etc/systemd/system/vps-web-dashboard.service
[Unit]
Description=Ultra VPS Tunnel Manager Web Dashboard
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$NODE_BIN $INSTALL_DIR/server.js
Restart=always
RestartSec=5
Environment=NODE_ENV=production
Environment=PORT=3000
Environment=SERVER_IP=$SERVER_IP
Environment=ADMIN_USER=admin
Environment=ADMIN_PASSWORD=$ADMIN_PASS

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload 2>/dev/null
  systemctl enable vps-web-dashboard 2>/dev/null
  systemctl restart vps-web-dashboard 2>/dev/null || true
  log "Web Dashboard started on port 3000"
fi

# Install menu CLI
if [ -f "$INSTALL_DIR/scripts/menu.sh" ]; then
  cp "$INSTALL_DIR/scripts/menu.sh" /usr/local/bin/menu
  chmod +x /usr/local/bin/menu
  log "'menu' command installed"
fi

# Cleanup old manager command
rm -f /usr/local/bin/manager 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ═══════════════════════════════════════════════════════════════════
clear
echo -e "${PURPLE}${BOLD}"
cat <<'DONE'
╔═══════════════════════════════════════════════════════════════╗
║       ULTRA VPS TUNNEL MANAGER — INSTALLATION COMPLETE!      ║
╚═══════════════════════════════════════════════════════════════╝
DONE
echo -e "${NC}"

source /etc/vps-tunnel/install.conf 2>/dev/null || true

echo -e " ${BOLD}📡 Server IP:${NC}         ${GREEN}$SERVER_IP${NC}"
[ -n "${DOMAIN:-}" ] && echo -e " ${BOLD}🌐 Domain (SSL):${NC}      ${GREEN}$DOMAIN${NC}"
echo ""
echo -e " ${BOLD}${CYAN}Protocol Stack${NC} — All active:"
echo -e " ${GREEN}  SSH Direct        →${NC} ${SERVER_IP}:22 / 109 / 143"
echo -e " ${GREEN}  SSH over HTTP     →${NC} ${SERVER_IP}:80 / 8080 / 8880 / 2082  [HTTP CONNECT]"
echo -e " ${GREEN}  SSH over SSL/TLS  →${NC} ${SERVER_IP}:443 / 444               [Stunnel4]"
echo -e " ${GREEN}  VMess WS          →${NC} ${SERVER_IP}:10085  path /vmess"
echo -e " ${GREEN}  VLess WS          →${NC} ${SERVER_IP}:20085  path /vless"
echo -e " ${GREEN}  Trojan            →${NC} ${SERVER_IP}:30085"
echo -e " ${GREEN}  Shadowsocks       →${NC} ${SERVER_IP}:8388   chacha20-ietf-poly1305"
[ -n "${DOMAIN:-}" ] && \
echo -e " ${GREEN}  VMess WS+TLS      →${NC} ${DOMAIN}:8443  path /vmess" && \
echo -e " ${GREEN}  VLess WS+TLS      →${NC} ${DOMAIN}:8444  path /vless" && \
echo -e " ${GREEN}  Trojan+TLS        →${NC} ${DOMAIN}:30085"
echo -e " ${GREEN}  OpenVPN           →${NC} ${SERVER_IP}:1194/udp"
echo -e " ${GREEN}  BadVPN udpgw      →${NC} 127.0.0.1:7300  (in-app: enable UDPGW)"
echo ""
echo -e " ${BOLD}🔐 Xray Credentials:${NC}"
echo -e "    VMess UUID:   ${YELLOW}${VMESS_UUID}${NC}"
echo -e "    VLess UUID:   ${YELLOW}${VLESS_UUID}${NC}"
echo -e "    Trojan Pass:  ${YELLOW}${TROJAN_PASS}${NC}"
echo -e "    SS Pass:      ${YELLOW}${SS_PASS:-N/A}${NC}"
echo ""
echo -e " ${BOLD}🌐 Web Dashboard:${NC}     ${YELLOW}http://${SERVER_IP}:3000${NC}"
echo -e " ${BOLD}🔑 Admin:${NC}             admin / ${YELLOW}${ADMIN_PASS:-check /etc/vps-tunnel/install.conf}${NC}"
echo ""
echo -e " ${BOLD}💻 CLI Management:${NC}    Type ${GREEN}menu${NC} in your terminal"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " ${BOLD}Quick Start:${NC}"
echo -e "   1. Run ${GREEN}menu${NC} → Create Account"
echo -e "   2. Open Dark Tunnel / HTTP Custom"
echo -e "   3. Set server: ${GREEN}$SERVER_IP${NC}, port: ${GREEN}80${NC}"
echo -e "   4. Set payload:  ${YELLOW}CONNECT [host]:22 HTTP/1.1[crlf][crlf]${NC}"
echo -e "   5. Enter your username and password"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
