const express = require('express');
const router = express.Router();
const { verifyLogin, createToken, revokeToken, extractToken, isValidToken } = require('../utils/auth');

// Login to the admin dashboard
router.post('/login', (req, res) => {
  const { username, password } = req.body || {};
  if (!verifyLogin(username, password)) {
    return res.status(401).json({ error: 'Invalid admin username or password.' });
  }
  const token = createToken();
  res.json({ success: true, token, admin: true });
});

// Logout and revoke the current token
router.post('/logout', (req, res) => {
  revokeToken(extractToken(req));
  res.json({ success: true });
});

// Check if the current token is still valid
router.get('/status', (req, res) => {
  const token = extractToken(req);
  res.json({ authenticated: isValidToken(token) });
});

module.exports = router;