/**
 * SentinelX - ML Detection Controller
 * Bridges the Node.js Express backend to the Python FastAPI ML microservice.
 * POST /api/detect — Ingests video/audio, forwards to Python, records genuine ML log to MongoDB.
 */

const { callMlService } = require('../services/mlBridge.service');
const CrimeLog = require('../models/CrimeLog');
const { validateBase64WavAudio } = require('../utils/wavValidator');

// ─── POST /api/detect ─────────────────────────────────────────────────────────
const detect = async (req, res) => {
  try {
    const {
      cameraId,
      location,
      frameTimestamp,
      videoFrames,  // base64-encoded video file or video clip bytes
      audioData,    // base64-encoded WAV audio bytes
      videoPath,
      audioPath,
    } = req.body;

    if (!cameraId) {
      return res.status(400).json({ success: false, error: 'cameraId is required.' });
    }

    // ── Strict Input Audio Validation (Deep WAV Header & Structure Inspection) ─
    if (audioData !== undefined && audioData !== null) {
      const validation = validateBase64WavAudio(audioData);
      if (!validation.valid) {
        const isTooLarge = validation.error && validation.error.includes('exceeds maximum permitted size');
        return res.status(isTooLarge ? 413 : 400).json({
          success: false,
          error: validation.error,
        });
      }
    }

    const startTime = Date.now();

    // ── Call Python ML microservice or subprocess fallback ───────────────────
    const mlResult = await callMlService({
      camera_id: cameraId,
      video_frames: videoFrames || null,
      audio_data: audioData || null,
      video_path: videoPath || null,
      audio_path: audioPath || null,
    });

    const latencyMs = Date.now() - startTime;

    const rawBbox = mlResult.bbox || [0, 0, 0, 0];
    const bbox = Array.isArray(rawBbox)
      ? { x: rawBbox[0] || 0, y: rawBbox[1] || 0, w: rawBbox[2] || 0, h: rawBbox[3] || 0 }
      : { x: rawBbox.x || 0, y: rawBbox.y || 0, w: rawBbox.w || 0, h: rawBbox.h || 0 };

    const metrics = mlResult.metrics || {
      videoPreprocessMs: 0,
      audioPreprocessMs: 0,
      modelInferenceMs: latencyMs,
      totalLatencyMs: latencyMs,
    };

    // Determine genuine ML vs subprocess fallback
    const isFallback = Boolean(
      mlResult.is_fallback ||
      mlResult.detection_status === 'subprocess_fallback' ||
      mlResult.detection_source === 'subprocess_fallback' ||
      mlResult.model_loaded === false
    );

    const detectionSource = isFallback
      ? 'subprocess_fallback'
      : (mlResult.detection_source || 'ml_real');

    const detectionStatus = isFallback
      ? 'subprocess_fallback'
      : (mlResult.detection_status || 'normal');

    // ── Build response payload ───────────────────────────────────────────────
    const safeConfidence = (typeof mlResult.confidence === 'number' && !isNaN(mlResult.confidence))
      ? mlResult.confidence
      : (isFallback ? 0.50 : 0.0);

    const result = {
      threatClass: mlResult.threat_class || 'Normal',
      confidence: safeConfidence,
      boundingBox: bbox,
      classProbabilities: mlResult.class_probabilities || {},
      rawLogits: mlResult.raw_logits || [],
      detectionStatus: detectionStatus,
      detectionSource: detectionSource,
      isFallback: isFallback,
      isEmergencyEligible: CrimeLog.isEmergencyEligible({
        detectionStatus,
        detectionSource,
        severity: (detectionStatus === 'anomaly_detected' && safeConfidence >= 0.85) ? 'critical' : 'normal',
        confidence: safeConfidence,
        threatClass: mlResult.threat_class || 'Normal',
      }),
      metrics: {
        videoPreprocessMs: metrics.video_preprocess_ms || metrics.videoPreprocessMs || 0,
        audioPreprocessMs: metrics.audio_preprocess_ms || metrics.audioPreprocessMs || 0,
        modelInferenceMs: metrics.model_inference_ms || metrics.modelInferenceMs || latencyMs,
        totalLatencyMs: metrics.total_latency_ms || metrics.totalLatencyMs || latencyMs,
      },
      inferenceLatencyMs: latencyMs,
      modelVersion: mlResult.model_version || '1.0.0',
    };

    // ── Persist to MongoDB with verified detectionStatus and detectionSource ──
    CrimeLog.create({
      threatClass: result.threatClass,
      confidence: result.confidence,
      boundingBox: result.boundingBox,
      classProbabilities: result.classProbabilities,
      rawLogits: result.rawLogits,
      detectionStatus: result.detectionStatus,
      detectionSource: result.detectionSource,
      metrics: result.metrics,
      cameraId,
      location: location || 'Unknown',
      frameTimestamp: frameTimestamp ? new Date(frameTimestamp) : new Date(),
      modelVersion: result.modelVersion,
      inferenceLatencyMs: latencyMs,
    }).catch((err) => console.error('[Detect] Failed to persist CrimeLog:', err.message));

    res.status(200).json({
      success: true,
      data: result,
    });
  } catch (err) {
    console.error('[Detect] detect error:', err.message);

    if (err.code === 'ECONNREFUSED' || err.message?.includes('fetch')) {
      return res.status(503).json({
        success: false,
        error: 'ML inference service unavailable. Ensure server_ml/inference_api.py is running.',
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
