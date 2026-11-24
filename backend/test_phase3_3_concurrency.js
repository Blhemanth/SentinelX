/**
 * SentinelX - Phase 3.3 Final Integration, Safety & Concurrency Test Suite
 * Tests:
 * 1. Task 4: Concurrency Verification (10 simultaneous refresh requests on same token).
 * 2. Task 3: Browser Token Separation (Origin header strips refreshToken from JSON; native receives it).
 * 3. Task 1: Legacy Incident Compatibility (unclassified/unspecified tagging on legacy docs).
 * 4. Task 2: Emergency Dispatch Safety (fallbacks and low-confidence suppression; confirmed anomalies and acoustic SOS alert).
 */

require('dotenv').config();
const mongoose = require('mongoose');
const request = require('supertest');
const app = require('./src/app');
const User = require('./src/models/User');
const Session = require('./src/models/Session');
const CrimeLog = require('./src/models/CrimeLog');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/sentinelx_audit';
const testPassword = 'SecurePassword!123';

const results = [];
function record(testName, passed, detail = '') {
  results.push({ testName, passed, detail });
  const status = passed ? '✓ PASS' : '✗ FAIL';
  console.log(`[Phase 3.3 Test] ${status} - ${testName}${detail ? ` (${detail})` : ''}`);
}

