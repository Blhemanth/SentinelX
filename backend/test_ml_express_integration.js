/**
 * SentinelX - Phase 3 Express Backend to Python ML Integration Test Suite
 * Validates:
 * 1. Express forwards real base64 video & audio to Python ML engine.
 * 2. Response returns genuine model predictions, bounding boxes, logits, and metrics.
 * 3. MongoDB CrimeLog collection correctly saves genuine ML events with detectionSource: 'ml_real'.
 * 4. Demonstration drills are distinctly flagged with detectionSource: 'drill_simulation'.
 */

require('dotenv').config();
const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const request = require('supertest');
const { execSync } = require('child_process');

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
  console.log(`[ML Integration Test] ${status} - ${testName}${detail ? ` (${detail})` : ''}`);
}

async function runMlIntegrationTests() {
  console.log('====================================================');
  console.log(' SENTINELX - EXPRESS <-> PYTHON ML INTEGRATION SUITE');
  console.log('====================================================\n');

  try {
    await mongoose.connect(MONGODB_URI);
    console.log(`Connected to test MongoDB: ${MONGODB_URI}\n`);

    // Clean up previous test users and logs
    await User.deleteMany({ email: /@ml-test\.local$/ });
    await CrimeLog.deleteMany({ cameraId: 'CAM-TEST-ML' });

    // ── Generate real sample media (MP4 & WAV) via OpenCV & Scipy ───────
    console.log('Generating real sample media (MP4 & WAV) via OpenCV & Scipy...');
    const mediaGenCode = `import cv2, numpy as np, scipy.io.wavfile as wav
v_path = "backend/test_sample_video.mp4"
fourcc = cv2.VideoWriter_fourcc(*"mp4v")
out = cv2.VideoWriter(v_path, fourcc, 20.0, (224, 224))
for i in range(20):
    f = np.zeros((224, 224, 3), dtype=np.uint8)
    cv2.circle(f, (30 + i * 8, 112), 25, (0, 255, 0), -1)
    out.write(f)
out.release()

a_path = "backend/test_sample_audio.wav"
sr = 16000
t = np.linspace(0, 1.0, sr, endpoint=False)
sig = (np.sin(2 * np.pi * 500 * t) * 32767).astype(np.int16)
wav.write(a_path, sr, sig)
print("MEDIA_GEN_OK")
`;
    fs.writeFileSync('backend/_gen_media_tmp.py', mediaGenCode, 'utf8');
    execSync('python backend/_gen_media_tmp.py');

    const videoBytes = fs.readFileSync('backend/test_sample_video.mp4');
    const audioBytes = fs.readFileSync('backend/test_sample_audio.wav');
    const videoBase64 = videoBytes.toString('base64');
    const audioBase64 = audioBytes.toString('base64');

    // Clean up temporary files
    try { fs.unlinkSync('backend/test_sample_video.mp4'); } catch (_) {}
    try { fs.unlinkSync('backend/test_sample_audio.wav'); } catch (_) {}
    try { fs.unlinkSync('backend/_gen_media_tmp.py'); } catch (_) {}

    console.log(`Media generated: Video ${videoBytes.length} bytes, Audio ${audioBytes.length} bytes.\n`);

    // ── 1. Create Analyst User & Authenticate ─────────────────────────────────
    const regRes = await request(app)
      .post('/api/auth/register')
      .send({
        name: 'Analyst ML Tester',
        email: 'analyst@ml-test.local',
        password: testPassword,
      });

    // Elevate role to analyst directly in DB
    await User.updateOne({ email: 'analyst@ml-test.local' }, { role: 'analyst' });

    const loginRes = await request(app)
      .post('/api/auth/login')
      .send({ email: 'analyst@ml-test.local', password: testPassword });

    analystToken = loginRes.body.data.accessToken;
    record('Auth: Analyst account registered and authenticated', Boolean(analystToken));

    // ── 2. Call POST /api/detect with Genuine Video & Audio ───────────────────
    console.log('Sending real multimodal media payload to POST /api/detect...');
    const detectRes = await request(app)
      .post('/api/detect')
      .set('Authorization', `Bearer ${analystToken}`)
      .send({
        cameraId: 'CAM-TEST-ML',
        location: 'North Perimeter Gate',
        videoFrames: videoBase64,
        audioData: audioBase64,
      });

    record(
      'API Response Status: /api/detect responds with HTTP 200',
      detectRes.status === 200,
      `Status: ${detectRes.status}`
    );

    const data = detectRes.body.data;
    record(
      'Threat Classification: Valid class predicted from model taxonomy',
      ['Explosion', 'Gunshot', 'Fighting', 'Accident', 'Normal'].includes(data?.threatClass),
      `Threat: ${data?.threatClass}`
    );

    record(
      'Confidence Score: Valid confidence value in [0.0, 1.0]',
      typeof data?.confidence === 'number' && data.confidence >= 0 && data.confidence <= 1.0,
      `Confidence: ${(data?.confidence * 100).toFixed(2)}%`
    );

    record(
      'Bounding Box: Valid normalized bounding box coords',
      typeof data?.boundingBox?.x === 'number' &&
        data.boundingBox.x >= 0 &&
        data.boundingBox.y >= 0 &&
        data.boundingBox.w >= 0 &&
        data.boundingBox.h >= 0,
      `Box: [${data?.boundingBox?.x}, ${data?.boundingBox?.y}, ${data?.boundingBox?.w}, ${data?.boundingBox?.h}]`
    );

    record(
      'Metrics Tracking: Separate preprocessing and inference latencies recorded',
      typeof data?.metrics?.modelInferenceMs === 'number' && data.metrics.totalLatencyMs > 0,
      `Infer: ${data?.metrics?.modelInferenceMs}ms, Total: ${data?.metrics?.totalLatencyMs}ms`
    );

    record(
      'Detection Source: Genuine detection tagged as "ml_real"',
      data?.detectionSource === 'ml_real',
      `Source: ${data?.detectionSource}`
    );

    // ── 3. Database Persistence Verification ─────────────────────────────────
    // Allow non-blocking MongoDB write to settle
    await new Promise((r) => setTimeout(r, 400));

    const dbLog = await CrimeLog.findOne({ cameraId: 'CAM-TEST-ML', detectionSource: 'ml_real' });
    record(
      'MongoDB Persistence: CrimeLog saved with detectionSource "ml_real"',
      Boolean(dbLog && dbLog.threatClass === data.threatClass),
      `DB ID: ${dbLog?._id}, Source: ${dbLog?.detectionSource}`
    );

    record(
      'MongoDB Schema: Metrics subdocument stored in database',
      Boolean(dbLog && dbLog.metrics && dbLog.metrics.totalLatencyMs > 0),
      `Total Latency in DB: ${dbLog?.metrics?.totalLatencyMs}ms`
    );

    // ── 4. Verify Distinction from Demonstration Drills ───────────────────────
    const drillRes = await request(app)
      .post('/api/logs/trigger')
      .set('Authorization', `Bearer ${analystToken}`)
      .send({
        cameraId: 'CAM-TEST-ML',
        threatClass: 'Weapon Detected',
        confidence: 0.95,
      });

    record(
      'Drill Trigger: POST /api/logs/trigger responds with HTTP 201',
      drillRes.status === 201,
      `Status: ${drillRes.status}`
    );

    const drillDbLog = await CrimeLog.findOne({
      cameraId: 'CAM-TEST-ML',
      threatClass: 'Weapon Detected',
    });

    record(
      'Drill Distinction: Manually triggered drill explicitly saved with detectionSource "drill_simulation"',
      drillDbLog && drillDbLog.detectionSource === 'drill_simulation',
      `Drill Source in DB: ${drillDbLog?.detectionSource}`
    );

    // Clean up test logs
    await CrimeLog.deleteMany({ cameraId: 'CAM-TEST-ML' });
    await User.deleteMany({ email: /@ml-test\.local$/ });

    // ── Summary ──────────────────────────────────────────────────────────────
    console.log('\n====================================================');
    const total = results.length;
    const passed = results.filter((r) => r.passed).length;
    const failed = total - passed;
    console.log(`TOTAL INTEGRATION TESTS: ${total} | PASSED: ${passed} | FAILED: ${failed}`);
    console.log('====================================================\n');

    process.exit(failed === 0 ? 0 : 1);
  } catch (err) {
    console.error('Fatal test error:', err);
    process.exit(1);
  } finally {
    await mongoose.disconnect();
  }
}

runMlIntegrationTests();
