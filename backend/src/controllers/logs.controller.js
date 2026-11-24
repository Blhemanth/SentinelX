/**
 * SentinelX - Crime Log Controller
 * CRUD + filtering for detection/anomaly event logs.
 * Role access:
 *   GET    → all roles
 *   POST   → analyst, admin (ingest from ML bridge)
 *   PATCH  → analyst, admin (acknowledge)
 *   DELETE → admin only
 */

const mongoose = require('mongoose');
const CrimeLog = require('../models/CrimeLog');
const { verifyInternalServiceToken } = require('../middleware/internalAuth');

// ─── GET /api/logs ─────────────────────────────────────────────────────────────
const getLogs = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 20,
      severity,
      threatClass,
      cameraId,
      dispatchStatus,
      acknowledged,
      startDate,
      endDate,
      createdBy,
    } = req.query;

    const userRole = req.user?.role || 'user';
    const userId = req.user?.userId;

    // Build filter
    const filter = {};
    if (severity) filter.severity = severity;
    if (threatClass) filter.threatClass = threatClass;
    if (cameraId) filter.cameraId = cameraId;
    if (dispatchStatus) filter.dispatchStatus = dispatchStatus;
    if (acknowledged !== undefined) filter.isAcknowledged = acknowledged === 'true';
    if (startDate || endDate) {
      filter.frameTimestamp = {};
      if (startDate) filter.frameTimestamp.$gte = new Date(startDate);
      if (endDate) filter.frameTimestamp.$lte = new Date(endDate);
    }

    // Role-based tenant and surveillance isolation
    if (userRole === 'user') {
      // Standard civilian/tenant user can ONLY see their own records
      if (!userId) {
        return res.status(403).json({ success: false, error: 'Access denied: valid user identity required.' });
      }
      filter.createdBy = userId;
    } else if (['admin', 'analyst', 'police'].includes(userRole)) {
      // Staff roles can view all logs, or filter by specific user if provided
      if (createdBy) filter.createdBy = createdBy;
    }

    const skip = (Number(page) - 1) * Number(limit);
    const [logs, total] = await Promise.all([
      CrimeLog.find(filter)
        .sort({ frameTimestamp: -1 })
        .skip(skip)
        .limit(Number(limit))
        .populate('acknowledgedBy', 'name email')
        .populate('createdBy', 'name email'),
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
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(404).json({ success: false, error: 'Log entry not found.' });
    }

    const log = await CrimeLog.findById(req.params.id)
      .populate('acknowledgedBy', 'name email')
      .populate('createdBy', 'name email');
    if (!log) return res.status(404).json({ success: false, error: 'Log entry not found.' });

    const userRole = req.user?.role || 'user';
    const userId = req.user?.userId;

    // Authorization & IDOR Protection:
    // Staff roles (admin, analyst, police) have full organizational surveillance access.
    // Regular 'user' role can ONLY access their own records.
    const isStaff = ['admin', 'analyst', 'police'].includes(userRole);
    if (!isStaff) {
      const ownerId = log.createdBy
        ? (log.createdBy._id ? log.createdBy._id.toString() : log.createdBy.toString())
        : null;
      if (!ownerId || ownerId !== userId) {
        return res.status(403).json({
          success: false,
          error: 'Access denied: you do not have permission to view this incident.',
        });
      }
    }

    res.status(200).json({ success: true, data: log });
  } catch (err) {
    console.error('[Logs] getLogById error:', err);
    res.status(500).json({ success: false, error: 'Internal server error.' });
  }
};

