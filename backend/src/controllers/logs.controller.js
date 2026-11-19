/**
 * SentinelX - Crime Log Controller
 * CRUD + filtering for detection/anomaly event logs.
 * Role access:
 *   GET    → all roles
 *   POST   → analyst, admin (ingest from ML bridge)
 *   PATCH  → analyst, admin (acknowledge)
 *   DELETE → admin only
 */

const CrimeLog = require('../models/CrimeLog');

// ─── GET /api/logs ─────────────────────────────────────────────────────────────
const getLogs = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 20,
      severity,
      threatClass,
      cameraId,
      acknowledged,
      startDate,
      endDate,
    } = req.query;

    // Build filter
    const filter = {};
    if (severity) filter.severity = severity;
    if (threatClass) filter.threatClass = threatClass;
    if (cameraId) filter.cameraId = cameraId;
    if (acknowledged !== undefined) filter.isAcknowledged = acknowledged === 'true';
    if (startDate || endDate) {
      filter.frameTimestamp = {};
      if (startDate) filter.frameTimestamp.$gte = new Date(startDate);
      if (endDate) filter.frameTimestamp.$lte = new Date(endDate);
    }

    const skip = (Number(page) - 1) * Number(limit);
    const [logs, total] = await Promise.all([
      CrimeLog.find(filter)
        .sort({ frameTimestamp: -1 })
        .skip(skip)
        .limit(Number(limit))
        .populate('acknowledgedBy', 'name email'),
      CrimeLog.countDocuments(filter),
    ]);

    res.status(200).json({
      success: true,
      data: logs,
      pagination: {
        total,
        page: Number(page),
        limit: Number(limit),
        pages: Math.ceil(total / Number(limit)),
      },
    });
  } catch (err) {
    console.error('[Logs] getLogs error:', err);
    res.status(500).json({ success: false, error: 'Internal server error.' });
  }
};

// ─── GET /api/logs/:id ─────────────────────────────────────────────────────────
const getLogById = async (req, res) => {
  try {
    const log = await CrimeLog.findById(req.params.id).populate('acknowledgedBy', 'name email');
    if (!log) return res.status(404).json({ success: false, error: 'Log entry not found.' });
    res.status(200).json({ success: true, data: log });
  } catch (err) {
    console.error('[Logs] getLogById error:', err);
    res.status(500).json({ success: false, error: 'Internal server error.' });
  }
};

// ─── POST /api/logs ────────────────────────────────────────────────────────────
const createLog = async (req, res) => {
  try {
    const log = await CrimeLog.create(req.body);
    res.status(201).json({ success: true, data: log });
  } catch (err) {
    if (err.name === 'ValidationError') {
      return res.status(400).json({ success: false, error: err.message });
    }
    console.error('[Logs] createLog error:', err);
    res.status(500).json({ success: false, error: 'Internal server error.' });
  }
};

// ─── PATCH /api/logs/:id/acknowledge ──────────────────────────────────────────
const acknowledgeLog = async (req, res) => {
  try {
    const log = await CrimeLog.findByIdAndUpdate(
      req.params.id,
      {
        isAcknowledged: true,
        acknowledgedBy: req.user.userId,
        acknowledgedAt: new Date(),
      },
      { new: true }
    );
    if (!log) return res.status(404).json({ success: false, error: 'Log entry not found.' });
    res.status(200).json({ success: true, data: log });
  } catch (err) {
    console.error('[Logs] acknowledgeLog error:', err);
    res.status(500).json({ success: false, error: 'Internal server error.' });
  }
};

// ─── DELETE /api/logs/:id ──────────────────────────────────────────────────────
const deleteLog = async (req, res) => {
  try {
    const log = await CrimeLog.findByIdAndDelete(req.params.id);
    if (!log) return res.status(404).json({ success: false, error: 'Log entry not found.' });
    res.status(200).json({ success: true, message: 'Log entry deleted.' });
  } catch (err) {
    console.error('[Logs] deleteLog error:', err);
    res.status(500).json({ success: false, error: 'Internal server error.' });
  }
};

// ─── GET /api/logs/stats ───────────────────────────────────────────────────────
const getStats = async (req, res) => {
  try {
    const [bySeverity, byClass, recent] = await Promise.all([
      CrimeLog.aggregate([
        { $group: { _id: '$severity', count: { $sum: 1 } } },
        { $sort: { _id: 1 } },
      ]),
      CrimeLog.aggregate([
        { $group: { _id: '$threatClass', count: { $sum: 1 }, avgConfidence: { $avg: '$confidence' } } },
        { $sort: { count: -1 } },
      ]),
      CrimeLog.countDocuments({
        frameTimestamp: { $gte: new Date(Date.now() - 24 * 60 * 60 * 1000) },
      }),
    ]);

    res.status(200).json({
      success: true,
      data: {
        totalLogs: await CrimeLog.countDocuments(),
        last24Hours: recent,
        bySeverity,
        byClass,
      },
    });
  } catch (err) {
    console.error('[Logs] getStats error:', err);
    res.status(500).json({ success: false, error: 'Internal server error.' });
  }
};

module.exports = { getLogs, getLogById, createLog, acknowledgeLog, deleteLog, getStats };
