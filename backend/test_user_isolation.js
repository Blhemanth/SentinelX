/**
 * SentinelX — Automated User Authorization & Data Isolation Test Suite
 * 
 * Verifies P0 Security & Authorization Requirements:
 * 1. Strict Tenant / User Data Isolation across multi-tenant sessions
 * 2. IDOR Prevention: User B cannot read, acknowledge, dispatch, or delete User A's records
 * 3. Client Identity Tampering / UserId Spoofing Prevention on creation
 * 4. Safe Handling of Legacy Records (unowned records hidden from standard users, accessible to staff)
 * 5. Role-Based Access Control (RBAC): Admin and Analyst oversight vs Civilian User restrictions
 * 6. Isolated Statistics Aggregation per Tenant
 * 7. Malformed ObjectId handling (preventing Mongoose CastError 500s)
 */

require('dotenv').config();
const mongoose = require('mongoose');
const request = require('supertest');
const app = require('./src/app');
const User = require('./src/models/User');
const CrimeLog = require('./src/models/CrimeLog');
const { generateAccessToken } = require('./src/config/jwt');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/sentinelx_audit';

const results = [];
function record(testNum, title, passed, detail = '') {
  results.push({ testNum, title, passed, detail });
  const status = passed ? 'PASS' : 'FAIL';
  console.log(`[${status}] #${testNum}: ${title}${detail ? ` - ${detail}` : ''}`);
}