// ─── POST /api/logs ────────────────────────────────────────────────────────────
const createLog = async (req, res) => {
  try {
    const payload = { ...req.body };
    if (!payload.frameTimestamp) {
      payload.frameTimestamp = new Date();
    }

    // 1. Strip client-supplied authoritative severity, eligibility, internal flags, and ownership
    delete payload.severity; // Authoritative severity derived by Mongoose pre('save')
    delete payload.isEmergencyEligible;
    delete payload.isServerVerifiedAudio;
    delete payload.req_isServerVerifiedAudio;
    delete payload.internalService;
    delete payload.createdBy; // Never trust client-supplied userId/createdBy
    delete payload.userId;

    // 2. Derive user ownership strictly from verified token
    if (req.user && req.user.userId) {
      payload.createdBy = req.user.userId;
    }

    // Explicit simulation flag handling
    if (payload.isSimulation === true) {
      payload.detectionSource = 'drill_simulation';
    }

    // Deduplicate rapid duplicate submissions (same camera, user, and threat within 3 seconds)
    if (payload.createdBy && payload.threatClass && payload.cameraId) {
      const recentDuplicate = await CrimeLog.findOne({
        createdBy: payload.createdBy,
        cameraId: payload.cameraId,
        threatClass: payload.threatClass,
        createdAt: { $gte: new Date(Date.now() - 3000) },
      });
      if (recentDuplicate) {
        return res.status(200).json({
          success: true,
          message: 'Duplicate incident submission acknowledged.',
          data: recentDuplicate,
          isDuplicate: true,
        });
      }
    }

    // 2. SERVER-SIDE SOURCE SANITIZATION & AUTHENTICATION
    // Any incident created via POST /api/logs defaults to manual_entry unless explicitly drill_simulation
    // or verified by server audio pipeline.
    if (!payload.detectionSource || payload.detectionSource === 'legacy_unspecified') {
      payload.detectionSource = 'manual_entry';
    }

    // Clients cannot self-proclaim genuine 'ml_real' without going through /api/detect
    if (payload.detectionSource === 'ml_real') {
      payload.detectionSource = 'manual_entry';
      payload.detectionStatus = 'low_confidence_review';
    }

    // 3. Cryptographic Internal Service Provenance Verification
    // Only trust provenance established by internalServiceAuthMiddleware or valid cryptographic HMAC token.
    // Never trust plain marker headers (e.g. x-sentinelx-internal-source) or unvetted client flags.
    let isInternalServiceAuthenticated = false;
    let authenticatedServiceId = null;

    if (req.internalService && req.internalService.authenticated === true) {
      isInternalServiceAuthenticated = true;
      authenticatedServiceId = req.internalService.serviceId;
    } else {
      const authHeader = req.headers && (req.headers['x-sentinelx-service-auth'] || req.headers['x-sentinelx-internal-token']);
      if (authHeader) {
        const verification = verifyInternalServiceToken(authHeader, req);
        if (verification.valid) {
          isInternalServiceAuthenticated = true;
          authenticatedServiceId = verification.serviceId;
        }
      }
    }

    // 4. Acoustic SOS Trust Policy:
    // Client-reported distress entering via REST cannot self-proclaim genuine 'acoustic_sos'.
    // Even for internal service requests: automated Acoustic SOS is strictly disabled unless
    // verified by an authenticated server-side acoustic speech/keyword verifier ('sentinelx-audio-verifier').
    if (payload.detectionSource === 'acoustic_sos') {
      const isGenuineAudioVerifier = isInternalServiceAuthenticated && authenticatedServiceId === 'sentinelx-audio-verifier';
      if (!isGenuineAudioVerifier) {
        // Untrusted or non-verifier claim: sanitize to manual_entry and low_confidence_review
        payload.detectionSource = 'manual_entry';
        payload.detectionStatus = 'low_confidence_review';
      }
    }

    // 4. Drill simulations and Manual entries cannot be pre-assigned to police on creation
    if (payload.detectionSource === 'drill_simulation' || payload.detectionSource === 'manual_entry') {
      if (['assigned_police', 'en_route', 'on_scene'].includes(payload.dispatchStatus)) {
        payload.dispatchStatus = 'unassigned';
      }
    }

    // 5. Default manual entry status classification
    if (payload.detectionSource === 'manual_entry') {
      if (payload.threatClass === 'Normal') {
        payload.detectionStatus = 'normal';
      } else {
        payload.detectionStatus = 'low_confidence_review';
      }
    }

    const log = await CrimeLog.create(payload);
    res.status(201).json({ success: true, data: log });
  } catch (err) {
    if (err.name === 'ValidationError') {
      return res.status(400).json({ success: false, error: err.message });
    }
    console.error('[Logs] createLog error:', err);
    res.status(500).json({ success: false, error: 'Internal server error.' });
  }
};

// ─── PATCH /api/logs/:id/dispatch ──────────────────────────────────────────────
const updateDispatchStatus = async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(404).json({ success: false, error: 'Log entry not found.' });
    }

    const { dispatchStatus, assignedTo, policeNotes } = req.body;

    const validStatuses = ['unassigned', 'assigned_police', 'en_route', 'on_scene', 'resolved'];
    if (dispatchStatus && !validStatuses.includes(dispatchStatus)) {
      return res.status(400).json({
        success: false,
        error: `Invalid dispatchStatus: "${dispatchStatus}". Valid statuses: ${validStatuses.join(', ')}`,
      });
    }

    const log = await CrimeLog.findById(req.params.id);
    if (!log) return res.status(404).json({ success: false, error: 'Log entry not found.' });

    // STRICT SAFETY BOUNDARY: Drill simulations cannot be dispatched to REAL law enforcement
    if (log.detectionSource === 'drill_simulation' && ['assigned_police', 'en_route', 'on_scene'].includes(dispatchStatus)) {
      const isSimulatedAssignment = req.body.isSimulatedUnit === true ||
        (assignedTo && /simulat|drill|training/i.test(assignedTo));
      if (!isSimulatedAssignment) {
        return res.status(400).json({
          success: false,
          error: 'Drill simulations are training exercises and cannot be dispatched to law enforcement.',
        });
      }
    }

    // State transition enforcement: Cannot re-open resolved incident to police dispatch
    if (log.dispatchStatus === 'resolved' && dispatchStatus && dispatchStatus !== 'resolved') {
      return res.status(400).json({
        success: false,
        error: 'Resolved incidents cannot be re-dispatched. Create a new incident log if needed.',
      });
    }

    const update = {};
    if (dispatchStatus) update.dispatchStatus = dispatchStatus;
    if (assignedTo !== undefined) update.assignedTo = assignedTo;
    if (policeNotes !== undefined) update.policeNotes = policeNotes;

    // Atomic update enforcing safety isolation
    const isSimulatedTarget = req.body.isSimulatedUnit === true ||
      (assignedTo && /simulat|drill|training/i.test(assignedTo));
    const updatedLog = await CrimeLog.findOneAndUpdate(
      {
        _id: req.params.id,
        ...(['assigned_police', 'en_route', 'on_scene'].includes(dispatchStatus) && !isSimulatedTarget
          ? { detectionSource: { $ne: 'drill_simulation' } }
          : {}),
      },
      update,
      { new: true, runValidators: true }
    );

    if (!updatedLog) {
      return res.status(400).json({
        success: false,
        error: 'Dispatch update rejected by safety integrity constraint.',
      });
    }

    res.status(200).json({ success: true, data: updatedLog });
  } catch (err) {
    if (err.name === 'ValidationError') {
      return res.status(400).json({ success: false, error: err.message });
    }
    console.error('[Logs] updateDispatchStatus error:', err);
    res.status(500).json({ success: false, error: 'Internal server error.' });
  }
};

