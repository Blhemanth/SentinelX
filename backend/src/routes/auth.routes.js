/**
 * SentinelX - Auth Routes
 * Public: POST /register, POST /login, POST /refresh
 * Protected: POST /logout, GET /me
 */

const express = require('express');
const { body } = require('express-validator');
const router = express.Router();
const { register, login, refreshToken, logout, getMe } = require('../controllers/auth.controller');
const { authenticate } = require('../middleware/auth');
const { requireRole } = require('../middleware/rbac');

// ─── Validation middleware ────────────────────────────────────────────────────
const validateRegister = [
  body('name').trim().notEmpty().withMessage('Name is required').isLength({ max: 80 }),
  body('email').isEmail().normalizeEmail().withMessage('Valid email required'),
  body('password')
    .isLength({ min: 8 })
    .withMessage('Password must be at least 8 characters')
    .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
    .withMessage('Password must contain uppercase, lowercase, and a number'),
];

const validateLogin = [
  body('email').isEmail().normalizeEmail().withMessage('Valid email required'),
  body('password').notEmpty().withMessage('Password is required'),
];

const handleValidation = (req, res, next) => {
  const { validationResult } = require('express-validator');
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ success: false, errors: errors.array() });
  }
  next();
};

// ─── Public routes ────────────────────────────────────────────────────────────
router.post('/register', validateRegister, handleValidation, register);
router.post('/login', validateLogin, handleValidation, login);
router.post('/refresh', refreshToken);

// ─── Protected routes ─────────────────────────────────────────────────────────
router.post('/logout', authenticate, logout);
router.get('/me', authenticate, getMe);

// ─── Admin-only: create analyst/admin accounts ────────────────────────────────
router.post(
  '/admin/register',
  authenticate,
  requireRole('admin'),
  validateRegister,
  handleValidation,
  register
);

module.exports = router;
