const express = require('express');
const router = express.Router();
const TelemetryService = require('../services/telemetry.service');
const UserService = require('../services/user.service');

router.get('/', (req, res) => {
  const users = UserService.getAllUsers();
  const activeCount = users.filter(u => u.status === 'active').length * 2;
  res.json(TelemetryService.getMetrics(activeCount));
});

module.exports = router;