// ─── POST /api/logs/trigger ────────────────────────────────────────────────────
// Injects an anomaly event into MongoDB (useful for live demo drills from Web or Mobile)
const mockTrigger = async (req, res) => {
  try {
    const {
      threatClass = 'Acoustic Distress: HELP, HELP',
      cameraId = 'CAM-001',
      location = 'Primary Perimeter // Gate A',
      audioTranscript = 'Critical Acoustic Distress Detected: "HELP! HELP! EMERGENCY AT SECTOR"',
      confidence = 0.988,
      decibels = 89.2,
    } = req.body;

    // Drill triggers MUST be strictly unassigned regardless of client-supplied dispatchStatus
    const dispatchStatus = 'unassigned';

    const log = await CrimeLog.create({
      threatClass,
      confidence,
      boundingBox: { x: 0.22, y: 0.18, w: 0.44, h: 0.56 },
      detectionSource: 'drill_simulation',
      detectionStatus: 'anomaly_detected',
      isSimulation: true,
      createdBy: req.user?.userId || null,
      cameraId,
      location,
      frameTimestamp: new Date(),
      audioDecibels: decibels,
      audioTranscript,
      dispatchStatus,
      audioFrequencies: [
        0.18, 0.35, 0.58, 0.88, 0.98, 0.92, 0.85, 0.91, 0.96, 0.84,
        0.75, 0.65, 0.55, 0.45, 0.35, 0.28, 0.22, 0.18, 0.14, 0.10,
      ],
      modelVersion: '1.0.0-ONNX-INT8',
      inferenceLatencyMs: 14,
    });

    res.status(201).json({ success: true, message: 'Anomaly triggered and saved to MongoDB.', data: log });
  } catch (err) {
    console.error('[Logs] mockTrigger error:', err);
    res.status(500).json({ success: false, error: 'Internal server error.' });
  }
};

// ─── PATCH /api/logs/:id/acknowledge ──────────────────────────────────────────
const acknowledgeLog = async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(404).json({ success: false, error: 'Log entry not found.' });
    }

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
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(404).json({ success: false, error: 'Log entry not found.' });
    }

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
    const userRole = req.user?.role || 'user';
    const userId = req.user?.userId;
    const isStaff = ['admin', 'analyst', 'police'].includes(userRole);

    const matchFilter = isStaff
      ? {}
      : { createdBy: userId && mongoose.isValidObjectId(userId) ? new mongoose.Types.ObjectId(userId) : null };

    const [bySeverity, byClass, byDispatch, recent, totalLogs] = await Promise.all([
      CrimeLog.aggregate([
        { $match: matchFilter },
        { $group: { _id: '$severity', count: { $sum: 1 } } },
        { $sort: { _id: 1 } },
      ]),
      CrimeLog.aggregate([
        { $match: matchFilter },
        { $group: { _id: '$threatClass', count: { $sum: 1 }, avgConfidence: { $avg: '$confidence' } } },
        { $sort: { count: -1 } },
      ]),
      CrimeLog.aggregate([
        { $match: matchFilter },
        { $group: { _id: '$dispatchStatus', count: { $sum: 1 } } },
        { $sort: { count: -1 } },
      ]),
      CrimeLog.countDocuments({
        ...matchFilter,
        frameTimestamp: { $gte: new Date(Date.now() - 24 * 60 * 60 * 1000) },
      }),
      CrimeLog.countDocuments(matchFilter),
    ]);

    res.status(200).json({
      success: true,
      data: {
        totalLogs,
        last24Hours: recent,
        bySeverity,
        byClass,
        byDispatch,
      },
    });
  } catch (err) {
    console.error('[Logs] getStats error:', err);
    res.status(500).json({ success: false, error: 'Internal server error.' });
  }
};

module.exports = {
  getLogs,
  getLogById,
  createLog,
  updateDispatchStatus,
  mockTrigger,
  acknowledgeLog,
  deleteLog,
  getStats,
};
