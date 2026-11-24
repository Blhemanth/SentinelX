/**
 * SentinelX - JWT Authentication Middleware
 * Verifies Bearer token from Authorization header.
 * Attaches decoded user payload to req.user.
 */

const mongoose = require('mongoose');
const { verifyAccessToken } = require('../config/jwt');
const User = require('../models/User');

const authenticate = async (req, res, next) => {
  try {
    // 1. Extract token
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required. Provide a Bearer token.',
      });
    }

    const token = authHeader.split(' ')[1];

    // 2. Verify token signature and expiry
    let decoded;
    try {
      decoded = verifyAccessToken(token);
    } catch (err) {
      const message =
        err.name === 'TokenExpiredError'
          ? 'Access token expired. Please refresh your session.'
          : 'Invalid access token.';
      return res.status(401).json({ success: false, error: message });
    }

    // 3. Confirm user in DB if MongoDB is active and userId is a valid ObjectId
    if (mongoose.connection.readyState === 1 && mongoose.isValidObjectId(decoded.userId)) {
      const user = await User.findById(decoded.userId).select('+passwordChangedAt');
      if (!user || !user.isActive) {
        return res.status(401).json({
          success: false,
          error: 'User account not found or deactivated.',
        });
      }

      // Check if password changed after token was issued
      if (user.passwordChangedAfter && user.passwordChangedAfter(decoded.iat)) {
        return res.status(401).json({
          success: false,
          error: 'Password was recently changed. Please log in again.',
        });
      }

      req.user = {
        userId: user._id.toString(),
        email: user.email,
        role: user.role,
        name: user.name,
      };
    } else {
      // Valid signed JWT token (offline/test mode)
      req.user = {
        userId: decoded.userId,
        email: decoded.email,
        role: decoded.role || 'user',
        name: decoded.name || 'User',
      };
    }

    next();
  } catch (err) {
    console.error('[Auth Middleware] Unexpected error:', err.message);
    res.status(500).json({ success: false, error: 'Internal server error.' });
  }
};

/**
 * Permissive authentication for logout / cleanup routes.
 * If a valid Bearer token is present, sets req.user.
 * If expired or missing, allows execution to proceed cleanly so session revocation succeeds.
 */
const permissiveAuthenticate = (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.split(' ')[1];
    try {
      const decoded = verifyAccessToken(token);
      req.user = decoded;
    } catch (_) {
      // Permissive: token expired or invalid; proceed so logout clears session/cookies
    }
  }
  next();
};

module.exports = { authenticate, permissiveAuthenticate };
