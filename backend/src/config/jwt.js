/**
 * SentinelX - JWT Configuration & Token Utilities
 */

const jwt = require('jsonwebtoken');

const ACCESS_SECRET = process.env.JWT_ACCESS_SECRET || 'sentinelx_access_dev_secret_CHANGE_IN_PROD';
const REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'sentinelx_refresh_dev_secret_CHANGE_IN_PROD';
const ACCESS_EXPIRES = process.env.JWT_ACCESS_EXPIRES || '15m';
const REFRESH_EXPIRES = process.env.JWT_REFRESH_EXPIRES || '7d';

/**
 * Generate a signed access token (short-lived).
 * @param {object} payload - { userId, email, role }
 */
const generateAccessToken = (payload) => {
  return jwt.sign(payload, ACCESS_SECRET, { expiresIn: ACCESS_EXPIRES });
};

/**
 * Generate a signed refresh token (long-lived).
 * @param {object} payload - { userId }
 */
const generateRefreshToken = (payload) => {
  return jwt.sign(payload, REFRESH_SECRET, { expiresIn: REFRESH_EXPIRES });
};

/**
 * Verify an access token. Throws if invalid or expired.
 */
const verifyAccessToken = (token) => {
  return jwt.verify(token, ACCESS_SECRET);
};

/**
 * Verify a refresh token. Throws if invalid or expired.
 */
const verifyRefreshToken = (token) => {
  return jwt.verify(token, REFRESH_SECRET);
};

module.exports = {
  generateAccessToken,
  generateRefreshToken,
  verifyAccessToken,
  verifyRefreshToken,
  ACCESS_EXPIRES,
  REFRESH_EXPIRES,
};
