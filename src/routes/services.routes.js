const express = require('express');
const router = express.Router();
const os = require('os');
const { execSync, exec } = require('child_process');
const path = require('path');

// Restart/Action Service Endpoint
router.post('/action', (req, res) => {
  const { service, action } = req.body;
  console.log(`Executing ${action} on service ${service}`);

  if (os.platform() === 'linux') {
    try {
      execSync(`systemctl ${action} ${service}`);
    } catch (e) {
      console.warn(`Execution note: ${e.message}`);
    }
  }

  res.json({ success: true, message: `Action ${action} executed for service ${service}.` });
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
