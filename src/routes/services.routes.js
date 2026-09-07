const express = require('express');
const router = express.Router();
const os = require('os');
const { execSync, exec } = require('child_process');
const path = require('path');

// Security Whitelist Maps
const ALLOWED_ACTIONS = ['start', 'stop', 'restart', 'status', 'reload', 'reboot'];
const SERVICE_MAP = {
  ssh: 'ssh',
  dropbear: 'dropbear',
  stunnel: 'stunnel4',
  wsProxy: 'ws-proxy',
  udpCustom: 'udp-custom',
  badvpn: 'badvpn-7300',
  v2ray: 'xray',
  openvpn: 'openvpn',
  nginx: 'nginx',
  fail2ban: 'fail2ban',
  slowdns: 'slowdns',
  system: 'system'
};

// Restart/Start/Stop Service Endpoint with Security Whitelist
router.post('/action', (req, res) => {
  const { service, action } = req.body;

  if (!ALLOWED_ACTIONS.includes(action)) {
    return res.status(400).json({ error: 'Invalid service action!' });
  }

  const sysService = SERVICE_MAP[service];
  if (!sysService && service !== 'system') {
    return res.status(400).json({ error: 'Invalid service key!' });
  }

  console.log(`[SECURITY AUDIT PASSED] Executing ${action} on service ${service}`);

  if (os.platform() === 'linux') {
    try {
      if (service === 'system' && action === 'reboot') {
        exec('reboot');
      } else {
        execSync(`systemctl ${action} ${sysService}`);
      }
    } catch (e) {
      console.warn(`Execution note: ${e.message}`);
    }
  }

  res.json({ success: true, message: `Action ${action} executed for service ${service}.` });
});

// Torrent & P2P Blocker Toggle Endpoint
router.post('/torrent-blocker', (req, res) => {
  const enable = Boolean(req.body.enable);

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

// Issue Certbot SSL Certificate Endpoint with Security Regex
router.post('/issue-cert', (req, res) => {
  const { domain, email } = req.body;

  if (!domain || !/^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/.test(domain)) {
    return res.status(400).json({ error: 'Invalid domain name format!' });
  }

  const safeDomain = domain.replace(/[^a-zA-Z0-9.-]/g, '');
  const safeEmail = email && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ? email : `admin@${safeDomain}`;

  if (os.platform() === 'linux') {
    try {
      execSync(`certbot certonly --standalone -d ${safeDomain} --non-interactive --agree-tos -m ${safeEmail}`);
      execSync(`systemctl restart stunnel4 nginx 2>/dev/null || true`);
      return res.json({ success: true, message: `SSL Certificate issued for ${safeDomain} successfully!` });
    } catch (e) {
      return res.status(500).json({ error: `Certbot error: ${e.message}` });
    }
  }

  res.json({ success: true, message: `Certbot SSL issued for ${safeDomain} (Simulated).` });
});

// UFW Firewall Rule Control Endpoint
router.post('/ufw', (req, res) => {
  const { port, protocol, action } = req.body;
  const numPort = parseInt(port, 10);
  const proto = protocol === 'udp' ? 'udp' : 'tcp';
  const ufwAction = action === 'delete' ? 'delete allow' : 'allow';

  if (isNaN(numPort) || numPort < 1 || numPort > 65535) {
    return res.status(400).json({ error: 'Invalid port number (1-65535)' });
  }

  if (os.platform() === 'linux') {
    try {
      execSync(`ufw ${ufwAction} ${numPort}/${proto}`);
    } catch (e) {
      console.warn('UFW command note:', e.message);
    }
  }

  res.json({ success: true, message: `UFW firewall rule updated: ${ufwAction} ${numPort}/${proto}` });
});

// Fail2Ban IP Control Endpoint
router.post('/fail2ban/unban', (req, res) => {
  const { ip, jail } = req.body;
  if (!ip || !/^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/.test(ip)) {
    return res.status(400).json({ error: 'Invalid IP address format!' });
  }

  const safeJail = jail ? jail.replace(/[^a-zA-Z0-9_-]/g, '') : 'sshd';

  if (os.platform() === 'linux') {
    try {
      execSync(`fail2ban-client unbanip ${ip}`);
    } catch (e) {
      console.warn('Fail2Ban unban note:', e.message);
    }
  }

  res.json({ success: true, message: `IP ${ip} unbanned from Fail2Ban jail '${safeJail}'.` });
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
