# Ultra VPS SSH & Multi-Protocol Tunnel Manager

An enterprise-grade, modern VPS Tunnel Manager Web Dashboard & Bash CLI suite for managing multi-protocol SSH tunnels, UDP Custom, BadVPN udpgw, WebSocket proxies, V2Ray/Xray cores, OpenVPN, and SlowDNS.

## 🌟 Key Features

1. **AMD64 (x86_64) & ARM64 Multi-Processor Support**:
   - Auto-detects processor architecture (`uname -m`) to fetch binary packages tailored for AMD, Intel, and ARM64 VPS servers.
2. **Universal Single-Account Multi-Protocol Synchronization**:
   - Create **1 Account** (username + password) and use it across **ALL** active tunneling protocols simultaneously (SSH, Stunnel SSL, WebSocket Proxy, UDP Custom, BadVPN, V2Ray, OpenVPN, SlowDNS).
3. **Lifetime Account Duration (`0` Days)**:
   - Setting duration to `0` marks accounts as **LIFETIME** (bypasses account expiration and auto-cleaner cron tasks).
4. **Real-time Task Manager Header**:
   - Animated telemetry meters for CPU usage, RAM/Swap utilization, disk storage, and live Upload/Download bandwidth rates.
5. **Modern Cyberpunk Glassmorphism UI**:
   - Sleek dark theme with neon badges, protocol cards, modal payload editors, client QR Code generators, and instant `.ovpn` / `vmess://` / `vless://` link exporters.

---

## 📁 Directory Architecture

```
my script/
├── package.json               # Node.js dependencies & scripts
├── server.js                  # Main server entry point (Express + Socket.io)
├── README.md                  # System documentation
├── config/
│   └── default_protocols.json # Default port & protocol settings
├── src/
│   ├── routes/
│   │   ├── telemetry.routes.js # System metrics API endpoints
│   │   ├── users.routes.js     # Universal Account CRUD API
│   │   └── services.routes.js  # Service control API
│   ├── services/
│   │   ├── telemetry.service.js# Telemetry data provider
│   │   └── user.service.js     # User manager & Linux OS user sync
│   └── utils/
│       ├── arch.detector.js   # AMD64 vs ARM64 CPU detector
│       └── uuid.generator.js  # V2Ray deterministic UUID mapper
├── public/
│   ├── index.html             # Web dashboard UI
│   ├── css/
│   │   └── style.css          # Glassmorphism styling system
│   └── js/
│       └── app.js             # Dynamic client UI script
├── scripts/
│   ├── install.sh             # Standalone Linux VPS auto-installer
│   ├── menu.sh                # Interactive terminal CLI menu ('menu' command)
│   └── auto-cleaner.sh        # Expired accounts auto-deletion cron script
```

---

## 🚀 Quick Start Guide

### 1. Run Web Dashboard Locally or on Node VPS
```bash
# Install dependencies
sudo apt install npm

# Start server
npm start
```
Access the dashboard at `http://localhost:3000`.

### 2. Deploy on Linux VPS (Ubuntu / Debian)
Run the one-line installer command in root shell:
```bash
curl -sSL https://raw.githubusercontent.com/Azdinmata/vps-tunnel-manager/main/scripts/install.sh | bash
```

### 3. Terminal CLI Menu Command
To launch the interactive CLI control panel in root shell:
```bash
menu
```

---

## 🔐 Web Dashboard Admin Authentication

All dashboard API endpoints and live telemetry are protected by an admin login screen.

- **Default credentials (development):** `admin` / `admin123`
- **On the VPS:** the installer generates a random password and sets it via the `ADMIN_PASSWORD` environment variable in `/etc/systemd/system/vps-web-dashboard.service` (shown at the end of `install.sh` output).
- To change it manually: `systemctl edit vps-web-dashboard` and set `Environment=ADMIN_PASSWORD=your_strong_password`, then `systemctl restart vps-web-dashboard`.
- ALWAYS override the default password before exposing the dashboard to the internet.
