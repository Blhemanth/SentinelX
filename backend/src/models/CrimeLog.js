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

// Pre-save: derive severity from threatClass + confidence
crimeLogSchema.pre('save', function (next) {
  if (this.threatClass === 'Normal') {
    this.severity = 'normal';
  } else if (this.confidence >= 0.85) {
    this.severity = 'critical';
  } else if (this.confidence >= 0.70) {
    this.severity = 'high';
  } else if (this.confidence >= 0.50) {
    this.severity = 'medium';
  } else {
    this.severity = 'low';
  }
  next();
});

crimeLogSchema.statics.THREAT_CLASSES = THREAT_CLASSES;

const CrimeLog = mongoose.model('CrimeLog', crimeLogSchema);
module.exports = CrimeLog;
