/**
 * SentinelX - Crime / Anomaly Detection Log Schema
 * Records all ML inference events with structured metadata.
 */

const mongoose = require('mongoose');

const THREAT_CLASSES = [
  'Explosion',
  'Gunshot',
  'Gunshot Audio',
  'Fighting',
  'Accident',
  'Weapon Detected',
  'Crowd Panic',
  'Acoustic Distress: HELP, HELP',
  'Normal',
];

const boundingBoxSchema = new mongoose.Schema(
  {
    x: { type: Number, required: true, min: 0, max: 1 },
    y: { type: Number, required: true, min: 0, max: 1 },
    w: { type: Number, required: true, min: 0, max: 1 },
    h: { type: Number, required: true, min: 0, max: 1 },
  },
  { _id: false }
);

const latencyMetricsSchema = new mongoose.Schema(
  {
    videoPreprocessMs: { type: Number, default: 0 },
    audioPreprocessMs: { type: Number, default: 0 },
    modelInferenceMs: { type: Number, default: 0 },
    totalLatencyMs: { type: Number, default: 0 },
  },
  { _id: false }
);

const crimeLogSchema = new mongoose.Schema(
  {
    // Detection result
    threatClass: {
      type: String,
      required: true,
    },
    confidence: {
      type: Number,
      required: true,
      min: 0,
      max: 1,
    },
    boundingBox: {
      type: boundingBoxSchema,
      required: false,
    },

    // All class probabilities from softmax
    classProbabilities: {
      type: Map,
      of: Number,
    },

    // Raw logits from model output
    rawLogits: {
      type: [Number],
      default: [],
    },

    // Threat detection state
    detectionStatus: {
      type: String,
      enum: [
        'normal',
        'anomaly_detected',
        'low_confidence_review',
        'subprocess_fallback',
        'legacy_unclassified',
      ],
      default: 'legacy_unclassified',
      index: true,
    },

    // Distinguish genuine ML detections from simulated drills, fallbacks & legacy records
    detectionSource: {
      type: String,
      enum: [
        'ml_real',
        'drill_simulation',
        'acoustic_sos',
        'manual_entry',
        'subprocess_fallback',
        'legacy_unspecified',
      ],
      default: 'legacy_unspecified',
      index: true,
    },

    // Explicit simulation marker
    isSimulation: {
      type: Boolean,
      default: false,
      index: true,
    },

    // Detailed latency metrics
    metrics: {
      type: latencyMetricsSchema,
      required: false,
    },

    // Source metadata
    cameraId: {
      type: String,
      required: true,
      index: true,
    },
    location: {
      type: String,
      default: 'Unknown',
    },
    frameTimestamp: {
      type: Date,
      required: true,
      index: true,
    },

    // Audio data snapshot
    audioDecibels: {
      type: Number,
    },
    audioFrequencies: {
      type: [Number],
    },
    audioTranscript: {
      type: String,
      default: null,
    },

    // Dispatch & Police Action
    assignedTo: {
      type: String,
      default: null,
    },
    dispatchStatus: {
      type: String,
      enum: ['unassigned', 'assigned_police', 'en_route', 'on_scene', 'resolved'],
      default: 'unassigned',
    },
    policeNotes: {
      type: String,
      default: '',
    },

    // Status
    isAcknowledged: {
      type: Boolean,
      default: false,
      index: true,
    },
    acknowledgedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
    acknowledgedAt: {
      type: Date,
    },

    // Severity classification
    severity: {
      type: String,
      enum: ['critical', 'high', 'medium', 'low', 'normal'],
      default: 'normal',
    },

    // User ownership & provenance tracking
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
      index: true,
    },

    // ML model metadata
    modelVersion: {
      type: String,
      default: '1.0.0',
    },
    inferenceLatencyMs: {
      type: Number,
    },
  },
  {
    timestamps: true,
  }
);

// Compound index for efficient dashboard queries
crimeLogSchema.index({ frameTimestamp: -1, severity: 1 });
crimeLogSchema.index({ cameraId: 1, frameTimestamp: -1 });
crimeLogSchema.index({ createdBy: 1, frameTimestamp: -1 });
crimeLogSchema.index({ detectionSource: 1, frameTimestamp: -1 });
crimeLogSchema.index({ detectionStatus: 1, frameTimestamp: -1 });

