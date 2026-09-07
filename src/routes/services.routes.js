const express = require('express');
const router = express.Router();
const os = require('os');
const { execSync, exec } = require('child_process');
const path = require('path');

// Restart/Start/Stop Service Endpoint
router.post('/action', (req, res) => {
  const { service, action } = req.body;
  console.log(`Executing ${action} on service ${service}`);

  const serviceMap = {
    ssh: 'ssh',
    dropbear: 'dropbear',
    stunnel: 'stunnel4',
    wsProxy: 'ws-proxy',
    udpCustom: 'udp-custom',
    badvpn: 'badvpn-7300',
    v2ray: 'xray',
    openvpn: 'openvpn',
    nginx: 'nginx',
    fail2ban: 'fail2ban'
  };

  const sysService = serviceMap[service] || service;

  if (os.platform() === 'linux') {
    try {
      execSync(`systemctl ${action} ${sysService}`);
    } catch (e) {
      console.warn(`Execution note: ${e.message}`);
    }
  }

  res.json({ success: true, message: `Action ${action} executed for service ${service}.` });
});

// Torrent & P2P Blocker Toggle Endpoint
router.post('/torrent-blocker', (req, res) => {
  const { enable } = req.body;

  if (os.platform() === 'linux') {
    try {
      if (enable) {
        execSync(`iptables -A FORWARD -m string --algo bm --string "BitTorrent" -j DROP`);
        execSync(`iptables -A FORWARD -m string --algo bm --string "peer_id=" -j DROP`);
        execSync(`iptables -A FORWARD -m string --algo bm --string ".torrent" -j DROP`);
        execSync(`iptables -A FORWARD -p tcp --dport 6881:6889 -j DROP`);
        execSync(`iptables -A FORWARD -p udp --dport 6881:6889 -j DROP`);
      } else {
        execSync(`iptables -F FORWARD 2>/dev/null || true`);
      }
    } catch (e) {
      console.warn('IPtables execution warning:', e.message);
    }
  }

  res.json({ success: true, enabled: enable, message: enable ? 'Torrent & P2P Traffic BLOCKED!' : 'Torrent Blocking Disabled.' });
});

// Issue Certbot SSL Certificate Endpoint
router.post('/issue-cert', (req, res) => {
  const { domain, email } = req.body;

  if (os.platform() === 'linux') {
    try {
      execSync(`certbot certonly --standalone -d ${domain} --non-interactive --agree-tos -m ${email || 'admin@' + domain}`);
      execSync(`systemctl restart stunnel4 nginx 2>/dev/null || true`);
      return res.json({ success: true, message: `SSL Certificate issued for ${domain} successfully!` });
    } catch (e) {
      return res.status(500).json({ error: `Certbot error: ${e.message}` });
    }
  }

  res.json({ success: true, message: `Certbot SSL issued for ${domain} (Simulated).` });
});

// Update System Script Endpoint
router.post('/update', (req, res) => {
  console.log('Updating VPS Manager system codebase...');

  if (os.platform() === 'linux') {
    try {
      execSync('cd /usr/local/vps-manager && git pull origin main && npm install --production');
      exec('systemctl restart vps-web-dashboard');
      return res.json({ success: true, message: 'System updated successfully! Restarting dashboard...' });
    } catch (e) {
      return res.status(500).json({ error: e.message });
    }
  }

  res.json({ success: true, message: 'Update simulated (Development Mode).' });
});

// Uninstall & Purge Everything Endpoint
router.post('/uninstall', (req, res) => {
  console.log('Purging system and uninstalling VPS Tunnel Manager...');

  if (os.platform() === 'linux') {
    const uninstallerPath = path.join(__dirname, '../../scripts/uninstall.sh');
    exec(`bash ${uninstallerPath}`);
    return res.json({ success: true, message: 'Uninstallation initiated. All services purged.' });
  }

  res.json({ success: true, message: 'Uninstallation simulated (Development Mode).' });
});

module.exports = router;
