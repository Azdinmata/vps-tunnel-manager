# Ultra VPS Tunnel Manager v3.0

Multi-protocol SSH VPN server for **Dark Tunnel**, **HTTP Custom**, **KPN Tunnel**, **v2rayNG**, **HTTP Injector**, and **OpenVPN Connect**.

---

## 🚀 One-Line Install

```bash
curl -sSL https://raw.githubusercontent.com/Azdinmata/vps-tunnel-manager/main/scripts/install.sh | bash
```

**Requirements:**
- Ubuntu 20.04 / 22.04 / 24.04 or Debian 10 / 11 / 12
- Run as `root` (or `sudo -i` first)
- Minimum 512 MB RAM

---

## 📡 Protocol Stack

| Protocol | Port(s) | App Compatibility |
|---|---|---|
| **OpenSSH** | 22 | All SSH clients |
| **Dropbear SSH** | 109, 143 | Dark Tunnel, HTTP Custom |
| **SSH over HTTP CONNECT** | 80, 8080, 8880, 2082 | Dark Tunnel, HTTP Custom, KPN Tunnel, HTTP Injector |
| **SSH over SSL/TLS** | 443, 444 | Any SSL tunnel client |
| **VMess WebSocket** | 10085 | v2rayNG, ClashX, Nekobox |
| **VLess WebSocket** | 20085 | v2rayNG, ClashX, Nekobox |
| **VMess WS+TLS** | 8443 | v2rayNG (requires domain) |
| **VLess WS+TLS** | 8444 | v2rayNG (requires domain) |
| **Trojan** | 30085 | Trojan clients (requires domain for TLS) |
| **Shadowsocks** | 8388 | Any SS client (chacha20-ietf-poly1305) |
| **OpenVPN** | 1194/udp | OpenVPN Connect |
| **BadVPN udpgw** | 7300 (local) | In-app UDP game forwarding |
| **SlowDNS** | 5300/udp | HTTP Custom SlowDNS mode |

---

## 💻 CLI Management

After install, type `menu` in your terminal:

```bash
menu
```

**Menu Categories:**

| # | Feature |
|---|---|
| 1 | Create Account |
| 2 | List All Accounts |
| 3 | Connection Guide (per-user, per-protocol) |
| 4 | Extend Account Expiry |
| 5 | Lock / Unlock Account |
| 6 | Modify Bandwidth Quota |
| 7 | Delete Account |
| 8 | View Online Users |
| 9 | **Protocol Status Dashboard** (live status of all services) |
| 10 | Restart / Control Services (individual or all) |
| 11 | Issue / Renew SSL Certificate (Let's Encrypt) |
| 12 | Install / Update Xray Core |
| 13 | Generate V2Ray Import Links & QR Codes |
| 14 | Generate OpenVPN Client Config (.ovpn) |
| 15 | UFW Firewall Manager |
| 16 | Fail2Ban IP Manager |
| 17 | Block / Unblock BitTorrent P2P |
| 18 | System Info & Speed Test |
| 19 | Update Script from GitHub |
| 20 | Reboot Server |
| 21 | Uninstall & Purge All |

---

## 🌐 Web Dashboard

After install, access the web panel at:

```
http://YOUR_SERVER_IP:3000
```

Login: `admin` / (password shown at end of install)

---

## 📱 Dark Tunnel Setup (Recommended)

1. Run installer → create account via `menu`
2. Open Dark Tunnel → **New Config**
3. Set **Server**: `YOUR_IP` | **Port**: `80`
4. **Payload**:
   ```
   CONNECT [host]:[port] HTTP/1.1[crlf]Host: [host][crlf][crlf]
   ```
5. Enter your **username** and **password**
6. Connect

> Port 80, 8080, 8880, or 2082 all work identically.

---

## 🔐 SSL Domain Setup

During installation, enter your domain when prompted. The domain's **A record must point to your server IP**.

To add a domain later:
```bash
menu → [11] Issue / Renew SSL Certificate
```

With a domain configured, Stunnel4 (port 443) and Xray TLS (ports 8443, 8444) use a real Let's Encrypt certificate.

---

## 🔧 Credentials Location

All credentials are stored in:
```
/etc/vps-tunnel/install.conf
/etc/vps-tunnel/xray.conf
```

---

## 📄 License

MIT License — Free to use and modify.
