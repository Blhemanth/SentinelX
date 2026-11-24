/**
 * SentinelX - JWT Configuration & Token Utilities
 * Hardened for Phase 2:
 * - Cryptographic JTI nonces on refresh tokens (eliminates sub-second collision)
 * - Strict startup secret validation & production environment enforcement
 * - Masked token error logging
 */

const crypto = require('crypto');
const jwt = require('jsonwebtoken');

const INSECURE_DEFAULT_SECRETS = [
  'sentinelx_access_dev_secret_CHANGE_IN_PROD',
  'sentinelx_refresh_dev_secret_CHANGE_IN_PROD',
  'your_access_secret_min_64_chars_change_in_production',
  'your_refresh_secret_min_64_chars_change_in_production',
  'change_in_production',
  'secret',
  'jwt_secret',
];

/**
 * Validate JWT configuration on startup.
 * In production: throws fatal errors on insecure, short, or identical secrets.
 * In development: warns cleanly without halting execution.
 */
const validateJwtConfig = () => {
  const isProd = process.env.NODE_ENV === 'production';
  const accessSecret = process.env.JWT_ACCESS_SECRET;
  const refreshSecret = process.env.JWT_REFRESH_SECRET;

  if (isProd) {
    if (!accessSecret || accessSecret.trim().length < 32) {
      throw new Error('[JWT Security Fatal] Production environment requires JWT_ACCESS_SECRET with minimum 32 characters.');
    }
    if (!refreshSecret || refreshSecret.trim().length < 32) {
      throw new Error('[JWT Security Fatal] Production environment requires JWT_REFRESH_SECRET with minimum 32 characters.');
    }
    if (INSECURE_DEFAULT_SECRETS.includes(accessSecret) || INSECURE_DEFAULT_SECRETS.includes(refreshSecret)) {
      throw new Error('[JWT Security Fatal] Insecure default JWT secret detected in production environment.');
    }
    if (accessSecret === refreshSecret) {
      throw new Error('[JWT Security Fatal] JWT_ACCESS_SECRET and JWT_REFRESH_SECRET must be distinct cryptographic keys.');
    }
  } else {
    if (!accessSecret || INSECURE_DEFAULT_SECRETS.includes(accessSecret)) {
      console.warn('[JWT Security Warning] Using default development JWT_ACCESS_SECRET. Replace with strong 64+ char key in production.');
    }
    if (!refreshSecret || INSECURE_DEFAULT_SECRETS.includes(refreshSecret)) {
      console.warn('[JWT Security Warning] Using default development JWT_REFRESH_SECRET. Replace with strong 64+ char key in production.');
    }
    if (accessSecret && refreshSecret && accessSecret === refreshSecret) {
      console.warn('[JWT Security Warning] JWT_ACCESS_SECRET and JWT_REFRESH_SECRET should not be identical.');
    }
  }
};

validateJwtConfig();

const ACCESS_SECRET = process.env.JWT_ACCESS_SECRET || 'sentinelx_access_dev_secret_CHANGE_IN_PROD';
const REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'sentinelx_refresh_dev_secret_CHANGE_IN_PROD';
const ACCESS_EXPIRES = process.env.JWT_ACCESS_EXPIRES || '15m';
const REFRESH_EXPIRES = process.env.JWT_REFRESH_EXPIRES || '7d';

/**
 * Generate a signed access token (short-lived, 15m).
 * @param {object} payload - { userId, email, role }
 */
const generateAccessToken = (payload) => {
  return jwt.sign(payload, ACCESS_SECRET, { expiresIn: ACCESS_EXPIRES });
};

/**
 * Generate a signed refresh token (long-lived, 7d).
 * Injects a cryptographically random UUID jti to guarantee 100% uniqueness
 * even when generated within the same millisecond or second.
 * @param {object} payload - { userId }
 */
const generateRefreshToken = (payload) => {
  const tokenPayload = {
    ...payload,
    jti: crypto.randomUUID(),
  };
  return jwt.sign(tokenPayload, REFRESH_SECRET, { expiresIn: REFRESH_EXPIRES });
};

/**
 * Helper to mask JWT for secure logging. Never log full tokens.
 */
const maskToken = (token) => {
  if (!token || typeof token !== 'string') return '[empty]';
  if (token.length <= 16) return '***';
  return `${token.slice(0, 6)}...${token.slice(-6)}`;
};

/**
 * Verify an access token. Throws if invalid or expired.
 */
const verifyAccessToken = (token) => {
  try {
    return jwt.verify(token, ACCESS_SECRET);
  } catch (err) {
    err.maskedToken = maskToken(token);
    throw err;
  }
};

/**
 * Verify a refresh token. Throws if invalid or expired.
 */
const verifyRefreshToken = (token) => {
  try {
    return jwt.verify(token, REFRESH_SECRET);
  } catch (err) {
    err.maskedToken = maskToken(token);
    throw err;
  }
};

module.exports = {
  generateAccessToken,
  generateRefreshToken,
  verifyAccessToken,
  verifyRefreshToken,
  validateJwtConfig,
  maskToken,
  ACCESS_EXPIRES,
  REFRESH_EXPIRES,
};
