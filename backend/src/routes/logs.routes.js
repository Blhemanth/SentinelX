/**
 * SentinelX - Crime Log Routes
 * GET    /api/logs        → all roles (authenticated)
 * GET    /api/logs/stats  → all roles (authenticated)
 * GET    /api/logs/:id    → all roles (authenticated)
 * POST   /api/logs        → analyst, admin
 * PATCH  /api/logs/:id/acknowledge → analyst, admin
 * DELETE /api/logs/:id    → admin only
 */

const express = require('express');
const router = express.Router();
const {
  getLogs,
  getLogById,
  createLog,
  updateDispatchStatus,
  mockTrigger,
  acknowledgeLog,
  deleteLog,
  getStats,
} = require('../controllers/logs.controller');
const { authenticate } = require('../middleware/auth');
const { requireMinRole, requireRole } = require('../middleware/rbac');

router.get('/stats', authenticate, getStats);
router.get('/', authenticate, getLogs);
router.get('/:id', authenticate, getLogById);
router.post('/', authenticate, createLog);
router.post('/trigger', authenticate, requireMinRole('analyst'), mockTrigger);
router.patch('/:id/dispatch', authenticate, requireMinRole('analyst'), updateDispatchStatus);
router.patch('/:id/acknowledge', authenticate, requireMinRole('analyst'), acknowledgeLog);
router.delete('/:id', authenticate, requireRole('admin'), deleteLog);

module.exports = router;
