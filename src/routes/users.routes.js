const express = require('express');
const router = express.Router();
const UserService = require('../services/user.service');

// Get All Users
router.get('/', (req, res) => {
  res.json(UserService.getAllUsers());
});

// Create Universal User (0 = Lifetime)
router.post('/create', (req, res) => {
  try {
    const user = UserService.createUser(req.body);
    req.app.get('io').emit('users_list', UserService.getAllUsers());
    res.json({ success: true, user });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

// Delete User
router.delete('/:id', (req, res) => {
  try {
    UserService.deleteUser(req.params.id);
    req.app.get('io').emit('users_list', UserService.getAllUsers());
    res.json({ success: true });
  } catch (e) {
    res.status(404).json({ error: e.message });
  }
});

// Toggle Lock / Unlock User Status
router.post('/:id/toggle-status', (req, res) => {
  try {
    const user = UserService.toggleUserStatus(req.params.id);
    req.app.get('io').emit('users_list', UserService.getAllUsers());
    res.json({ success: true, status: user.status });
  } catch (e) {
    res.status(404).json({ error: e.message });
  }
});

// Extend Validity
router.post('/:id/extend', (req, res) => {
  try {
    const user = UserService.extendValidity(req.params.id, req.body.additionalDays);
    req.app.get('io').emit('users_list', UserService.getAllUsers());
    res.json({ success: true, user });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

// Update Bandwidth Limit (0 = Unlimited)
router.post('/:id/bandwidth', (req, res) => {
  try {
    const user = UserService.updateBandwidth(req.params.id, req.body.maxBandwidthGB);
    req.app.get('io').emit('users_list', UserService.getAllUsers());
    res.json({ success: true, user });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

module.exports = router;