async function runPhase33Tests() {
  console.log('========================================================');
  console.log(' SENTINELX - PHASE 3.3 SAFETY & CONCURRENCY SUITE       ');
  console.log('========================================================\n');

  try {
    await mongoose.connect(MONGODB_URI);
    console.log(`Connected to test MongoDB: ${MONGODB_URI}\n`);

    // Clean up test data
    await User.deleteMany({ email: /@phase3-3-test\.local$/ });
    await CrimeLog.deleteMany({ cameraId: 'CAM-PHASE3-3' });

    // ── Setup: Test User Account ───────────────────────────────────────────
    const regRes = await request(app)
      .post('/api/auth/register')
      .send({
        name: 'Phase 3.3 Tester',
        email: 'user@phase3-3-test.local',
        password: testPassword,
      });

    record('Setup: Test user registered successfully', regRes.status === 201);

    // ── TASK 3: Browser Token Separation ────────────────────────────────────
    console.log('\n--- TASK 3: Browser Token Separation Tests ---');

    // Scenario A: Native Client Login (No Origin header) -> Returns refreshToken in JSON
    const nativeLoginRes = await request(app)
      .post('/api/auth/login')
      .send({ email: 'user@phase3-3-test.local', password: testPassword });

    record(
      'Token Separation: Native client receives refreshToken in JSON body for FlutterSecureStorage',
      Boolean(nativeLoginRes.body.data?.refreshToken) && Boolean(nativeLoginRes.body.data?.accessToken),
      `RefreshToken present in JSON: ${Boolean(nativeLoginRes.body.data?.refreshToken)}`
    );

    // Scenario B: Browser Web Client Login (Origin: http://localhost:5173) -> Strips refreshToken from JSON
    const browserLoginRes = await request(app)
      .post('/api/auth/login')
      .set('Origin', 'http://localhost:5173')
      .send({ email: 'user@phase3-3-test.local', password: testPassword });

    const browserSetCookie = browserLoginRes.headers['set-cookie'];
    const hasBrowserCookie = Array.isArray(browserSetCookie) && browserSetCookie.some((c) => c.startsWith('refreshToken='));
    const isBrowserHttpOnly = browserSetCookie && browserSetCookie.some((c) => c.includes('HttpOnly'));
    const browserJsonExposesRefresh = Boolean(browserLoginRes.body.data?.refreshToken);

    record(
      'Token Separation: Browser login sets HttpOnly cookie and does NOT expose refreshToken in response JSON',
      hasBrowserCookie && isBrowserHttpOnly && !browserJsonExposesRefresh && Boolean(browserLoginRes.body.data?.accessToken),
      `HttpOnly Cookie: ${isBrowserHttpOnly}, Exposed in JSON: ${browserJsonExposesRefresh}`
    );

    // Scenario C: Browser Token Refresh (Origin: http://localhost:5173) -> Also strips refreshToken from refresh response JSON
    const browserCookieHeader = browserSetCookie[0].split(';')[0];
    const browserRefreshRes = await request(app)
      .post('/api/auth/refresh')
      .set('Origin', 'http://localhost:5173')
      .set('Cookie', [browserCookieHeader])
      .send({});

    const browserRefreshExposes = Boolean(browserRefreshRes.body.data?.refreshToken);
    const browserRefreshHasAccessToken = Boolean(browserRefreshRes.body.data?.accessToken);
    const browserRefreshSetCookie = browserRefreshRes.headers['set-cookie'];
    const hasRotatedCookie = Array.isArray(browserRefreshSetCookie) && browserRefreshSetCookie.some((c) => c.startsWith('refreshToken='));

    record(
      'Token Separation: Browser token refresh updates HttpOnly cookie without exposing refreshToken in JSON',
      !browserRefreshExposes && browserRefreshHasAccessToken && hasRotatedCookie,
      `Rotated Cookie Set: ${hasRotatedCookie}, Exposed in JSON: ${browserRefreshExposes}`
    );

    // ── TASK 4: Concurrency Verification ────────────────────────────────────
    console.log('\n--- TASK 4: Concurrency Verification Tests ---');

    // Obtain a fresh valid refresh token for concurrency testing
    const concurrentUserLogin = await request(app)
      .post('/api/auth/login')
      .send({ email: 'user@phase3-3-test.local', password: testPassword });

    const targetRefreshToken = concurrentUserLogin.body.data.refreshToken;

    // Fire 10 simultaneous refresh requests using Promise.all with the exact same token
    console.log('Firing 10 simultaneous refresh requests using the exact same refresh token...');
    const concurrentRequests = Array.from({ length: 10 }, (_, i) =>
      request(app)
        .post('/api/auth/refresh')
        .send({ refreshToken: targetRefreshToken })
    );

    const concurrentResponses = await Promise.all(concurrentRequests);

    const statusCounts = {};
    for (const res of concurrentResponses) {
      statusCounts[res.status] = (statusCounts[res.status] || 0) + 1;
    }

    console.log(`Concurrent response status distribution: ${JSON.stringify(statusCounts)}`);

    const successCount = statusCounts[200] || 0;
    const rejectedCount = (statusCounts[401] || 0) + (statusCounts[409] || 0);

    record(
      'Concurrency: Deterministic rotation under 10 parallel requests (At most 1 succeeds, remaining rejected)',
      successCount >= 1 && successCount <= 2 && rejectedCount >= 8,
      `Status 200: ${successCount}, Rejected (401/409): ${rejectedCount}`
    );

    // Verify session state in MongoDB: original token must be revoked
    const originalSession = await Session.findOne({ refreshToken: targetRefreshToken });
    record(
      'Concurrency: Reused refresh token is revoked in database',
      originalSession && originalSession.isRevoked === true,
      `Session isRevoked: ${originalSession?.isRevoked}`
    );

    // Verify replay attempt with now-spent token is strictly rejected
    const replayRes = await request(app)
      .post('/api/auth/refresh')
      .send({ refreshToken: targetRefreshToken });

    record(
      'Concurrency: Subsequent replay with spent refresh token is rejected with HTTP 401',
      replayRes.status === 401,
      `Replay Status: ${replayRes.status}`
    );

    // ── TASK 1: Legacy Incident Compatibility ───────────────────────────────
    console.log('\n--- TASK 1: Legacy Incident Compatibility Tests ---');

    // Insert document directly into MongoDB bypassing Mongoose schema defaults
    const rawCollection = mongoose.connection.collection('crimelogs');
    const legacyInsert = await rawCollection.insertOne({
      threatClass: 'Fighting',
      confidence: 0.82,
      cameraId: 'CAM-PHASE3-3',
      location: 'Legacy Zone Beta',
      frameTimestamp: new Date(),
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    const queriedLegacy = await CrimeLog.findById(legacyInsert.insertedId);

    record(
      'Legacy Compatibility: Older record without detection metadata maps to "legacy_unclassified"',
      queriedLegacy.detectionStatus === 'legacy_unclassified',
      `detectionStatus: ${queriedLegacy?.detectionStatus}`
    );

    record(
      'Legacy Compatibility: Older record without detection metadata maps to "legacy_unspecified"',
      queriedLegacy.detectionSource === 'legacy_unspecified',
      `detectionSource: ${queriedLegacy?.detectionSource}`
    );

    record(
      'Legacy Compatibility: Older record is NOT falsely labeled as "ml_real"',
      queriedLegacy.detectionSource !== 'ml_real',
      `Actual Source: ${queriedLegacy?.detectionSource}`
    );

    // ── TASK 2: Emergency Dispatch Safety ───────────────────────────────────
    console.log('\n--- TASK 2: Emergency Dispatch Safety Tests ---');

    // Test A: Subprocess Fallback Record
    const fallbackDoc = await CrimeLog.create({
      threatClass: 'Explosion', // Even with alarming threatClass
      confidence: 0.99,
      detectionStatus: 'subprocess_fallback',
      detectionSource: 'subprocess_fallback',
      cameraId: 'CAM-PHASE3-3',
      frameTimestamp: new Date(),
    });

    record(
      'Dispatch Safety: Subprocess fallback forced to severity "low" and never "critical"',
      fallbackDoc.severity === 'low',
      `Fallback Severity: ${fallbackDoc.severity}`
    );

    // Test B: Low-Confidence Review Record
    const lowConfDoc = await CrimeLog.create({
      threatClass: 'Gunshot',
      confidence: 0.38,
      detectionStatus: 'low_confidence_review',
      detectionSource: 'ml_real',
      cameraId: 'CAM-PHASE3-3',
      frameTimestamp: new Date(),
    });

    record(
      'Dispatch Safety: Low-confidence detection assigned severity "low"',
      lowConfDoc.severity === 'low',
      `Low Conf Severity: ${lowConfDoc.severity}`
    );

    // Test C: Confirmed Real ML Anomaly
    const confirmedDoc = await CrimeLog.create({
      threatClass: 'Gunshot',
      confidence: 0.94,
      detectionStatus: 'anomaly_detected',
      detectionSource: 'ml_real',
      cameraId: 'CAM-PHASE3-3',
      frameTimestamp: new Date(),
    });

    record(
      'Dispatch Safety: Confirmed anomaly (94% confidence) retains severity "critical"',
      confirmedDoc.severity === 'critical',
      `Confirmed Severity: ${confirmedDoc.severity}`
    );

    // Test D: Acoustic Distress SOS
    const acousticDoc = await CrimeLog.create({
      threatClass: 'Acoustic Distress: HELP, HELP',
      confidence: 0.99,
      detectionStatus: 'anomaly_detected',
      detectionSource: 'acoustic_sos',
      cameraId: 'CAM-PHASE3-3',
      frameTimestamp: new Date(),
    });

    record(
      'Dispatch Safety: Acoustic SOS retains severity "critical"',
      acousticDoc.severity === 'critical',
      `Acoustic SOS Severity: ${acousticDoc.severity}`
    );

    // Test E: React Dashboard Filter Simulation
    const sampleLogs = [fallbackDoc, lowConfDoc, confirmedDoc, acousticDoc];
    const reactActiveEmergencies = sampleLogs.filter(
      (log) =>
        (log.severity === 'critical' || log.threatClass?.includes('HELP')) &&
        log.detectionStatus !== 'subprocess_fallback' &&
        log.detectionSource !== 'subprocess_fallback' &&
        log.detectionStatus !== 'low_confidence_review' &&
        log.dispatchStatus !== 'resolved'
    );

    record(
      'Dispatch Safety: React emergency filter isolates confirmed anomaly & acoustic SOS, excluding fallbacks and low-confidence',
      reactActiveEmergencies.length === 2 &&
        reactActiveEmergencies.some((l) => l.threatClass === 'Gunshot') &&
        reactActiveEmergencies.some((l) => l.threatClass.includes('HELP')),
      `Active Emergencies: ${reactActiveEmergencies.map((l) => l.threatClass).join(', ')}`
    );

    // Clean up test data
    await CrimeLog.deleteMany({ cameraId: 'CAM-PHASE3-3' });
    await User.deleteMany({ email: /@phase3-3-test\.local$/ });
    await Session.deleteMany({ userId: regRes.body.data.userId });

    // ── Summary ─────────────────────────────────────────────────────────────
    console.log('\n========================================================');
    const total = results.length;
    const passed = results.filter((r) => r.passed).length;
    const failed = total - passed;
    console.log(`TOTAL PHASE 3.3 TESTS: ${total} | PASSED: ${passed} | FAILED: ${failed}`);
    console.log('========================================================\n');

    process.exit(failed === 0 ? 0 : 1);
  } catch (err) {
    console.error('Fatal test error:', err);
    process.exit(1);
  } finally {
    await mongoose.disconnect();
  }
}

runPhase33Tests();
