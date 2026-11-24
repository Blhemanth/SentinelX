/**
 * SentinelX — Phase 4.2.4 Adversarial Security Test Suite
 * 
 * 15 Distinct Adversarial Security Scenarios:
 * 1.  Forged Acoustic SOS source via POST /api/logs
 * 2.  Forged HELP transcript via POST /api/logs
 * 3.  Forged high decibel value via POST /api/logs
 * 4.  Forged source + transcript + decibel combination
 * 5.  Missing audio file/payload in audio validation
 * 6.  Invalid audio file (missing RIFF/WAVE header)
 * 7.  Oversized audio upload (>10MB)
 * 8.  Malformed audio (corrupted base64)
 * 9.  Unauthorized audio upload (missing JWT / insufficient role)
 * 10. Ordinary REST attempt to create ml_real via POST /api/logs
 * 11. Ordinary REST attempt to create critical emergency via POST /api/logs
 * 12. Drill dispatch through every available backend route (Routes A, B, C)
 * 13. Attempted dispatch of manual-entry records & invalid state transitions
 * 14. Existing legitimate verified ML emergency retains critical eligibility
 * 15. Existing legitimate verified Acoustic SOS via trusted server provenance
 */

require('dotenv').config();
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const CrimeLog = require('./src/models/CrimeLog');
const { createLog, updateDispatchStatus, mockTrigger } = require('./src/controllers/logs.controller');
const { detect } = require('./src/controllers/detect.controller');
const { generateInternalServiceToken } = require('./src/middleware/internalAuth');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/sentinelx_audit';
const JWT_SECRET = process.env.JWT_SECRET || 'sentinelx_jwt_secret_audit';

