/**
 * SentinelX - Auth Controller
 * Handles: register, login, refreshToken, logout, getMe
 */

const { v4: uuidv4 } = require('uuid');
const User = require('../models/User');
const Session = require('../models/Session');
const {
  generateAccessToken,
  generateRefreshToken,
  verifyRefreshToken,
  REFRESH_EXPIRES,
} = require('../config/jwt');

// ─── Helper: parse JWT expires string to ms ──────────────────────────────────
const parseExpiresToMs = (expiresStr) => {
  const unit = expiresStr.slice(-1);
  const value = parseInt(expiresStr.slice(0, -1), 10);
  const map = { s: 1000, m: 60000, h: 3600000, d: 86400000 };
  return value * (map[unit] || 1000);
};

// ─── POST /api/auth/register ─────────────────────────────────────────────────
const register = async (req, res) => {
  try {
    const { name, email, password, role } = req.body;

    // Only admins can create non-user roles (enforced at route level too)
    const assignedRole =
      req.user?.role === 'admin' && ['analyst', 'admin'].includes(role)
        ? role
        : 'user';

    const existing = await User.findOne({ email });
    if (existing) {
      return res.status(409).json({ success: false, error: 'Email already registered.' });
    }

    const user = await User.create({ name, email, password, role: assignedRole });

    res.status(201).json({
      success: true,
      message: 'Account created successfully.',
      data: {
        userId: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
      },
    });
  } catch (err) {
    if (err.name === 'ValidationError') {
      return res.status(400).json({ success: false, error: err.message });
    }
    console.error('[Auth] register error:', err);
    res.status(500).json({ success: false, error: 'Internal server error.' });
  }
};

// ─── POST /api/auth/login ─────────────────────────────────────────────────────
const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    // Fetch user with password field
    const user = await User.findOne({ email }).select('+password');
    if (!user || !user.isActive) {
      return res.status(401).json({ success: false, error: 'Invalid credentials.' });
    }

    const passwordMatch = await user.comparePassword(password);
    if (!passwordMatch) {
      return res.status(401).json({ success: false, error: 'Invalid credentials.' });
    }

    // Generate tokens
    const tokenPayload = { userId: user._id.toString(), email: user.email, role: user.role };
    const accessToken = generateAccessToken(tokenPayload);
    const refreshToken = generateRefreshToken({ userId: user._id.toString() });

    // Store session
    await Session.create({
      userId: user._id,
      refreshToken,
      userAgent: req.headers['user-agent'] || 'unknown',
      ipAddress: req.ip,
      expiresAt: new Date(Date.now() + parseExpiresToMs(REFRESH_EXPIRES)),
    });

    // Update lastLogin
    user.lastLogin = new Date();
    await user.save({ validateBeforeSave: false });

    res.status(200).json({
      success: true,
      data: {
        accessToken,
        refreshToken,
        expiresIn: 900, // 15 minutes in seconds
        user: {
          userId: user._id,
          name: user.name,
          email: user.email,
          role: user.role,
        },
      },
    });
  } catch (err) {
    console.error('[Auth] login error:', err);
    res.status(500).json({ success: false, error: 'Internal server error.' });
  }
};

// ─── POST /api/auth/refresh ───────────────────────────────────────────────────
const refreshToken = async (req, res) => {
  try {
    const { refreshToken: token } = req.body;
    if (!token) {
      return res.status(400).json({ success: false, error: 'Refresh token required.' });
    }

    // Verify signature
    let decoded;
    try {
      decoded = verifyRefreshToken(token);
    } catch {
      return res.status(401).json({ success: false, error: 'Invalid or expired refresh token.' });
    }

    // Check session in DB
    const session = await Session.findOne({ refreshToken: token, isRevoked: false });
    if (!session) {
      return res.status(401).json({ success: false, error: 'Session not found or revoked.' });
    }

    // Fetch user
    const user = await User.findById(decoded.userId);
    if (!user || !user.isActive) {
      return res.status(401).json({ success: false, error: 'User not found or deactivated.' });
    }

    // Rotate tokens (revoke old, issue new)
    session.isRevoked = true;
    await session.save();

    const tokenPayload = { userId: user._id.toString(), email: user.email, role: user.role };
    const newAccessToken = generateAccessToken(tokenPayload);
    const newRefreshToken = generateRefreshToken({ userId: user._id.toString() });

    await Session.create({
      userId: user._id,
      refreshToken: newRefreshToken,
      userAgent: req.headers['user-agent'] || 'unknown',
      ipAddress: req.ip,
      expiresAt: new Date(Date.now() + parseExpiresToMs(REFRESH_EXPIRES)),
    });

    res.status(200).json({
      success: true,
      data: {
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
        expiresIn: 900,
      },
    });
  } catch (err) {
    console.error('[Auth] refresh error:', err);
    res.status(500).json({ success: false, error: 'Internal server error.' });
  }
};

// ─── POST /api/auth/logout ────────────────────────────────────────────────────
const logout = async (req, res) => {
  try {
    const { refreshToken: token } = req.body;
    if (token) {
      await Session.updateOne({ refreshToken: token }, { isRevoked: true });
    }
    res.status(200).json({ success: true, message: 'Logged out successfully.' });
  } catch (err) {
    console.error('[Auth] logout error:', err);
    res.status(500).json({ success: false, error: 'Internal server error.' });
  }
};

// ─── GET /api/auth/me ─────────────────────────────────────────────────────────
const getMe = async (req, res) => {
  try {
    const user = await User.findById(req.user.userId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found.' });
    }
    res.status(200).json({
      success: true,
      data: {
        userId: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        lastLogin: user.lastLogin,
        createdAt: user.createdAt,
      },
    });
  } catch (err) {
    console.error('[Auth] getMe error:', err);
    res.status(500).json({ success: false, error: 'Internal server error.' });
  }
};

module.exports = { register, login, refreshToken, logout, getMe };
