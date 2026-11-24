/**
 * SentinelX - Comprehensive Technical Audit Verification Suite
 * Executes functional, security, RBAC, and performance tests against backend/src/app.js
 */

const mongoose = require('mongoose');
const request = require('supertest');
const app = require('./src/app');
const User = require('./src/models/User');
const Session = require('./src/models/Session');
const CrimeLog = require('./src/models/CrimeLog');

const MONGO_URI = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/sentinelx_audit';

async function runAudit() {
  console.log('====================================================');
  console.log('SENTINELX AUTOMATED AUDIT VERIFICATION SUITE');
  console.log('====================================================\n');

  // 1. Database Connection
  console.log('[1/6] Connecting to MongoDB...');
  await mongoose.connect(MONGO_URI);
  console.log('✓ Connected to MongoDB:', MONGO_URI);

  // Clean test collection
  await User.deleteMany({ email: /@audit-test\.local$/ });
  await CrimeLog.deleteMany({ location: /Audit-Test/ });

  const results = {
    auth: {},
    rbac: {},
    incidents: {},
    security: {},
    performance: {},
  };

  // ─── 2. AUTHENTICATION VERIFICATION ──────────────────────────────────────────
  console.log('\n[2/6] Verifying Authentication...');

  // 2.1 Registration
  const regEmail = `test_analyst_${Date.now()}@audit-test.local`;
  const regPass = 'StrongPass123!';
  const regRes = await request(app)
    .post('/api/auth/register')
    .send({ name: 'Audit Analyst', email: regEmail, password: regPass, role: 'analyst' });

  results.auth.registration = {
    status: regRes.status,
    success: regRes.body.success,
    hasToken: Boolean(regRes.body.data?.accessToken),
  };
  console.log('  Registration:', regRes.status === 201 ? 'PASS (201)' : `FAIL (${regRes.status})`);

  // Verify bcrypt password hashing in DB (password is select: false)
  const dbUser = await User.findOne({ email: regEmail }).select('+password');
  const isBcrypt = dbUser && dbUser.password && dbUser.password.startsWith('$2') && dbUser.password.length === 60;
  results.auth.passwordHashing = { isBcrypt, hashLength: dbUser?.password?.length };
  console.log('  Bcrypt Hashing in DB:', isBcrypt ? 'PASS ($2... 60 chars)' : 'FAIL');

  // 2.2 Login
  const loginRes = await request(app)
    .post('/api/auth/login')
    .send({ email: regEmail, password: regPass });

  const accessToken = loginRes.body.data?.accessToken;
  const refreshToken = loginRes.body.data?.refreshToken;
  results.auth.login = {
    status: loginRes.status,
    hasAccessToken: Boolean(accessToken),
    hasRefreshToken: Boolean(refreshToken),
  };
  console.log('  Login:', loginRes.status === 200 && accessToken ? 'PASS (200, JWT returned)' : 'FAIL');

  // 2.3 Refresh Token Rotation (Wait 1.1s so JWT iat changes to test rotation)
  await new Promise(r => setTimeout(r, 1100));
  const refreshRes = await request(app)
    .post('/api/auth/refresh')
    .send({ refreshToken });

  const newAccessToken = refreshRes.body.data?.accessToken;
  const newRefreshToken = refreshRes.body.data?.refreshToken;
  const rotated = Boolean(newRefreshToken && newRefreshToken !== refreshToken);
  results.auth.tokenRotation = {
    status: refreshRes.status,
    gotNewAccessToken: Boolean(newAccessToken),
    tokenRotated: rotated,
  };
  console.log('  Token Rotation:', rotated ? 'PASS (Rotated new refresh token)' : `FAIL (Status: ${refreshRes.status})`);

  // 2.4 Protected Route (401 without token, 401 with tampered token)
  const noTokenRes = await request(app).get('/api/auth/me');
  const tamperedRes = await request(app)
    .get('/api/auth/me')
    .set('Authorization', 'Bearer fake_tampered_token_xyz');

  const validMeRes = await request(app)
    .get('/api/auth/me')
    .set('Authorization', `Bearer ${newAccessToken || accessToken}`);

  results.auth.protectedRoutes = {
    noTokenStatus: noTokenRes.status,
    tamperedTokenStatus: tamperedRes.status,
    validTokenStatus: validMeRes.status,
  };
  console.log('  Protected Guard:', noTokenRes.status === 401 && tamperedRes.status === 401 && validMeRes.status === 200 ? 'PASS (401 rejection working)' : 'FAIL');

  // 2.5 Logout & Session Revocation
  const logoutRes = await request(app)
    .post('/api/auth/logout')
    .set('Authorization', `Bearer ${newAccessToken || accessToken}`)
    .send({ refreshToken: newRefreshToken || refreshToken });

  // Attempt using revoked refresh token
  const revokedRefreshRes = await request(app)
    .post('/api/auth/refresh')
    .send({ refreshToken: newRefreshToken || refreshToken });

  results.auth.logout = {
    logoutStatus: logoutRes.status,
    revokedAttemptStatus: revokedRefreshRes.status,
  };
  console.log('  Logout Revocation:', revokedRefreshRes.status === 401 ? 'PASS (Session revoked in DB)' : 'FAIL');

  // ─── 3. RBAC VERIFICATION ACROSS ALL 4 ROLES ─────────────────────────────────
  console.log('\n[3/6] Verifying RBAC across all 4 roles (admin, police, analyst, user)...');

  const roles = ['admin', 'police', 'analyst', 'user'];
  const roleTokens = {};

  for (const r of roles) {
    const email = `audit_${r}@audit-test.local`;
    await User.deleteOne({ email });
    await request(app)
      .post('/api/auth/register')
      .send({ name: `Audit ${r}`, email, password: 'Password123!', role: r });
    // Update role directly in DB to test authentic role permissions
    await User.updateOne({ email }, { role: r });
    const logRes = await request(app)
      .post('/api/auth/login')
      .send({ email, password: 'Password123!' });
    roleTokens[r] = logRes.body.data?.accessToken;
  }

  // RBAC Tests on critical endpoints:
  // 1. DELETE /api/logs/:id (requires admin)
  // 2. POST /api/logs/trigger (requires analyst or police or admin)
  // 3. POST /api/detect (requires analyst or police or admin)
  // 4. GET /api/logs (open to user, analyst, police, admin)

  const dummyLog = await CrimeLog.create({
    threatClass: 'Normal',
    confidence: 0.95,
    cameraId: 'CAM-001',
    location: 'Audit-Test Sector',
    frameTimestamp: new Date(),
  });

  results.rbac.deleteLog = {};
  results.rbac.triggerAnomaly = {};
  results.rbac.detect = {};
  results.rbac.getLogs = {};

  for (const r of roles) {
    const token = roleTokens[r];

    // Test GET /api/logs
    const getRes = await request(app)
      .get('/api/logs')
      .set('Authorization', `Bearer ${token}`);
    results.rbac.getLogs[r] = getRes.status;

    // Test POST /api/logs/trigger
    const trigRes = await request(app)
      .post('/api/logs/trigger')
      .set('Authorization', `Bearer ${token}`)
      .send({ threatClass: 'Explosion', location: 'Audit-Test Zone' });
    results.rbac.triggerAnomaly[r] = trigRes.status;

    // Test DELETE /api/logs/:id
    const delRes = await request(app)
      .delete(`/api/logs/${dummyLog._id}`)
      .set('Authorization', `Bearer ${token}`);
    results.rbac.deleteLog[r] = delRes.status;
  }

  console.log('  GET /api/logs (all roles):', results.rbac.getLogs);
  console.log('  POST /api/logs/trigger (analyst+):', results.rbac.triggerAnomaly);
  console.log('  DELETE /api/logs/:id (admin only):', results.rbac.deleteLog);

  // ─── 4. INCIDENT MANAGEMENT & DISPATCH PROGRESSION ───────────────────────────
  console.log('\n[4/6] Verifying Incident Lifecycle & Dispatch Progression...');

  // 4.1 Ingest via Flutter payload format
  const flutterLogRes = await request(app)
    .post('/api/logs')
    .set('Authorization', `Bearer ${roleTokens.analyst}`)
    .send({
      threatClass: 'Acoustic Distress: HELP, HELP',
      confidence: 0.988,
      cameraId: 'CAM-001',
      location: 'Audit-Test Location A',
      audioDecibels: 89.2,
      audioTranscript: 'HELP! HELP! EMERGENCY AT SECTOR',
      dispatchStatus: 'unassigned',
      severity: 'critical',
    });

  const createdId = flutterLogRes.body.data?._id;
  results.incidents.createFlutter = { status: flutterLogRes.status, id: createdId };

  // 4.2 Patch Dispatch Status through CAD Stepper
  const steps = ['assigned_police', 'en_route', 'on_scene', 'resolved'];
  const stepResults = [];

  for (const st of steps) {
    const patchRes = await request(app)
      .patch(`/api/logs/${createdId}/dispatch`)
      .set('Authorization', `Bearer ${roleTokens.police}`)
      .send({ dispatchStatus: st, assignedTo: 'Unit 104', policeNotes: `Status changed to ${st}` });
    stepResults.push({ step: st, status: patchRes.status, dbStatus: patchRes.body.data?.dispatchStatus });
  }
  results.incidents.dispatchSteps = stepResults;

  // 4.3 Acknowledge Log
  const ackRes = await request(app)
    .patch(`/api/logs/${createdId}/acknowledge`)
    .set('Authorization', `Bearer ${roleTokens.analyst}`);

  results.incidents.acknowledge = { status: ackRes.status, isAck: ackRes.body.data?.isAcknowledged };

  // 4.4 Verify Record in MongoDB
  const finalRecord = await CrimeLog.findById(createdId);
  results.incidents.persistedState = {
    id: finalRecord?._id,
    threatClass: finalRecord?.threatClass,
    dispatchStatus: finalRecord?.dispatchStatus,
    isAcknowledged: finalRecord?.isAcknowledged,
    policeNotes: finalRecord?.policeNotes,
  };
  console.log('  Incident Lifecycle Result:');
  console.log('    Created:', createdId);
  console.log('    CAD Dispatch progression:', stepResults.map(s => `${s.step} (${s.status})`).join(' -> '));
  console.log('    Acknowledged:', finalRecord?.isAcknowledged);
  console.log('    Final DB Status:', finalRecord?.dispatchStatus);

  // ─── 5. SECURITY & INPUT VALIDATION ASSESSMENT ───────────────────────────────
  console.log('\n[5/6] Security & Vulnerability Assessment...');

  // 5.1 Helmet & Security Headers
  const headRes = await request(app).get('/health');
  const headers = headRes.headers;
  results.security.headers = {
    xContentTypeOptions: headers['x-content-type-options'],
    xFrameOptions: headers['x-frame-options'],
    contentSecurityPolicy: headers['content-security-policy'],
  };
  console.log('  Helmet Security Headers:', headers['x-content-type-options'] ? 'PRESENT' : 'MISSING');

  // 5.2 NoSQL Injection Test (Attempt query operator in string field)
  const injRes = await request(app)
    .post('/api/auth/login')
    .send({ email: { '$gt': '' }, password: { '$gt': '' } });
  results.security.noSqlInjection = { status: injRes.status, blocked: injRes.status === 400 || injRes.status === 401 };
  console.log('  NoSQL Operator Injection:', results.security.noSqlInjection.blocked ? 'BLOCKED/HANDLED' : 'VULNERABLE');

  // 5.3 Weak Password Handling
  const weakPassRes = await request(app)
    .post('/api/auth/register')
    .send({ name: 'Weak', email: 'weak@audit-test.local', password: '123' });
  results.security.weakPassword = { status: weakPassRes.status, rejected: weakPassRes.status === 400 };
  console.log('  Weak Password (< 8 chars):', weakPassRes.status === 400 ? 'REJECTED (400)' : 'ALLOWED');

  // 5.4 Privilege Escalation in Register
  // Does regular user registration permit setting role='admin'?
  const privEscRes = await request(app)
    .post('/api/auth/register')
    .send({ name: 'Hacker', email: 'hacker@audit-test.local', password: 'Password123!', role: 'admin' });
  results.security.privilegeEscalationOnRegister = {
    status: privEscRes.status,
    roleGranted: privEscRes.body.data?.user?.role,
    allowedAdmin: privEscRes.body.data?.user?.role === 'admin',
  };
  console.log('  Public Registration Role Assignment:', results.security.privilegeEscalationOnRegister.allowedAdmin ? 'WARNING: ANY USER CAN REGISTER AS ADMIN' : 'SAFE');

  // ─── 6. PERFORMANCE & LATENCY MEASUREMENTS ──────────────────────────────────
  console.log('\n[6/6] Performance Benchmarking...');

  // Measure GET /api/logs (10 iterations)
  const getLatencies = [];
  for (let i = 0; i < 10; i++) {
    const t0 = process.hrtime.bigint();
    await request(app).get('/api/logs').set('Authorization', `Bearer ${roleTokens.admin}`);
    const diffMs = Number(process.hrtime.bigint() - t0) / 1e6;
    getLatencies.push(diffMs);
  }
  const avgGet = getLatencies.reduce((a, b) => a + b, 0) / getLatencies.length;
  results.performance.apiLogsQuery = {
    avgMs: round2(avgGet),
    minMs: round2(Math.min(...getLatencies)),
    maxMs: round2(Math.max(...getLatencies)),
  };
  console.log(`  GET /api/logs Latency: Avg ${results.performance.apiLogsQuery.avgMs} ms (Min: ${results.performance.apiLogsQuery.minMs} ms, Max: ${results.performance.apiLogsQuery.maxMs} ms)`);

  // Concurrent Load: 20 simultaneous requests to /api/logs
  const c0 = process.hrtime.bigint();
  const concurrentPromises = Array.from({ length: 20 }, () =>
    request(app).get('/api/logs').set('Authorization', `Bearer ${roleTokens.admin}`)
  );
  const concurrentRes = await Promise.all(concurrentPromises);
  const totalConcurrentMs = Number(process.hrtime.bigint() - c0) / 1e6;
  results.performance.concurrency20 = {
    totalMs: round2(totalConcurrentMs),
    all200: concurrentRes.every(r => r.status === 200),
    avgPerReqMs: round2(totalConcurrentMs / 20),
  };
  console.log(`  20 Concurrent Requests: Total ${results.performance.concurrency20.totalMs} ms (All 200: ${results.performance.concurrency20.all200})`);

  // Clean test data
  await User.deleteMany({ email: /@audit-test\.local$/ });
  await CrimeLog.deleteMany({ location: /Audit-Test/ });
  await mongoose.disconnect();

  console.log('\n====================================================');
  console.log('AUDIT RUN COMPLETED. DUMPING RESULTS JSON:');
  console.log('====================================================');
  console.log(JSON.stringify(results, null, 2));
}

function round2(num) {
  return Math.round(num * 100) / 100;
}

runAudit().catch(err => {
  console.error('Fatal audit error:', err);
  process.exit(1);
});
