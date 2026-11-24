/**
 * SentinelX — Phase 4.2.5 Adversarial Security & Audio Validation Suite
 * 
 * Tests 19 Discrete Scenarios:
 * 1.  Missing INTERNAL_SERVICE_KEY in production fails closed
 * 2.  Weak INTERNAL_SERVICE_KEY (<32 chars) in production fails closed
 * 3.  Default secret in production fails closed
 * 4.  Plain marker header (x-sentinelx-internal-source) cannot authenticate
 * 5.  Client cannot set req.isServerVerifiedAudio or body flag
 * 6.  Forged internal provenance token rejected
 * 7.  Invalid or expired authenticated request (>60s) rejected
 * 8.  Replay of a previously authenticated internal request blocked
 * 9.  Valid authenticated internal request succeeds
 * 10. Invalid WAV chunk structure rejected with HTTP 400
 * 11. Incorrect declared RIFF length rejected with HTTP 400
 * 12. Unsupported audio encoding (e.g. IEEE float format tag 3) rejected with HTTP 400
 * 13. Unsupported sample rate (e.g. 96000 Hz) rejected with HTTP 400
 * 14. Unsupported bit depth (e.g. 12-bit) rejected with HTTP 400
 * 15. Excessive audio duration (>30s) rejected with HTTP 400
 * 16. Truncated WAV file rejected with HTTP 400
 * 17. Existing ordinary client SOS spoofing attempts sanitized to manual_entry
 * 18. Existing legitimate ML detection retains critical emergency eligibility
 * 19. Existing drill isolation strictly prevents police dispatch across all routes
 */

require('dotenv').config();
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const CrimeLog = require('./src/models/CrimeLog');
const { createLog, updateDispatchStatus, mockTrigger } = require('./src/controllers/logs.controller');
const { detect } = require('./src/controllers/detect.controller');
const {
  validateInternalServiceConfig,
  generateInternalServiceToken,
  verifyInternalServiceToken,
  INSECURE_DEFAULT_SERVICE_KEYS,
} = require('./src/middleware/internalAuth');
const { validateWavAudioBuffer, validateBase64WavAudio } = require('./src/utils/wavValidator');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/sentinelx_audit';

const results = [];
function record(testNum, title, passed, detail = '') {
  results.push({ testNum, title, passed, detail });
  const mark = passed ? '✓ PASS' : '✗ FAIL';
  console.log(`[Phase 4.2.5 Test ${testNum}] ${mark} - ${title}${detail ? ` (${detail})` : ''}`);
}

function createMockRes() {
  const res = {
    statusCode: 200,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(data) {
      this.body = data;
      return this;
    },
  };
  return res;
}

/**
 * Helper to build custom WAV buffers with specific chunk structures.
 */
function buildCustomWavBuffer({
  audioFormat = 1,
  numChannels = 1,
  sampleRate = 16000,
  bitsPerSample = 16,
  numSamples = 1600, // 0.1s at 16kHz
  riffSizeOverride = null,
  dataSizeOverride = null,
  corruptChunk = false,
  truncateData = false,
}) {
  const bytesPerSample = bitsPerSample / 8;
  const blockAlign = numChannels * bytesPerSample;
  const byteRate = sampleRate * blockAlign;
  const dataSize = dataSizeOverride !== null ? dataSizeOverride : numSamples * blockAlign;

  const actualDataBytes = truncateData ? 100 : dataSize;
  const totalBufferSize = 44 + actualDataBytes;
  const declaredRiffSize = riffSizeOverride !== null ? riffSizeOverride : 36 + dataSize;

  const buf = Buffer.alloc(totalBufferSize);

  // RIFF Header
  buf.write('RIFF', 0);
  buf.writeUInt32LE(declaredRiffSize, 4);
  buf.write('WAVE', 8);

  // fmt subchunk
  if (corruptChunk) {
    buf.write('corrupt', 12);
  } else {
    buf.write('fmt ', 12);
    buf.writeUInt32LE(16, 16); // Subchunk1Size
    buf.writeUInt16LE(audioFormat, 20);
    buf.writeUInt16LE(numChannels, 22);
    buf.writeUInt32LE(sampleRate, 24);
    buf.writeUInt32LE(byteRate, 28);
    buf.writeUInt16LE(blockAlign, 32);
    buf.writeUInt16LE(bitsPerSample, 34);

    // data subchunk
    buf.write('data', 36);
    buf.writeUInt32LE(dataSize, 40);
  }

  return buf;
}

