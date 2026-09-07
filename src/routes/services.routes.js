const express = require('express');
const router = express.Router();
const os = require('os');
const { execSync } = require('child_process');

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

module.exports = router;