async function runIsolationSuite() {
  console.log('================================================================');
  console.log('   SentinelX — User Data Isolation & IDOR Verification Suite    ');
  console.log('================================================================\n');

  try {
    if (mongoose.connection.readyState === 0) {
      await mongoose.connect(MONGODB_URI);
    }

    // Clean test users & isolation logs
    const testEmails = [
      'user_alpha_iso@sentinelx.local',
      'user_beta_iso@sentinelx.local',
      'analyst_iso@sentinelx.local',
      'admin_iso@sentinelx.local',
    ];
    await User.deleteMany({ email: { $in: testEmails } });
    await CrimeLog.deleteMany({ location: 'Isolation Test Zone' });

    // 1. Create Test Users
    const userA = await User.create({
      name: 'User Alpha',
      email: 'user_alpha_iso@sentinelx.local',
      password: 'Password123!',
      role: 'user',
    });

    const userB = await User.create({
      name: 'User Beta',
      email: 'user_beta_iso@sentinelx.local',
      password: 'Password123!',
      role: 'user',
    });

    const analyst = await User.create({
      name: 'Analyst Iso',
      email: 'analyst_iso@sentinelx.local',
      password: 'Password123!',
      role: 'analyst',
    });

    const admin = await User.create({
      name: 'Admin Iso',
      email: 'admin_iso@sentinelx.local',
      password: 'Password123!',
      role: 'admin',
    });

    // Generate verified JWT tokens
    const tokenA = generateAccessToken({ userId: userA._id.toString(), email: userA.email, role: userA.role });
    const tokenB = generateAccessToken({ userId: userB._id.toString(), email: userB.email, role: userB.role });
    const tokenAnalyst = generateAccessToken({ userId: analyst._id.toString(), email: analyst.email, role: analyst.role });
    const tokenAdmin = generateAccessToken({ userId: admin._id.toString(), email: admin.email, role: admin.role });

    // ── Test 1: UserId Spoofing Prevention on Creation ───────────────────────
    // User A attempts to forge ownership by specifying createdBy: userB._id
    const createSpoofRes = await request(app)
      .post('/api/logs')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        threatClass: 'Trespassing',
        location: 'Isolation Test Zone',
        cameraId: 'CAM-ISO-01',
        confidence: 0.92,
        createdBy: userB._id.toString(), // SPOOF ATTEMPT
        userId: userB._id.toString(),    // SPOOF ATTEMPT
      });

    const logA1 = createSpoofRes.body?.data;
    const spoofStripped = createSpoofRes.status === 201 &&
      logA1 &&
      logA1.createdBy.toString() === userA._id.toString() &&
      logA1.createdBy.toString() !== userB._id.toString();

    record(
      1,
      'UserId Spoofing Prevention on Incident Creation',
      spoofStripped,
      `Declared UserB ID was ignored; bound to verified token owner: ${logA1?.createdBy}`
    );

    // ── Test 2: User A creates a second incident ─────────────────────────────
    const createA2Res = await request(app)
      .post('/api/logs')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        threatClass: 'Fighting',
        location: 'Isolation Test Zone',
        cameraId: 'CAM-ISO-01',
        confidence: 0.88,
      });
    const logA2 = createA2Res.body?.data;
    record(2, 'User A Second Incident Creation', createA2Res.status === 201 && logA2);

    // ── Test 3: User B creates their own incident ────────────────────────────
    const createBRes = await request(app)
      .post('/api/logs')
      .set('Authorization', `Bearer ${tokenB}`)
      .send({
        threatClass: 'Vandalism',
        location: 'Isolation Test Zone',
        cameraId: 'CAM-ISO-02',
        confidence: 0.76,
      });
    const logB1 = createBRes.body?.data;
    const logBOwned = createBRes.status === 201 && logB1 && logB1.createdBy.toString() === userB._id.toString();
    record(3, 'User B Incident Creation and Verified Ownership', logBOwned);

    // ── Test 4: Data Isolation in Listing (GET /api/logs) ────────────────────
    const listARes = await request(app)
      .get('/api/logs')
      .set('Authorization', `Bearer ${tokenA}`);

    const logsReturnedToA = listARes.body?.data || [];
    const aListIsolated = listARes.status === 200 &&
      logsReturnedToA.every(l => {
        const owner = l.createdBy?._id || l.createdBy;
        return owner && owner.toString() === userA._id.toString();
      }) &&
      logsReturnedToA.some(l => l._id.toString() === logA1._id.toString()) &&
      !logsReturnedToA.some(l => l._id.toString() === logB1._id.toString());

    record(
      4,
      'Listing Data Isolation for User A',
      aListIsolated,
      `User A sees only their own incidents (count: ${logsReturnedToA.length}), User B logs excluded`
    );

    const listBRes = await request(app)
      .get('/api/logs')
      .set('Authorization', `Bearer ${tokenB}`);

    const logsReturnedToB = listBRes.body?.data || [];
    const bListIsolated = listBRes.status === 200 &&
      logsReturnedToB.every(l => {
        const owner = l.createdBy?._id || l.createdBy;
        return owner && owner.toString() === userB._id.toString();
      }) &&
      logsReturnedToB.some(l => l._id.toString() === logB1._id.toString()) &&
      !logsReturnedToB.some(l => l._id.toString() === logA1._id.toString());

    record(
      5,
      'Listing Data Isolation for User B',
      bListIsolated,
      `User B sees only their own incidents (count: ${logsReturnedToB.length}), User A logs excluded`
    );

    // ── Test 6: IDOR Direct Access Attempt (User B reads User A's record) ───
    const idorReadRes = await request(app)
      .get(`/api/logs/${logA1._id}`)
      .set('Authorization', `Bearer ${tokenB}`);

    const idorBlocked = idorReadRes.status === 403 &&
      idorReadRes.body?.success === false &&
      idorReadRes.body?.error?.includes('Access denied');

    record(
      6,
      'IDOR Direct Access Blocked (GET /api/logs/:id across tenants)',
      idorBlocked,
      `Expected HTTP 403 Forbidden, got HTTP ${idorReadRes.status}`
    );

    // ── Test 7: Legitimate Owner Direct Access (User A reads User A's record)
    const legitimateReadRes = await request(app)
      .get(`/api/logs/${logA1._id}`)
      .set('Authorization', `Bearer ${tokenA}`);

    const legitimateAllowed = legitimateReadRes.status === 200 &&
      legitimateReadRes.body?.data?._id?.toString() === logA1._id.toString();

    record(
      7,
      'Legitimate Owner Direct Access (GET /api/logs/:id)',
      legitimateAllowed,
      `Owner User A successfully fetched incident: HTTP ${legitimateReadRes.status}`
    );

    // ── Test 8: Unauthenticated Access Blocked ──────────────────────────────
    const unauthListRes = await request(app).get('/api/logs');
    const unauthGetRes = await request(app).get(`/api/logs/${logA1._id}`);
    const unauthBlocked = unauthListRes.status === 401 && unauthGetRes.status === 401;

    record(
      8,
      'Unauthenticated Access Blocked (HTTP 401 on GET endpoints)',
      unauthBlocked,
      `List: ${unauthListRes.status}, Single: ${unauthGetRes.status}`
    );

    // ── Test 9: IDOR / RBAC Dispatch Tampering Blocked ──────────────────────
    const dispatchTamperRes = await request(app)
      .patch(`/api/logs/${logA1._id}/dispatch`)
      .set('Authorization', `Bearer ${tokenA}`)
      .send({ dispatchStatus: 'assigned_police' });

    const dispatchBlocked = dispatchTamperRes.status === 403;
    record(
      9,
      'Standard User Forbidden from Updating Dispatch Status (RBAC Enforcement)',
      dispatchBlocked,
      `Expected HTTP 403 Forbidden, got HTTP ${dispatchTamperRes.status}`
    );

    // ── Test 10: IDOR / RBAC Acknowledge Tampering Blocked ───────────────────
    const ackTamperRes = await request(app)
      .patch(`/api/logs/${logA1._id}/acknowledge`)
      .set('Authorization', `Bearer ${tokenB}`);

    const ackBlocked = ackTamperRes.status === 403;
    record(
      10,
      'Standard User Forbidden from Acknowledging Incident (RBAC Enforcement)',
      ackBlocked,
      `Expected HTTP 403 Forbidden, got HTTP ${ackTamperRes.status}`
    );

    // ── Test 11: Standard User Forbidden from Deleting Incident ─────────────
    const deleteTamperRes = await request(app)
      .delete(`/api/logs/${logA1._id}`)
      .set('Authorization', `Bearer ${tokenA}`);

    const deleteBlocked = deleteTamperRes.status === 403;
    record(
      11,
      'Standard User Forbidden from Deleting Incident (Admin Only RBAC)',
      deleteBlocked,
      `Expected HTTP 403 Forbidden, got HTTP ${deleteTamperRes.status}`
    );

    // ── Test 12: Staff Surveillance Oversight (Analyst & Admin) ─────────────
    const analystListRes = await request(app)
      .get('/api/logs')
      .set('Authorization', `Bearer ${tokenAnalyst}`);

    const analystLogs = analystListRes.body?.data || [];
    const analystSeesAll = analystListRes.status === 200 &&
      analystLogs.some(l => l._id.toString() === logA1._id.toString()) &&
      analystLogs.some(l => l._id.toString() === logB1._id.toString());

    record(
      12,
      'Analyst Global Surveillance Visibility (Staff Access)',
      analystSeesAll,
      `Analyst sees incidents across all users (total visible: ${analystLogs.length})`
    );

    // Analyst direct read of user incident
    const analystReadRes = await request(app)
      .get(`/api/logs/${logA1._id}`)
      .set('Authorization', `Bearer ${tokenAnalyst}`);

    record(
      13,
      'Analyst Direct Incident Inspection (Staff Permission)',
      analystReadRes.status === 200 && analystReadRes.body?.data?._id?.toString() === logA1._id.toString(),
      `HTTP ${analystReadRes.status}`
    );

    // Analyst filtering by createdBy query param
    const analystFilteredRes = await request(app)
      .get(`/api/logs?createdBy=${userA._id}`)
      .set('Authorization', `Bearer ${tokenAnalyst}`);

    const analystFilteredLogs = analystFilteredRes.body?.data || [];
    const analystFilterCorrect = analystFilteredRes.status === 200 &&
      analystFilteredLogs.every(l => {
        const owner = l.createdBy?._id || l.createdBy;
        return owner && owner.toString() === userA._id.toString();
      }) &&
      !analystFilteredLogs.some(l => l._id.toString() === logB1._id.toString());

    record(
      14,
      'Analyst Query Filter by Tenant User (?createdBy=)',
      analystFilterCorrect,
      `Filtered correctly to User A only (${analystFilteredLogs.length} logs)`
    );

    // ── Test 15: Legacy Records Safety Handling ─────────────────────────────
    // Create an unowned legacy incident with createdBy: null
    const legacyLog = await CrimeLog.create({
      threatClass: 'Loitering',
      location: 'Isolation Test Zone',
      cameraId: 'CAM-LEGACY',
      confidence: 0.65,
      detectionSource: 'legacy_unspecified',
      detectionStatus: 'legacy_unclassified',
      frameTimestamp: new Date(),
      createdBy: null,
    });

    const userAListWithLegacy = await request(app)
      .get('/api/logs')
      .set('Authorization', `Bearer ${tokenA}`);

    const userASeesLegacy = (userAListWithLegacy.body?.data || []).some(
      l => l._id.toString() === legacyLog._id.toString()
    );

    const userAReadLegacyRes = await request(app)
      .get(`/api/logs/${legacyLog._id}`)
      .set('Authorization', `Bearer ${tokenA}`);

    const legacySafeFromUser = !userASeesLegacy && userAReadLegacyRes.status === 403;
    record(
      15,
      'Legacy Unowned Records Safety (Hidden from Civilian Users)',
      legacySafeFromUser,
      `User list excluded legacy: ${!userASeesLegacy}, Direct fetch: HTTP ${userAReadLegacyRes.status} (Forbidden)`
    );

    const analystListWithLegacy = await request(app)
      .get('/api/logs')
      .set('Authorization', `Bearer ${tokenAnalyst}`);

    const analystSeesLegacy = (analystListWithLegacy.body?.data || []).some(
      l => l._id.toString() === legacyLog._id.toString()
    );

    record(
      16,
      'Legacy Unowned Records Visible to Staff for Audit Oversight',
      analystSeesLegacy,
      `Analyst retained access to historical unowned record: ${analystSeesLegacy}`
    );

    // ── Test 17: Tenant Aggregated Stats Isolation (GET /api/logs/stats) ────
    const statsUserARes = await request(app)
      .get('/api/logs/stats')
      .set('Authorization', `Bearer ${tokenA}`);

    const userATotal = statsUserARes.body?.data?.totalLogs;

    const statsAnalystRes = await request(app)
      .get('/api/logs/stats')
      .set('Authorization', `Bearer ${tokenAnalyst}`);

    const globalTotal = statsAnalystRes.body?.data?.totalLogs;

    const statsIsolated = statsUserARes.status === 200 &&
      userATotal === 2 && // logA1 and logA2
      globalTotal >= 3;  // logA1, logA2, logB1, legacyLog

    record(
      17,
      'Aggregated Statistics Tenant Isolation (GET /api/logs/stats)',
      statsIsolated,
      `User A total: ${userATotal} (strictly their 2 logs), Global total: ${globalTotal}`
    );

    // ── Test 18: Malformed / Invalid ObjectId Handling ──────────────────────
    const malformedRes = await request(app)
      .get('/api/logs/not-a-valid-object-id')
      .set('Authorization', `Bearer ${tokenA}`);

    const nonExistentRes = await request(app)
      .get('/api/logs/507f1f77bcf86cd799439011')
      .set('Authorization', `Bearer ${tokenA}`);

    const objectIdSafe = malformedRes.status === 404 && nonExistentRes.status === 404;
    record(
      18,
      'Malformed and Non-Existent ObjectId Defensive Handling',
      objectIdSafe,
      `Malformed ID returned HTTP ${malformedRes.status}, Non-existent returned HTTP ${nonExistentRes.status}`
    );

    // ── Test 19: Admin Authorized Deletion ──────────────────────────────────
    const adminDeleteRes = await request(app)
      .delete(`/api/logs/${logA1._id}`)
      .set('Authorization', `Bearer ${tokenAdmin}`);

    record(
      19,
      'Admin Authorized Deletion (RBAC Verification)',
      adminDeleteRes.status === 200 && adminDeleteRes.body?.success === true,
      `HTTP ${adminDeleteRes.status}`
    );

    // Cleanup
    await CrimeLog.deleteMany({ location: 'Isolation Test Zone' });
    await User.deleteMany({ email: { $in: testEmails } });

  } catch (err) {
    console.error('Test suite runtime error:', err);
    record(99, 'Suite Execution Failure', false, err.message);
  } finally {
    if (mongoose.connection.readyState !== 0) {
      await mongoose.disconnect();
    }
  }

  // Summary
  console.log('\n================================================================');
  console.log('                 ISOLATION AUDIT SUMMARY                        ');
  console.log('================================================================');
  const passedCount = results.filter(r => r.passed).length;
  const totalCount = results.length;
  console.log(`Passed: ${passedCount}/${totalCount} (${((passedCount / totalCount) * 100).toFixed(1)}%)`);

  if (passedCount !== totalCount) {
    console.error('\nFAILED TESTS:');
    results.filter(r => !r.passed).forEach(r => console.error(` - #${r.testNum}: ${r.title} (${r.detail})`));
    process.exit(1);
  } else {
    console.log('\nALL ISOLATION & IDOR TESTS PASSED PERFECTLY.');
    process.exit(0);
  }
}

runIsolationSuite();
