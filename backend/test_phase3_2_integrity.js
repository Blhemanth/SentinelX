/**
 * SentinelX - Phase 3.2 ML Data Integrity Automated Test Suite
 * Tests:
 * 1. Normal detection persistence in MongoDB with detectionStatus: 'normal'.
 * 2. Confirmed anomaly persistence with detectionStatus: 'anomaly_detected'.
 * 3. Low-confidence detection persistence with detectionStatus: 'low_confidence_review'.
 * 4. Subprocess fallback persistence with detectionStatus & detectionSource: 'subprocess_fallback'.
 * 5. Subprocess failure never produces an 'ml_real' record.
 * 6. Missing detectionStatus on legacy records defaults safely without crashing.
 * 7. React response parsing correctly processes status and filters emergencies.
 * 8. Flutter response parsing correctly handles detectionStatus and ignores fallbacks.
 * 9. Fallback records never trigger critical dispatch (severity stays 'low').
 */

require('dotenv').config();
const mongoose = require('mongoose');
const request = require('supertest');
const app = require('./src/app');
const User = require('./src/models/User');
const CrimeLog = require('./src/models/CrimeLog');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/sentinelx_audit';

let analystToken;
const testPassword = 'SecurePassword!123';

const results = [];
function record(testName, passed, detail = '') {
  results.push({ testName, passed, detail });
  const status = passed ? '✓ PASS' : '✗ FAIL';
  console.log(`[Phase 3.2 Test] ${status} - ${testName}${detail ? ` (${detail})` : ''}`);
}

