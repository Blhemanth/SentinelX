/**
 * SentinelX - Refresh Token Session Schema
 * Stores active refresh tokens; enables secure token invalidation.
 */

const mongoose = require('mongoose');

const sessionSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    refreshToken: {
      type: String,
      required: true,
      unique: true,
    },
    userAgent: {
      type: String,
      default: 'unknown',
    },
    ipAddress: {
      type: String,
      default: 'unknown',
    },
    expiresAt: {
      type: Date,
      required: true,
      index: { expireAfterSeconds: 0 }, // MongoDB TTL auto-cleanup
    },
    isRevoked: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
  }
);

// Index for fast lookup + revocation check
sessionSchema.index({ refreshToken: 1, isRevoked: 1 });

const Session = mongoose.model('Session', sessionSchema);
module.exports = Session;
