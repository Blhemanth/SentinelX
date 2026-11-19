/**
 * SentinelX - Detection Routes
 * POST /api/detect — Run ML inference (analyst, admin)
 * GET  /api/detect/health — ML service health (all authenticated)
 */

const express = require('express');
const router = express.Router();
const { detect, mlHealth } = require('../controllers/detect.controller');
const { authenticate } = require('../middleware/auth');
const { requireMinRole } = require('../middleware/rbac');

router.get('/health', authenticate, mlHealth);
router.post('/', authenticate, requireMinRole('analyst'), detect);

module.exports = router;