async function runAdversarialSuite() {
  console.log('================================================================');
  console.log(' SENTINELX — PHASE 4.2.5 INTERNAL AUTH & AUDIO VALIDATION SUITE');
  console.log('================================================================\n');

  try {
    await mongoose.connect(MONGODB_URI);
    console.log(`Connected to test MongoDB: ${MONGODB_URI}\n`);

    await CrimeLog.deleteMany({ cameraId: /^CAM-PHASE-4-2-5/ });

    // ── Test 1: Missing INTERNAL_SERVICE_KEY in Production Fails Closed ──────
    {
      let threw = false;
      let errorMsg = '';
      try {
        validateInternalServiceConfig(null, 'production');
      } catch (err) {
        threw = true;
        errorMsg = err.message;
      }
      record(
        1,
        'Missing INTERNAL_SERVICE_KEY in production throws fatal error',
        threw && errorMsg.includes('requires INTERNAL_SERVICE_KEY'),
        `Threw: ${threw}, Error: "${errorMsg}"`
      );
    }

    // ── Test 2: Weak INTERNAL_SERVICE_KEY (<32 chars) in Production Fails Closed ──
    {
      let threw = false;
      let errorMsg = '';
      try {
        validateInternalServiceConfig('short_weak_key_16_bytes', 'production');
      } catch (err) {
        threw = true;
        errorMsg = err.message;
      }
      record(
        2,
        'Weak INTERNAL_SERVICE_KEY (<32 chars) in production throws fatal error',
        threw && errorMsg.includes('minimum 32 characters'),
        `Threw: ${threw}, Error: "${errorMsg}"`
      );
    }

    // ── Test 3: Insecure Default Secret in Production Fails Closed ───────────
    {
      let threw = false;
      let errorMsg = '';
      try {
        validateInternalServiceConfig('sentinelx_internal_audio_token_secure', 'production');
      } catch (err) {
        threw = true;
        errorMsg = err.message;
      }
      record(
        3,
        'Insecure default secret in production throws fatal error',
        threw && errorMsg.includes('Insecure default INTERNAL_SERVICE_KEY'),
        `Threw: ${threw}, Error: "${errorMsg}"`
      );
    }

    // ── Test 4: Plain Marker Header Cannot Authenticate Request ─────────────
    {
      const req = {
        headers: {
          'x-sentinelx-internal-source': 'server_audio_verifier', // Plain marker header
        },
        body: {
          threatClass: 'Acoustic Distress: HELP, HELP',
          confidence: 0.99,
          detectionSource: 'acoustic_sos',
          cameraId: 'CAM-PHASE-4-2-5-04',
        },
      };
      const res = createMockRes();
      await createLog(req, res);
      const doc = await CrimeLog.findById(res.body?.data?._id);

      const passed =
        res.statusCode === 201 &&
        doc?.detectionSource === 'manual_entry' &&
        doc?.severity === 'low' &&
        CrimeLog.isEmergencyEligible(doc) === false;

      record(
        4,
        'Plain marker header (x-sentinelx-internal-source) cannot authenticate request',
        passed,
        `PersistedSource: ${doc?.detectionSource}, Severity: ${doc?.severity}, Eligible: ${CrimeLog.isEmergencyEligible(doc)}`
      );
    }

    // ── Test 5: Client Cannot Inject req.isServerVerifiedAudio ───────────────
    {
      const req = {
        isServerVerifiedAudio: true, // Untrusted client trying to inject property
        body: {
          isServerVerifiedAudio: true,
          threatClass: 'Acoustic Distress: HELP, HELP',
          confidence: 0.95,
          detectionSource: 'acoustic_sos',
          cameraId: 'CAM-PHASE-4-2-5-05',
        },
      };
      const res = createMockRes();
      await createLog(req, res);
      const doc = await CrimeLog.findById(res.body?.data?._id);

      const passed =
        res.statusCode === 201 &&
        doc?.detectionSource === 'manual_entry' &&
        doc?.severity === 'low' &&
        CrimeLog.isEmergencyEligible(doc) === false;

      record(
        5,
        'Client cannot inject isServerVerifiedAudio in body or request object',
        passed,
        `PersistedSource: ${doc?.detectionSource}, Severity: ${doc?.severity}, Eligible: ${CrimeLog.isEmergencyEligible(doc)}`
      );
    }

    // ── Test 6: Forged Internal Provenance Token Rejected ────────────────────
    {
      const forgedToken = 'v1.sentinelx-audio-verifier.' + Date.now() + '.random-nonce.deadbeefcafebabe0123456789';
      const req = {
        headers: {
          'x-sentinelx-service-auth': forgedToken,
        },
        body: {
          threatClass: 'Acoustic Distress: HELP, HELP',
          confidence: 0.95,
          detectionSource: 'acoustic_sos',
          cameraId: 'CAM-PHASE-4-2-5-06',
        },
      };
      const res = createMockRes();
      await createLog(req, res);
      const doc = await CrimeLog.findById(res.body?.data?._id);

      const passed =
        res.statusCode === 201 &&
        doc?.detectionSource === 'manual_entry' &&
        doc?.severity === 'low' &&
        CrimeLog.isEmergencyEligible(doc) === false;

      record(
        6,
        'Forged internal provenance token rejected by cryptographic signature check',
        passed,
        `PersistedSource: ${doc?.detectionSource}, Severity: ${doc?.severity}, Eligible: ${CrimeLog.isEmergencyEligible(doc)}`
      );
    }

    // ── Test 7: Expired Internal Provenance Request (>60s) Rejected ─────────
    {
      const key = 'sentinelx_internal_dev_test_key_32_chars_min';
      const expiredTimestamp = Date.now() - 120000; // 2 minutes in the past
      const nonce = crypto.randomUUID();
      const payload = `sentinelx-audio-verifier:${expiredTimestamp}:${nonce}`;
      const sig = crypto.createHmac('sha256', key).update(payload).digest('hex');
      const expiredToken = `v1.sentinelx-audio-verifier.${expiredTimestamp}.${nonce}.${sig}`;

      const verification = verifyInternalServiceToken(expiredToken, null, key);

      record(
        7,
        'Expired internal token (>60s in the past) rejected by timestamp freshness check',
        verification.valid === false && verification.error?.includes('clock skew exceeded 60 seconds'),
        `Valid: ${verification.valid}, Error: "${verification.error}"`
      );
    }

    // ── Test 8: Replay Attack of Previously Authenticated Token Blocked ──────
    {
      const validToken = generateInternalServiceToken('sentinelx-internal');

      // First verification: Must succeed
      const firstCheck = verifyInternalServiceToken(validToken);

      // Second verification (Replay of identical nonce): Must fail
      const secondCheck = verifyInternalServiceToken(validToken);

      const passed =
        firstCheck.valid === true &&
        secondCheck.valid === false &&
        secondCheck.error?.includes('Replay attack detected');

      record(
        8,
        'Replay attack of previously authenticated token blocked by nonce cache',
        passed,
        `FirstCheck: ${firstCheck.valid}, ReplayCheck: ${secondCheck.valid} ("${secondCheck.error}")`
      );
    }

    // ── Test 9: Valid Authenticated Internal Request Succeeds ────────────────
    {
      const token = generateInternalServiceToken('sentinelx-internal');
      const check = verifyInternalServiceToken(token, 'sentinelx-internal');

      record(
        9,
        'Valid internal service token verifies cryptographic HMAC and timestamp',
        check.valid === true && check.serviceId === 'sentinelx-internal',
        `Valid: ${check.valid}, ServiceId: ${check.serviceId}`
      );
    }

    // ── Test 10: Invalid WAV Chunk Structure Rejected ────────────────────────
    {
      const corruptBuf = buildCustomWavBuffer({ corruptChunk: true });
      const req = {
        body: {
          cameraId: 'CAM-PHASE-4-2-5-10',
          audioData: corruptBuf.toString('base64'),
        },
      };
      const res = createMockRes();
      await detect(req, res);

      const passed =
        res.statusCode === 400 &&
        res.body?.success === false &&
        res.body?.error?.includes('Malformed WAV');

      record(
        10,
        'Invalid WAV chunk structure rejected with HTTP 400 Bad Request',
        passed,
        `HTTP ${res.statusCode}: "${res.body?.error}"`
      );
    }

    // ── Test 11: Incorrect Declared RIFF Length Rejected ─────────────────────
    {
      // Declares RIFF size of 1,000,000 bytes on a 100-byte buffer
      const badRiffBuf = buildCustomWavBuffer({ riffSizeOverride: 1000000 });
      const req = {
        body: {
          cameraId: 'CAM-PHASE-4-2-5-11',
          audioData: badRiffBuf.toString('base64'),
        },
      };
      const res = createMockRes();
      await detect(req, res);

      const passed =
        res.statusCode === 400 &&
        res.body?.success === false &&
        res.body?.error?.includes('Truncated WAV file: declared RIFF size');

      record(
        11,
        'Incorrect declared RIFF length rejected with HTTP 400 Bad Request',
        passed,
        `HTTP ${res.statusCode}: "${res.body?.error}"`
      );
    }

    // ── Test 12: Unsupported Audio Encoding (IEEE Float Tag 3) Rejected ──────
    {
      const floatWav = buildCustomWavBuffer({ audioFormat: 3 }); // 3 = IEEE Float
      const req = {
        body: {
          cameraId: 'CAM-PHASE-4-2-5-12',
          audioData: floatWav.toString('base64'),
        },
      };
      const res = createMockRes();
      await detect(req, res);

      const passed =
        res.statusCode === 400 &&
        res.body?.success === false &&
        res.body?.error?.includes('Unsupported audio encoding');

      record(
        12,
        'Unsupported audio encoding (IEEE Float tag 3) rejected with HTTP 400',
        passed,
        `HTTP ${res.statusCode}: "${res.body?.error}"`
      );
    }

    // ── Test 13: Unsupported Sample Rate (96000 Hz) Rejected ─────────────────
    {
      const highSampleWav = buildCustomWavBuffer({ sampleRate: 96000 });
      const req = {
        body: {
          cameraId: 'CAM-PHASE-4-2-5-13',
          audioData: highSampleWav.toString('base64'),
        },
      };
      const res = createMockRes();
      await detect(req, res);

      const passed =
        res.statusCode === 400 &&
        res.body?.success === false &&
        res.body?.error?.includes('Unsupported sample rate: 96000 Hz');

      record(
        13,
        'Unsupported sample rate (96000 Hz) rejected with HTTP 400 Bad Request',
        passed,
        `HTTP ${res.statusCode}: "${res.body?.error}"`
      );
    }

    // ── Test 14: Unsupported Bit Depth (12-bit) Rejected ─────────────────────
    {
      const badBitDepthWav = buildCustomWavBuffer({ bitsPerSample: 12 });
      const req = {
        body: {
          cameraId: 'CAM-PHASE-4-2-5-14',
          audioData: badBitDepthWav.toString('base64'),
        },
      };
      const res = createMockRes();
      await detect(req, res);

      const passed =
        res.statusCode === 400 &&
        res.body?.success === false &&
        (res.body?.error?.includes('Unsupported bit depth') || res.body?.error?.includes('blockAlign'));

      record(
        14,
        'Unsupported bit depth (12-bit) rejected with HTTP 400 Bad Request',
        passed,
        `HTTP ${res.statusCode}: "${res.body?.error}"`
      );
    }

    // ── Test 15: Excessive Audio Duration (>30s) Rejected ───────────────────
    {
      // 35 seconds of 16kHz 16-bit mono = 35 * 32000 = 1,120,000 bytes
      const excessiveWav = buildCustomWavBuffer({
        numSamples: 35 * 16000, // 35 seconds
      });
      const req = {
        body: {
          cameraId: 'CAM-PHASE-4-2-5-15',
          audioData: excessiveWav.toString('base64'),
        },
      };
      const res = createMockRes();
      await detect(req, res);

      const passed =
        res.statusCode === 400 &&
        res.body?.success === false &&
        res.body?.error?.includes('exceeds maximum permitted limit of 30 seconds');

      record(
        15,
        'Excessive audio duration (>30s) rejected with HTTP 400 Bad Request',
        passed,
        `HTTP ${res.statusCode}: "${res.body?.error}"`
      );
    }

    // ── Test 16: Truncated WAV File (Data Chunk Truncation) Rejected ─────────
    {
      const truncatedWav = buildCustomWavBuffer({
        riffSizeOverride: 36 + 100, // Matches buffer length (144 bytes) so RIFF size check passes
        dataSizeOverride: 64000,    // Declares 64,000 bytes in data subchunk
        truncateData: true,         // Only supplies 100 bytes of actual data
      });
      const req = {
        body: {
          cameraId: 'CAM-PHASE-4-2-5-16',
          audioData: truncatedWav.toString('base64'),
        },
      };
      const res = createMockRes();
      await detect(req, res);

      const passed =
        res.statusCode === 400 &&
        res.body?.success === false &&
        res.body?.error?.includes('Truncated WAV file: declared "data" chunk size');

      record(
        16,
        'Truncated WAV file (data chunk length discrepancy) rejected with HTTP 400',
        passed,
        `HTTP ${res.statusCode}: "${res.body?.error}"`
      );
    }

    // ── Test 17: Existing Ordinary Client SOS Spoofing Attempt Sanitized ────
    {
      const req = {
        body: {
          threatClass: 'Acoustic Distress: HELP, HELP',
          audioTranscript: 'CRITICAL DISTRESS: HELP! HELP!',
          audioDecibels: 95.0,
          detectionSource: 'acoustic_sos',
          confidence: 0.99,
          severity: 'critical',
          cameraId: 'CAM-PHASE-4-2-5-17',
        },
      };
      const res = createMockRes();
      await createLog(req, res);
      const doc = await CrimeLog.findById(res.body?.data?._id);

      const passed =
        res.statusCode === 201 &&
        doc?.detectionSource === 'manual_entry' &&
        doc?.detectionStatus === 'low_confidence_review' &&
        doc?.severity === 'low' &&
        CrimeLog.isEmergencyEligible(doc) === false;

      record(
        17,
        'Ordinary client SOS spoofing attempt sanitized to manual_entry / low severity',
        passed,
        `Source: ${doc?.detectionSource}, Severity: ${doc?.severity}, Eligible: ${CrimeLog.isEmergencyEligible(doc)}`
      );
    }

    // ── Test 18: Existing Legitimate ML Detection Retains Critical Eligibility
    {
      const mlDoc = await CrimeLog.create({
        threatClass: 'Explosion',
        confidence: 0.94,
        detectionStatus: 'anomaly_detected',
        detectionSource: 'ml_real',
        cameraId: 'CAM-PHASE-4-2-5-18',
        frameTimestamp: new Date(),
      });
      const isEligible = CrimeLog.isEmergencyEligible(mlDoc);

      const passed =
        mlDoc.severity === 'critical' &&
        isEligible === true;

      record(
        18,
        'Legitimate ML anomaly (confidence >= 0.85) retains critical emergency eligibility',
        passed,
        `Severity: ${mlDoc.severity}, EmergencyEligible: ${isEligible}`
      );
    }

    // ── Test 19: Existing Drill Simulation Isolation Enforced Across All Routes
    {
      const drillDoc = await CrimeLog.create({
        threatClass: 'Fighting',
        confidence: 0.95,
        detectionStatus: 'anomaly_detected',
        detectionSource: 'drill_simulation',
        cameraId: 'CAM-PHASE-4-2-5-19',
        frameTimestamp: new Date(),
      });

      // Route A: PATCH /api/logs/:id/dispatch
      const reqPatch = {
        params: { id: drillDoc._id.toString() },
        body: { dispatchStatus: 'assigned_police' },
      };
      const resPatch = createMockRes();
      await updateDispatchStatus(reqPatch, resPatch);

      // Route B: POST /api/logs with drill_simulation + assigned_police
      const reqPost = {
        body: {
          threatClass: 'Explosion',
          confidence: 0.95,
          detectionSource: 'drill_simulation',
          dispatchStatus: 'assigned_police',
          cameraId: 'CAM-PHASE-4-2-5-19',
        },
      };
      const resPost = createMockRes();
      await createLog(reqPost, resPost);
      const createdDrill = await CrimeLog.findById(resPost.body?.data?._id);

      // Route C: POST /api/logs/trigger with assigned_police
      const reqTrigger = {
        body: {
          threatClass: 'Crowd Panic',
          dispatchStatus: 'assigned_police',
          cameraId: 'CAM-PHASE-4-2-5-19',
        },
      };
      const resTrigger = createMockRes();
      await mockTrigger(reqTrigger, resTrigger);
      const triggeredDrill = await CrimeLog.findById(resTrigger.body?.data?._id);

      const isEligible = CrimeLog.isEmergencyEligible(drillDoc);

      const passed =
        resPatch.statusCode === 400 &&
        createdDrill?.dispatchStatus === 'unassigned' &&
        triggeredDrill?.dispatchStatus === 'unassigned' &&
        isEligible === false;

      record(
        19,
        'Drill simulation isolation strictly prevents police dispatch across all routes',
        passed,
        `PatchStatus: HTTP ${resPatch.statusCode}, PostStatus: ${createdDrill?.dispatchStatus}, TriggerStatus: ${triggeredDrill?.dispatchStatus}, Eligible: ${isEligible}`
      );
    }

    // ── Summary ─────────────────────────────────────────────────────────────
    const total = results.length;
    const passedCount = results.filter((r) => r.passed).length;
    const failedCount = total - passedCount;

    console.log('\n================================================================');
    console.log(`TOTAL PHASE 4.2.5 ADVERSARIAL TESTS: ${total} | PASSED: ${passedCount} | FAILED: ${failedCount}`);
    console.log('================================================================');

    if (failedCount > 0) {
      process.exit(1);
    }
  } catch (err) {
    console.error('[Phase 4.2.5] Unexpected error running suite:', err);
    process.exit(1);
  } finally {
    await mongoose.disconnect();
  }
}

runAdversarialSuite();