const results = [];
function record(testNum, title, passed, detail = '') {
  results.push({ testNum, title, passed, detail });
  const mark = passed ? '✓ PASS' : '✗ FAIL';
  console.log(`[Phase 4.2.4 Test ${testNum}] ${mark} - ${title}${detail ? ` (${detail})` : ''}`);
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

// Generate valid minimal WAV header (44 bytes standard PCM, 16kHz, mono, 16-bit)
function createValidWavBuffer(numSamples = 160) {
  const buffer = Buffer.alloc(44 + numSamples * 2);
  // RIFF chunk descriptor
  buffer.write('RIFF', 0);
  buffer.writeUInt32LE(36 + numSamples * 2, 4);
  buffer.write('WAVE', 8);
  // fmt sub-chunk
  buffer.write('fmt ', 12);
  buffer.writeUInt32LE(16, 16); // Subchunk1Size (16 for PCM)
  buffer.writeUInt16LE(1, 20);  // AudioFormat (1 = PCM)
  buffer.writeUInt16LE(1, 22);  // NumChannels (1 = Mono)
  buffer.writeUInt32LE(16000, 24); // SampleRate (16000 Hz)
  buffer.writeUInt32LE(32000, 28); // ByteRate (16000 * 1 * 2)
  buffer.writeUInt16LE(2, 32);  // BlockAlign
  buffer.writeUInt16LE(16, 34); // BitsPerSample
  // data sub-chunk
  buffer.write('data', 36);
  buffer.writeUInt32LE(numSamples * 2, 40);
  return buffer;
}

async function runAdversarialSuite() {
  console.log('================================================================');
  console.log(' SENTINELX — PHASE 4.2.4 ADVERSARIAL SECURITY TEST SUITE');
  console.log('================================================================\n');

  try {
    await mongoose.connect(MONGODB_URI);
    console.log(`Connected to test MongoDB: ${MONGODB_URI}\n`);

    await CrimeLog.deleteMany({ cameraId: /^CAM-ADV-/ });

    // ── Test 1: Forged Acoustic SOS Source via POST /api/logs ───────────────
    {
      const req = {
        body: {
          threatClass: 'Explosion',
          confidence: 0.95,
          detectionSource: 'acoustic_sos',
          cameraId: 'CAM-ADV-01',
        },
      };
      const res = createMockRes();
      await createLog(req, res);
      const doc = await CrimeLog.findById(res.body?.data?._id);

      const passed =
        res.statusCode === 201 &&
        res.body?.data?.detectionSource === 'manual_entry' &&
        doc?.detectionSource === 'manual_entry' &&
        doc?.severity === 'low' &&
        CrimeLog.isEmergencyEligible(doc) === false;

      record(
        1,
        'Forged Acoustic SOS source is sanitized to manual_entry with low severity',
        passed,
        `Source: ${doc?.detectionSource}, Severity: ${doc?.severity}, Eligible: ${CrimeLog.isEmergencyEligible(doc)}`
      );
    }

    // ── Test 2: Forged HELP Transcript via POST /api/logs ───────────────────
    {
      const req = {
        body: {
          threatClass: 'Explosion',
          confidence: 0.95,
          audioTranscript: 'CRITICAL DISTRESS: HELP! HELP! EMERGENCY!',
          cameraId: 'CAM-ADV-02',
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
        2,
        'Forged HELP transcript cannot independently escalate incident to emergency',
        passed,
        `Status: ${doc?.detectionStatus}, Severity: ${doc?.severity}, Eligible: ${CrimeLog.isEmergencyEligible(doc)}`
      );
    }

    // ── Test 3: Forged High Decibel Value via POST /api/logs ─────────────────
    {
      const req = {
        body: {
          threatClass: 'Fighting',
          confidence: 0.92,
          audioDecibels: 96.5,
          cameraId: 'CAM-ADV-03',
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
        3,
        'Forged high decibel value (96.5 dB) cannot authorize emergency eligibility',
        passed,
        `Decibels: ${doc?.audioDecibels}, Severity: ${doc?.severity}, Eligible: ${CrimeLog.isEmergencyEligible(doc)}`
      );
    }

    // ── Test 4: Forged Source + Transcript + Decibel Combination ────────────
    {
      const req = {
        body: {
          threatClass: 'Acoustic Distress: HELP, HELP',
          confidence: 0.99,
          severity: 'critical',
          detectionSource: 'acoustic_sos',
          detectionStatus: 'anomaly_detected',
          audioTranscript: 'CRITICAL DISTRESS: "HELP! HELP! EMERGENCY AT SECTOR GATE"',
          audioDecibels: 92.4,
          cameraId: 'CAM-ADV-04',
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
        4,
        'Forged source + transcript + decibels combination fully sanitized to manual_entry',
        passed,
        `Source: ${doc?.detectionSource}, Severity: ${doc?.severity}, Eligible: ${CrimeLog.isEmergencyEligible(doc)}`
      );
    }

    // ── Test 5: Missing Audio File / Empty Audio Payload ────────────────────
    {
      const req = {
        body: {
          cameraId: 'CAM-ADV-05',
          audioData: '   ', // Empty/whitespace audio string
        },
      };
      const res = createMockRes();
      await detect(req, res);

      const passed =
        res.statusCode === 400 &&
        res.body?.success === false &&
        res.body?.error?.includes('empty');

      record(
        5,
        'Missing / empty audio payload on audio ingestion rejected with HTTP 400',
        passed,
        `HTTP ${res.statusCode}: "${res.body?.error}"`
      );
    }

    // ── Test 6: Invalid Audio File (Missing RIFF/WAVE Header) ────────────────
    {
      const fakeWav = Buffer.from('FAKE-NON-WAV-PAYLOAD-WITH-NO-RIFF-HEADER-CORRUPTED');
      const req = {
        body: {
          cameraId: 'CAM-ADV-06',
          audioData: fakeWav.toString('base64'),
        },
      };
      const res = createMockRes();
      await detect(req, res);

      const passed =
        res.statusCode === 400 &&
        res.body?.success === false &&
        res.body?.error?.includes('Invalid audio format');

      record(
        6,
        'Invalid audio signature (missing RIFF/WAVE magic bytes) rejected with HTTP 400',
        passed,
        `HTTP ${res.statusCode}: "${res.body?.error}"`
      );
    }

    // ── Test 7: Oversized Audio Upload (>10MB) ──────────────────────────────
    {
      const oversizedAudio = Buffer.alloc(11 * 1024 * 1024, 0); // 11 MB
      // Prepend valid RIFF/WAVE header so it passes signature check and fails size check
      oversizedAudio.write('RIFF', 0);
      oversizedAudio.write('WAVE', 8);

      const req = {
        body: {
          cameraId: 'CAM-ADV-07',
          audioData: oversizedAudio.toString('base64'),
        },
      };
      const res = createMockRes();
      await detect(req, res);

      const passed =
        res.statusCode === 413 &&
        res.body?.success === false &&
        res.body?.error?.includes('exceeds maximum permitted size');

      record(
        7,
        'Oversized audio upload (>10 MB) rejected with HTTP 413 Payload Too Large',
        passed,
        `HTTP ${res.statusCode}: "${res.body?.error}"`
      );
    }

    // ── Test 8: Malformed Audio (Corrupted Base64) ───────────────────────────
    {
      const req = {
        body: {
          cameraId: 'CAM-ADV-08',
          audioData: '@@@@!CorruptedBase64InvalidCharacters#$$$%%%^^^&&&',
        },
      };
      const res = createMockRes();
      await detect(req, res);

      const passed =
        res.statusCode === 400 &&
        res.body?.success === false &&
        res.body?.error?.includes('invalid base64 encoding');

      record(
        8,
        'Malformed audio string with invalid base64 characters rejected with HTTP 400',
        passed,
        `HTTP ${res.statusCode}: "${res.body?.error}"`
      );
    }

    // ── Test 9: Unauthorized Audio Upload ───────────────────────────────────
    {
      // Test 9a: Missing JWT token (simulating auth middleware rejection)
      const { authenticate } = require('./src/middleware/auth');
      const { requireMinRole } = require('./src/middleware/rbac');

      const reqNoAuth = { headers: {} };
      const resNoAuth = createMockRes();
      let nextCalledNoAuth = false;
      authenticate(reqNoAuth, resNoAuth, () => { nextCalledNoAuth = true; });

      // Test 9b: Insufficient role ('viewer' attempting analyst-only audio detection)
      const viewerToken = jwt.sign(
        { userId: 'adv-viewer-01', role: 'viewer', email: 'viewer@sentinelx.local' },
        JWT_SECRET,
        { expiresIn: '1h' }
      );
      const reqViewer = {
        user: { userId: 'adv-viewer-01', role: 'viewer' },
      };
      const resViewer = createMockRes();
      let nextCalledViewer = false;
      requireMinRole('analyst')(reqViewer, resViewer, () => { nextCalledViewer = true; });

      const passed =
        resNoAuth.statusCode === 401 &&
        !nextCalledNoAuth &&
        resViewer.statusCode === 403 &&
        !nextCalledViewer;

      record(
        9,
        'Unauthorized audio upload blocked: 401 for missing JWT, 403 for viewer role',
        passed,
        `NoAuth: HTTP ${resNoAuth.statusCode}, ViewerRole: HTTP ${resViewer.statusCode}`
      );
    }

    // ── Test 10: Ordinary REST Attempt to Create ml_real ─────────────────────
    {
      const req = {
        body: {
          threatClass: 'Explosion',
          confidence: 0.98,
          detectionSource: 'ml_real',
          detectionStatus: 'anomaly_detected',
          cameraId: 'CAM-ADV-10',
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
        10,
        'Ordinary REST attempt to create ml_real demoted to manual_entry (low severity)',
        passed,
        `Source: ${doc?.detectionSource}, Severity: ${doc?.severity}, Eligible: ${CrimeLog.isEmergencyEligible(doc)}`
      );
    }

    // ── Test 11: Ordinary REST Attempt to Create Critical Emergency ─────────
    {
      const req = {
        body: {
          threatClass: 'Gunshot',
          confidence: 0.99,
          severity: 'critical',
          isEmergencyEligible: true,
          cameraId: 'CAM-ADV-11',
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
        11,
        'Ordinary REST attempt to create critical emergency stripped to low severity',
        passed,
        `ClientSeverityStripped: ${doc?.severity}, EmergencyEligible: ${CrimeLog.isEmergencyEligible(doc)}`
      );
    }

    // ── Test 12: Drill Dispatch Blocked Across Every Available Backend Route ─
    {
      // 12a: Route A — PATCH /api/logs/:id/dispatch on drill record
      const drillDoc = await CrimeLog.create({
        threatClass: 'Fighting',
        confidence: 0.95,
        detectionStatus: 'anomaly_detected',
        detectionSource: 'drill_simulation',
        cameraId: 'CAM-ADV-12',
        frameTimestamp: new Date(),
      });

      const reqPatch = {
        params: { id: drillDoc._id.toString() },
        body: { dispatchStatus: 'assigned_police', assignedTo: 'Officer 42' },
      };
      const resPatch = createMockRes();
      await updateDispatchStatus(reqPatch, resPatch);

      // 12b: Route B — POST /api/logs with drill_simulation + assigned_police
      const reqPost = {
        body: {
          threatClass: 'Explosion',
          confidence: 0.91,
          detectionSource: 'drill_simulation',
          dispatchStatus: 'assigned_police',
          cameraId: 'CAM-ADV-12',
        },
      };
      const resPost = createMockRes();
      await createLog(reqPost, resPost);
      const createdDrill = await CrimeLog.findById(resPost.body?.data?._id);

      // 12c: Route C — POST /api/logs/trigger with assigned_police
      const reqTrigger = {
        body: {
          threatClass: 'Acoustic Distress: HELP, HELP',
          dispatchStatus: 'assigned_police',
          cameraId: 'CAM-ADV-12',
        },
      };
      const resTrigger = createMockRes();
      await mockTrigger(reqTrigger, resTrigger);
      const triggeredDrill = await CrimeLog.findById(resTrigger.body?.data?._id);

      const passed =
        resPatch.statusCode === 400 &&
        resPatch.body?.error?.includes('Drill simulations are training exercises') &&
        createdDrill?.dispatchStatus === 'unassigned' &&
        triggeredDrill?.dispatchStatus === 'unassigned';

      record(
        12,
        'Drill dispatch blocked across all routes: PATCH rejected 400, POST clamped unassigned',
        passed,
        `RouteA: HTTP ${resPatch.statusCode}, RouteB: ${createdDrill?.dispatchStatus}, RouteC: ${triggeredDrill?.dispatchStatus}`
      );
    }

    // ── Test 13: Attempted Dispatch of Manual-Entry Records & Invalid States ──
    {
      // 13a: Manual entries cannot be automatically emergency eligible
      const manualDoc = await CrimeLog.create({
        threatClass: 'Accident',
        confidence: 0.99,
        detectionStatus: 'anomaly_detected',
        detectionSource: 'manual_entry',
        cameraId: 'CAM-ADV-13',
        frameTimestamp: new Date(),
      });
      const manualAutoEligible = CrimeLog.isEmergencyEligible(manualDoc);

      // 13b: Manual entry created via POST /api/logs cannot be pre-assigned on creation
      const reqCreateManual = {
        body: {
          threatClass: 'Gunshot',
          confidence: 0.88,
          detectionSource: 'manual_entry',
          dispatchStatus: 'assigned_police',
          cameraId: 'CAM-ADV-13',
        },
      };
      const resCreateManual = createMockRes();
      await createLog(reqCreateManual, resCreateManual);
      const createdManual = await CrimeLog.findById(resCreateManual.body?.data?._id);

      // 13c: Invalid dispatchStatus transition rejected with 400
      const reqInvalidStatus = {
        params: { id: manualDoc._id.toString() },
        body: { dispatchStatus: 'invalid_dispatch_state_xyz' },
      };
      const resInvalidStatus = createMockRes();
      await updateDispatchStatus(reqInvalidStatus, resInvalidStatus);

      // 13d: Cannot re-open resolved incident to police dispatch
      await CrimeLog.findByIdAndUpdate(manualDoc._id, { dispatchStatus: 'resolved' });
      const reqReopen = {
        params: { id: manualDoc._id.toString() },
        body: { dispatchStatus: 'assigned_police' },
      };
      const resReopen = createMockRes();
      await updateDispatchStatus(reqReopen, resReopen);

      const passed =
        manualAutoEligible === false &&
        createdManual?.dispatchStatus === 'unassigned' &&
        resInvalidStatus.statusCode === 400 &&
        resReopen.statusCode === 400;

      record(
        13,
        'Manual-entry records: not auto-eligible, creation clamped, invalid/resolved states rejected 400',
        passed,
        `AutoEligible: ${manualAutoEligible}, Clamped: ${createdManual?.dispatchStatus}, InvalidStatus: HTTP ${resInvalidStatus.statusCode}, ReopenResolved: HTTP ${resReopen.statusCode}`
      );
    }

    // ── Test 14: Legitimate Verified ML Emergency Retains Eligibility ────────
    {
      const genuineMlDoc = await CrimeLog.create({
        threatClass: 'Explosion',
        confidence: 0.92,
        detectionStatus: 'anomaly_detected',
        detectionSource: 'ml_real',
        cameraId: 'CAM-ADV-14',
        frameTimestamp: new Date(),
      });
      const isEligible = CrimeLog.isEmergencyEligible(genuineMlDoc);

      const passed =
        genuineMlDoc.severity === 'critical' &&
        isEligible === true;

      record(
        14,
        'Legitimate verified ML anomaly (confidence >= 0.85) retains critical emergency eligibility',
        passed,
        `Severity: ${genuineMlDoc.severity}, EmergencyEligible: ${isEligible}`
      );
    }

    // ── Test 15: Legitimate Verified Acoustic SOS via Trusted Provenance ─────
    {
      // Authenticated with cryptographic internal service token
      const reqVerifiedAcoustic = {
        headers: {
          'x-sentinelx-service-auth': generateInternalServiceToken('sentinelx-audio-verifier'),
        },
        body: {
          threatClass: 'Acoustic Distress: HELP, HELP',
          confidence: 0.985,
          detectionSource: 'acoustic_sos',
          detectionStatus: 'anomaly_detected',
          audioTranscript: 'SERVER_VERIFIED_DISTRESS: "HELP! HELP!"',
          audioDecibels: 88.5,
          cameraId: 'CAM-ADV-15',
        },
      };
      const resVerified = createMockRes();
      await createLog(reqVerifiedAcoustic, resVerified);
      const verifiedDoc = await CrimeLog.findById(resVerified.body?.data?._id);
      const isEligible = CrimeLog.isEmergencyEligible(verifiedDoc);

      const passed =
        resVerified.statusCode === 201 &&
        verifiedDoc?.detectionSource === 'acoustic_sos' &&
        verifiedDoc?.severity === 'critical' &&
        isEligible === true;

      record(
        15,
        'Acoustic SOS with trusted server audio provenance retains critical emergency eligibility',
        passed,
        `Source: ${verifiedDoc?.detectionSource}, Severity: ${verifiedDoc?.severity}, EmergencyEligible: ${isEligible}`
      );
    }

    // ── Summary ─────────────────────────────────────────────────────────────
    const total = results.length;
    const passedCount = results.filter((r) => r.passed).length;
    const failedCount = total - passedCount;

    console.log('\n================================================================');
    console.log(`TOTAL PHASE 4.2.4 ADVERSARIAL TESTS: ${total} | PASSED: ${passedCount} | FAILED: ${failedCount}`);
    console.log('================================================================');

    if (failedCount > 0) {
      process.exit(1);
    }
  } catch (err) {
    console.error('[Phase 4.2.4] Unexpected error running suite:', err);
    process.exit(1);
  } finally {
    await mongoose.disconnect();
  }
}

runAdversarialSuite();
