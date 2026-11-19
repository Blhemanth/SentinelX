/**
 * SentinelX - ML Detection Controller
 * Bridges the Node.js Express backend to the Python FastAPI ML microservice.
 * POST /api/detect — Accepts JSON payload, forwards to Python, returns structured results.
 */

const { callMlService } = require('../services/mlBridge.service');
const CrimeLog = require('../models/CrimeLog');

// ─── POST /api/detect ─────────────────────────────────────────────────────────
const detect = async (req, res) => {
  try {
    const {
      cameraId,
      location,
      frameTimestamp,
      videoFrames,  // base64-encoded or tensor metadata
      audioData,    // base64 Mel-spectrogram or frequency array
    } = req.body;

    if (!cameraId) {
      return res.status(400).json({ success: false, error: 'cameraId is required.' });
    }

    const startTime = Date.now();

    // ── Call Python ML microservice ──────────────────────────────────────────
    const mlResult = await callMlService({
      camera_id: cameraId,
      video_frames: videoFrames || null,
      audio_data: audioData || null,
    });

    const latencyMs = Date.now() - startTime;

    const rawBbox = mlResult.bbox || [0, 0, 0, 0];
    const bbox = Array.isArray(rawBbox)
      ? { x: rawBbox[0] || 0, y: rawBbox[1] || 0, w: rawBbox[2] || 0, h: rawBbox[3] || 0 }
      : { x: rawBbox.x || 0, y: rawBbox.y || 0, w: rawBbox.w || 0, h: rawBbox.h || 0 };

    // ── Build response payload ───────────────────────────────────────────────
    const result = {
      threatClass: mlResult.threat_class || 'Normal',
      confidence: mlResult.confidence ?? 0.85,
      boundingBox: bbox,
      classProbabilities: mlResult.class_probabilities || {},
      inferenceLatencyMs: latencyMs,
      modelVersion: mlResult.model_version || '1.0.0',
    };

    // ── Persist to MongoDB (non-blocking) ────────────────────────────────────
    CrimeLog.create({
      ...result,
      cameraId,
      location: location || 'Unknown',
      frameTimestamp: frameTimestamp ? new Date(frameTimestamp) : new Date(),
    }).catch((err) => console.error('[Detect] Failed to persist CrimeLog:', err));

    res.status(200).json({
      success: true,
      data: result,
    });
  } catch (err) {
    console.error('[Detect] detect error:', err.message);

    // If ML service unreachable, return mock/fallback
    if (err.code === 'ECONNREFUSED' || err.message?.includes('fetch')) {
      return res.status(503).json({
        success: false,
        error: 'ML inference service unavailable. Ensure server_ml/inference_api.py is running.',
        fallback: {
          threatClass: 'Normal',
          confidence: 0.0,
          boundingBox: { x: 0, y: 0, w: 0, h: 0 },
          classProbabilities: {
            Explosion: 0.0,
            Gunshot: 0.0,
            Fighting: 0.0,
            Accident: 0.0,
            Normal: 1.0,
          },
        },
      });
    }

    res.status(500).json({ success: false, error: 'Internal server error.' });
  }
};

// ─── GET /api/detect/health ────────────────────────────────────────────────────
const mlHealth = async (req, res) => {
  try {
    const ML_URL = process.env.ML_SERVICE_URL || 'http://localhost:8000';
    const response = await fetch(`${ML_URL}/health`, { signal: AbortSignal.timeout(3000) });
    const data = await response.json();
    res.status(200).json({ success: true, mlService: data });
  } catch {
    res.status(503).json({
      success: false,
      error: 'ML service unreachable.',
      mlService: { status: 'offline' },
    });
  }
};

module.exports = { detect, mlHealth };