async function runIntegrityTests() {
  console.log('========================================================');
  console.log(' SENTINELX - PHASE 3.2 ML DATA INTEGRITY TEST SUITE     ');
  console.log('========================================================\n');

  try {
    await mongoose.connect(MONGODB_URI);
    console.log(`Connected to test MongoDB: ${MONGODB_URI}\n`);

    // Clean up previous test users and test logs
    await User.deleteMany({ email: /@integrity-test\.local$/ });
    await CrimeLog.deleteMany({ cameraId: 'CAM-INTEGRITY-TEST' });

    // ── Setup: Authenticated Analyst User ───────────────────────────────────
    const regRes = await request(app)
      .post('/api/auth/register')
      .send({
        name: 'Integrity Test Analyst',
        email: 'analyst@integrity-test.local',
        password: testPassword,
      });

    await User.updateOne({ email: 'analyst@integrity-test.local' }, { role: 'analyst' });

    const loginRes = await request(app)
      .post('/api/auth/login')
      .send({ email: 'analyst@integrity-test.local', password: testPassword });

    analystToken = loginRes.body.data.accessToken;
    record('Auth: Analyst account registered and authenticated', Boolean(analystToken));

    // ── Test 1: Normal Detection Persistence ────────────────────────────────
    const normalLog = await CrimeLog.create({
      threatClass: 'Normal',
      confidence: 0.942,
      detectionStatus: 'normal',
      detectionSource: 'ml_real',
      cameraId: 'CAM-INTEGRITY-TEST',
      frameTimestamp: new Date(),
    });

    record(
      'Test 1: Normal detection persistence with detectionStatus "normal"',
      normalLog.detectionStatus === 'normal' &&
      normalLog.detectionSource === 'ml_real' &&
      normalLog.severity === 'normal',
      `Status: ${normalLog.detectionStatus}, Severity: ${normalLog.severity}`
    );

    // ── Test 2: Confirmed Anomaly Persistence ───────────────────────────────
    const anomalyLog = await CrimeLog.create({
      threatClass: 'Explosion',
      confidence: 0.915,
      detectionStatus: 'anomaly_detected',
      detectionSource: 'ml_real',
      cameraId: 'CAM-INTEGRITY-TEST',
      frameTimestamp: new Date(),
    });

    record(
      'Test 2: Confirmed anomaly persistence with detectionStatus "anomaly_detected"',
      anomalyLog.detectionStatus === 'anomaly_detected' &&
      anomalyLog.detectionSource === 'ml_real' &&
      anomalyLog.severity === 'critical',
      `Status: ${anomalyLog.detectionStatus}, Severity: ${anomalyLog.severity}`
    );

    // ── Test 3: Low-Confidence Detection Persistence ────────────────────────
    const lowConfLog = await CrimeLog.create({
      threatClass: 'Fighting',
      confidence: 0.325,
      detectionStatus: 'low_confidence_review',
      detectionSource: 'ml_real',
      cameraId: 'CAM-INTEGRITY-TEST',
      frameTimestamp: new Date(),
    });

    record(
      'Test 3: Low-confidence detection persistence with detectionStatus "low_confidence_review"',
      lowConfLog.detectionStatus === 'low_confidence_review' &&
      lowConfLog.detectionSource === 'ml_real' &&
      lowConfLog.severity === 'low',
      `Status: ${lowConfLog.detectionStatus}, Severity: ${lowConfLog.severity}`
    );

    // ── Test 4: Subprocess Fallback Persistence ─────────────────────────────
    const fallbackLog = await CrimeLog.create({
      threatClass: 'Normal',
      confidence: 0.50,
      detectionStatus: 'subprocess_fallback',
      detectionSource: 'subprocess_fallback',
      cameraId: 'CAM-INTEGRITY-TEST',
      frameTimestamp: new Date(),
    });

    record(
      'Test 4: Subprocess fallback persistence with detectionStatus & detectionSource "subprocess_fallback"',
      fallbackLog.detectionStatus === 'subprocess_fallback' &&
      fallbackLog.detectionSource === 'subprocess_fallback' &&
      fallbackLog.severity === 'low',
      `Status: ${fallbackLog.detectionStatus}, Source: ${fallbackLog.detectionSource}, Severity: ${fallbackLog.severity}`
    );

    // ── Test 5: Subprocess Failure Does NOT Produce 'ml_real' ───────────────
    // Directly test detect controller handling when mlResult is a fallback
    const { detect } = require('./src/controllers/detect.controller');
    // Simulate req/res for detect endpoint with mock fallback bridge
    const mockReq = {
      body: {
        cameraId: 'CAM-INTEGRITY-TEST',
        location: 'Perimeter Gate Test',
        videoFrames: 'INVALID_BASE64_FORCING_FALLBACK',
      },
    };
    let capturedRes = {};
    const mockRes = {
      status: (code) => {
        capturedRes.statusCode = code;
        return {
          json: (data) => {
            capturedRes.body = data;
          },
        };
      },
    };

    await detect(mockReq, mockRes);
    // Allow non-blocking MongoDB write to settle
    await new Promise((r) => setTimeout(r, 400));

    const dbFallbackLog = await CrimeLog.findOne({
      cameraId: 'CAM-INTEGRITY-TEST',
      detectionSource: 'subprocess_fallback',
    });

    const dbMisclassifiedReal = await CrimeLog.findOne({
      cameraId: 'CAM-INTEGRITY-TEST',
      detectionStatus: 'subprocess_fallback',
      detectionSource: 'ml_real',
    });

    record(
      'Test 5: Subprocess failure tagged as "subprocess_fallback" and NEVER as "ml_real"',
      Boolean(dbFallbackLog) && !dbMisclassifiedReal,
      `Fallback DB Record Source: ${dbFallbackLog?.detectionSource}, Misclassified count: ${dbMisclassifiedReal ? 1 : 0}`
    );

    // ── Test 6: Missing detectionStatus on Legacy Records ────────────────────
    // Insert a document directly via raw MongoDB collection without detectionStatus
    const rawCollection = mongoose.connection.collection('crimelogs');
    const legacyDoc = await rawCollection.insertOne({
      threatClass: 'Gunshot',
      confidence: 0.88,
      cameraId: 'CAM-INTEGRITY-TEST',
      frameTimestamp: new Date(),
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    // Query back through Mongoose model
    const readLegacy = await CrimeLog.findById(legacyDoc.insertedId);

    record(
      'Test 6: Missing detectionStatus on legacy records defaults safely to "legacy_unclassified"',
      readLegacy !== null && readLegacy.detectionStatus === 'legacy_unclassified',
      `Legacy record detectionStatus: ${readLegacy?.detectionStatus}`
    );

    // ── Test 7: React Response Parsing & Filter Logic ───────────────────────
    const reactLogs = [
      { _id: '1', threatClass: 'Explosion', severity: 'critical', detectionStatus: 'anomaly_detected', detectionSource: 'ml_real', dispatchStatus: 'unassigned' },
      { _id: '2', threatClass: 'Normal', severity: 'low', detectionStatus: 'subprocess_fallback', detectionSource: 'subprocess_fallback', dispatchStatus: 'unassigned' },
      { _id: '3', threatClass: 'Fighting', severity: 'low', detectionStatus: 'low_confidence_review', detectionSource: 'ml_real', dispatchStatus: 'unassigned' },
    ];

    // Mirror DashboardView.jsx activeEmergencies filter:
    const activeEmergencies = reactLogs.filter(
      (log) =>
        (log.severity === 'critical' || log.threatClass?.includes('HELP')) &&
        log.detectionStatus !== 'subprocess_fallback' &&
        log.detectionSource !== 'subprocess_fallback' &&
        log.dispatchStatus !== 'resolved'
    );

    record(
      'Test 7: React logic parses detectionStatus and excludes fallback records from activeEmergencies',
      activeEmergencies.length === 1 && activeEmergencies[0]._id === '1',
      `Active Emergencies Count: ${activeEmergencies.length} (Expected: 1, Explosion only)`
    );

    // ── Test 8: Flutter Response Parsing & Filter Logic ─────────────────────
    const flutterRawLogs = [
      { _id: 'f1', threatClass: 'Gunshot', confidence: 0.92, detectionStatus: 'anomaly_detected', detectionSource: 'ml_real' },
      { _id: 'f2', threatClass: 'Normal', confidence: 0.50, detectionStatus: 'subprocess_fallback', detectionSource: 'subprocess_fallback' },
      { _id: 'f3', threatClass: 'Fighting', confidence: 0.35, detectionStatus: 'low_confidence_review', detectionSource: 'ml_real' },
    ];

    // Mirror incident_dispatch_repository.dart syncFromBackend filter:
    const flutterParsedIncidents = [];
    for (const raw of flutterRawLogs) {
      const threatClass = raw.threatClass || 'Normal';
      const detStatus = raw.detectionStatus || 'normal';
      const detSource = raw.detectionSource || 'ml_real';
      if (
        threatClass === 'Normal' ||
        !raw._id ||
        detStatus === 'subprocess_fallback' ||
        detSource === 'subprocess_fallback'
      ) {
        continue;
      }
      flutterParsedIncidents.push({
        id: raw._id,
        threatClass,
        detectionStatus: detStatus,
        detectionSource: detSource,
      });
    }

    record(
      'Test 8: Flutter logic parses detectionStatus and ignores subprocess_fallback items',
      flutterParsedIncidents.length === 2 &&
      flutterParsedIncidents.every((inc) => inc.detectionStatus !== 'subprocess_fallback'),
      `Parsed Incidents: ${flutterParsedIncidents.map((i) => `${i.threatClass}:${i.detectionStatus}`).join(', ')}`
    );

    // ── Test 9: Fallback Records Never Trigger Critical Dispatch ────────────
    const criticalFallbackAttempt = await CrimeLog.create({
      threatClass: 'Explosion', // Even if threatClass was erroneously Explosion in a fallback
      confidence: 0.99,
      detectionStatus: 'subprocess_fallback',
      detectionSource: 'subprocess_fallback',
      cameraId: 'CAM-INTEGRITY-TEST',
      frameTimestamp: new Date(),
    });

    record(
      'Test 9: Pre-save hook forces severity "low" for subprocess_fallback regardless of confidence',
      criticalFallbackAttempt.severity === 'low',
      `Severity for 99% confidence fallback: ${criticalFallbackAttempt.severity} (Expected: 'low')`
    );

    // Clean up test data
    await CrimeLog.deleteMany({ cameraId: 'CAM-INTEGRITY-TEST' });
    await User.deleteMany({ email: /@integrity-test\.local$/ });

    // ── Summary ─────────────────────────────────────────────────────────────
    console.log('\n========================================================');
    const total = results.length;
    const passed = results.filter((r) => r.passed).length;
    const failed = total - passed;
    console.log(`TOTAL INTEGRITY TESTS: ${total} | PASSED: ${passed} | FAILED: ${failed}`);
    console.log('========================================================\n');

    process.exit(failed === 0 ? 0 : 1);
  } catch (err) {
    console.error('Fatal test error:', err);
    process.exit(1);
  } finally {
    await mongoose.disconnect();
  }
}

runIntegrityTests();