// Pre-save: derive severity from threatClass + confidence + detectionStatus + detectionSource
crimeLogSchema.pre('save', function (next) {
  // Sync simulation flag with detectionSource
  if (this.detectionSource === 'drill_simulation' || this.isSimulation === true) {
    this.isSimulation = true;
    this.detectionSource = 'drill_simulation';
  }

  // Safe confidence extraction (guard against NaN, null, undefined, non-numbers)
  const conf = typeof this.confidence === 'number' && !isNaN(this.confidence) ? this.confidence : 0;

  // 1. Subprocess fallback -> low
  if (this.detectionStatus === 'subprocess_fallback' || this.detectionSource === 'subprocess_fallback') {
    this.severity = 'low';
  }
  // 2. Low-confidence review -> low
  else if (this.detectionStatus === 'low_confidence_review') {
    this.severity = 'low';
  }
  // 3. Legacy unclassified OR legacy unspecified -> normal
  else if (this.detectionStatus === 'legacy_unclassified' || this.detectionSource === 'legacy_unspecified') {
    this.severity = 'normal';
  }
  // 4. Normal class -> normal
  else if (this.threatClass === 'Normal') {
    this.severity = 'normal';
  }
  // 5. Genuine verified anomaly with confidence >= 0.85 -> critical
  else if (
    this.detectionStatus === 'anomaly_detected' &&
    ['ml_real', 'acoustic_sos', 'drill_simulation'].includes(this.detectionSource) &&
    conf >= 0.85
  ) {
    this.severity = 'critical';
  }
  // 6. Genuine verified anomaly with confidence >= 0.70 and < 0.85 -> high
  else if (
    this.detectionStatus === 'anomaly_detected' &&
    ['ml_real', 'acoustic_sos', 'drill_simulation'].includes(this.detectionSource) &&
    conf >= 0.70
  ) {
    this.severity = 'high';
  }
  // 7. Genuine verified anomaly with confidence >= 0.50 and < 0.70 -> medium
  else if (
    this.detectionStatus === 'anomaly_detected' &&
    ['ml_real', 'acoustic_sos', 'drill_simulation'].includes(this.detectionSource) &&
    conf >= 0.50
  ) {
    this.severity = 'medium';
  }
  // 8. Remaining cases (unverified sources, malformed inputs, or confidence < 0.50) -> low
  else {
    this.severity = 'low';
  }
  next();
});

/**
 * Shared backend eligibility rule for automatic emergency escalation.
 * Automatic critical escalation requires:
 * - Genuine ML: detectionStatus === 'anomaly_detected' && detectionSource === 'ml_real' && severity === 'critical' && confidence >= 0.85
 * - Acoustic SOS: detectionSource === 'acoustic_sos' && (threatClass.includes('HELP') || severity === 'critical')
 * - Drill Simulation: detectionSource === 'drill_simulation' (retains simulated alert behavior, explicitly tagged)
 * Legacy and fallback records are NEVER eligible.
 */
crimeLogSchema.statics.isEmergencyEligible = function (log) {
  if (!log) return false;
  if (log.detectionStatus === 'subprocess_fallback' || log.detectionSource === 'subprocess_fallback') return false;
  if (log.detectionStatus === 'low_confidence_review') return false;
  if (log.detectionStatus === 'legacy_unclassified' || log.detectionSource === 'legacy_unspecified') return false;
  if (log.dispatchStatus === 'resolved') return false;

  // STRICT SAFETY ISOLATION: Drill simulations are training exercises and can NEVER trigger real police dispatch
  if (log.detectionSource === 'drill_simulation') return false;
  if (log.detectionSource === 'manual_entry') return false;

  const conf = typeof log.confidence === 'number' && !isNaN(log.confidence) ? log.confidence : 0;

  // Acoustic distress trigger ("HELP, HELP") - Requires verified acoustic_sos source AND distress threat class
  if (
    log.detectionSource === 'acoustic_sos' &&
    (log.threatClass?.includes('HELP') || log.threatClass?.includes('Acoustic')) &&
    (log.severity === 'critical' || conf >= 0.85)
  ) {
    return true;
  }

  // Genuine verified ML anomaly
  if (
    log.detectionStatus === 'anomaly_detected' &&
    log.detectionSource === 'ml_real' &&
    log.severity === 'critical' &&
    conf >= 0.85
  ) {
    return true;
  }

  return false;
};

crimeLogSchema.statics.THREAT_CLASSES = THREAT_CLASSES;

const CrimeLog = mongoose.model('CrimeLog', crimeLogSchema);
module.exports = CrimeLog;
