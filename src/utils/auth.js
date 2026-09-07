const crypto = require('crypto');

/**
 * Admin Authentication Module
 * - Credentials come from environment variables ADMIN_USER / ADMIN_PASSWORD.
 * - Issues in-memory bearer tokens stored in the running process.
 * - Token TTL enforced (24 hours) with lazy expiry purge.
 */

const DEFAULT_USER = 'admin';
const DEFAULT_PASS = 'admin123';

const adminUser = process.env.ADMIN_USER || DEFAULT_USER;
const adminPass = process.env.ADMIN_PASSWORD || DEFAULT_PASS;

const TOKEN_TTL_MS = 24 * 60 * 60 * 1000; // 24 hours
const tokens = new Map(); // token -> expiresAt

if (!process.env.ADMIN_PASSWORD) {
  console.warn(`[AUTH] Using DEFAULT admin password! Set ADMIN_PASSWORD env var to secure the dashboard.`);
}

function sha256(value) {
  return crypto.createHash('sha256').update(String(value)).digest();
}

function safeEqual(a, b) {
  const bufA = sha256(a);
  const bufB = sha256(b);
  return crypto.timingSafeEqual(bufA, bufB);
}

function verifyLogin(username, password) {
  if (!username || !password) return false;
  return safeEqual(username, adminUser) && safeEqual(password, adminPass);
}

function createToken() {
  const token = crypto.randomBytes(32).toString('hex');
  tokens.set(token, Date.now() + TOKEN_TTL_MS);
  return token;
}

function isValidToken(token) {
  if (!token || typeof token !== 'string') return false;
  const expiresAt = tokens.get(token);
  if (!expiresAt) return false;
  if (Date.now() > expiresAt) {
    tokens.delete(token);
    return false;
  }
  return true;
}

function revokeToken(token) {
  if (token) tokens.delete(token);
}

function extractToken(req) {
  const header = req.headers.authorization || '';
  if (header.startsWith('Bearer ')) return header.slice(7).trim();
  if (req.headers['x-auth-token']) return req.headers['x-auth-token'].trim();
  if (req.query && req.query.token) return String(req.query.token);
  return null;
}

function requireAuth(req, res, next) {
  const token = extractToken(req);
  if (!isValidToken(token)) {
    return res.status(401).json({ error: 'Unauthorized. Please log in.' });
  }
  return next();
}

module.exports = { verifyLogin, createToken, isValidToken, revokeToken, requireAuth, extractToken };