/**
 * SentinelX Backend Self-Test Suite
 * Tests Express endpoints, JWT auth generation, RBAC rules, and the Python ML bridge.
 */

const request = require('supertest');
const app = require('./src/app');
const { generateAccessToken, generateRefreshToken, verifyAccessToken } = require('./src/config/jwt');
const { callMlService } = require('./src/services/mlBridge.service');

async function runTests() {
  console.log('\n--- 1. Testing /health Endpoint ---');
  const healthRes = await request(app).get('/health');
  console.log(`Status: ${healthRes.status}`);
  console.log(`Response:`, healthRes.body);
  if (healthRes.status !== 200 || !healthRes.body.success) {
    throw new Error('Health check failed');
  }

  console.log('\n--- 2. Testing JWT Token Utilities ---');
  const testPayload = { userId: 'usr-test-123', email: 'analyst@sentinelx.local', role: 'analyst' };
  const token = generateAccessToken(testPayload);
  const decoded = verifyAccessToken(token);
  console.log('Generated token length:', token.length);
  console.log('Decoded payload:', decoded);
  if (decoded.role !== 'analyst' || decoded.userId !== 'usr-test-123') {
    throw new Error('JWT verification mismatch');
  }

  console.log('\n--- 3. Testing RBAC Route Protection ---');
  // Attempt to hit protected route without token
  const unauthRes = await request(app).post('/api/detect').send({ cameraId: 'CAM-001' });
  console.log(`Unauthenticated /api/detect status: ${unauthRes.status} (Expected: 401)`);
  if (unauthRes.status !== 401) {
    throw new Error('Expected 401 on unauthenticated route');
  }

  // Attempt to hit with 'user' role (detect requires analyst or admin)
  const userToken = generateAccessToken({ userId: 'usr-user-001', email: 'user@sentinelx.local', role: 'user' });
  const forbiddenRes = await request(app)
    .post('/api/detect')
    .set('Authorization', `Bearer ${userToken}`)
    .send({ cameraId: 'CAM-001' });
  console.log(`User role on /api/detect status: ${forbiddenRes.status} (Expected: 403)`);
  if (forbiddenRes.status !== 403) {
    throw new Error('Expected 403 on role lower than analyst');
  }

  console.log('\n--- 4. Testing Python ML Bridge & Inference ---');
  const mlOutput = await callMlService({ camera_id: 'CAM-TEST-099' });
  console.log('Python ML bridge output:', JSON.stringify(mlOutput, null, 2));
  if (!mlOutput.threat_class || !Array.isArray(mlOutput.bbox)) {
    throw new Error('Python ML output does not match expected schema');
  }

  console.log('\n--- 5. Testing Authorized /api/detect with Analyst Role ---');
  const analystToken = generateAccessToken({ userId: 'usr-analyst-001', email: 'analyst@sentinelx.local', role: 'analyst' });
  const detectRes = await request(app)
    .post('/api/detect')
    .set('Authorization', `Bearer ${analystToken}`)
    .send({
      cameraId: 'CAM-002',
      location: 'Sector 4 Metro Entrance',
    });
  console.log(`Analyst /api/detect status: ${detectRes.status}`);
  console.log('Detection Response:', JSON.stringify(detectRes.body, null, 2));
  if (detectRes.status !== 200 || !detectRes.body.success) {
    throw new Error('Analyst detection request failed');
  }

  console.log('\n=============================================');
  console.log('✅ ALL BACKEND AND ML BRIDGE TESTS PASSED!');
  console.log('=============================================\n');
}

runTests()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('❌ Test failed:', err);
    process.exit(1);
  });
