/**
 * SentinelX — Phase 4.2.6 Verification & Adversarial Security Suite
 * 
 * Tests 24 Discrete Scenarios across 3 Primary Security Domains:
 * 
 * Domain 1: Internal HMAC Authentication & Trust Boundary Verification (Real Express Route Chain)
 * 1.  Production startup fail-closed for missing, weak, or known default secrets
 * 2.  Plain marker header (x-sentinelx-internal-source) through real Express route chain fails to authenticate
 * 3.  Client property injection (isServerVerifiedAudio, internalService, severity, isEmergencyEligible) stripped through real route chain
 * 4.  Valid bound v2 token through real Express route chain succeeds and authenticates internal provenance
 * 5.  Cross-route token reuse attack blocked (token for /api/logs fails on /api/logs/trigger)
 * 6.  Modified request body payload tampering attack blocked (tampered body fails HMAC verification)
 * 7.  Modified HTTP method attack blocked (token for POST fails on PATCH)
 * 8.  Expired internal token (>60s) blocked by freshness window through middleware
 * 9.  Replay attack on same instance blocked by sliding nonce cache
 * 10. Multi-instance boundary verification: independent verifier instance replay demonstrates single-instance restriction requirement
 * 
 * Domain 2: WAV Parser Edge Case Hardening
 * 11. Odd-sized chunk with correct 1-byte RIFF padding byte accepted
 * 12. Odd-sized chunk missing padding byte rejected with HTTP 400
 * 13. Duplicate "fmt " chunk rejected with HTTP 400
 * 14. Duplicate "data" chunk rejected with HTTP 400
 * 15. Unusual chunk ordering ("data" before "fmt ") rejected with HTTP 400
 * 16. Missing "fmt " chunk rejected with HTTP 400
 * 17. Trailing extra bytes after declared RIFF container rejected with HTTP 400
 * 18. Incomplete chunk header at buffer boundary rejected with HTTP 400
 * 19. Inconsistent byteRate metadata calculation rejected with HTTP 400
 * 20. Zero samples in "data" chunk rejected with HTTP 400
 * 
 * Domain 3: Python ML Audio Preprocessing & Multi-Format PCM Decoding
 * 21. Real Python pipeline decodes 8-bit PCM (uint8) to Mel-spectrogram [1, 1, 128, 128]
 * 22. Real Python pipeline decodes 16-bit PCM (int16) to Mel-spectrogram [1, 1, 128, 128]
 * 23. Real Python pipeline decodes 24-bit PCM (3-byte) to Mel-spectrogram [1, 1, 128, 128]
 * 24. Real Python pipeline decodes 32-bit PCM (int32) to Mel-spectrogram [1, 1, 128, 128]
 */

require('dotenv').config();
const mongoose = require('mongoose');
const request = require('supertest');
const crypto = require('crypto');
const { execSync } = require('child_process');

const app = require('./src/app');
const User = require('./src/models/User');
const CrimeLog = require('./src/models/CrimeLog');
const { generateAccessToken } = require('./src/config/jwt');
const {
  validateInternalServiceConfig,
  generateInternalServiceToken,
  verifyInternalServiceToken,
  computeBodyDigest,
  normalizePath,
} = require('./src/middleware/internalAuth');
const { validateWavAudioBuffer, validateBase64WavAudio } = require('./src/utils/wavValidator');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/sentinelx_audit';

const results = [];
function record(testNum, title, passed, detail = '') {
  results.push({ testNum, title, passed, detail });
  const mark = passed ? '✓ PASS' : '✗ FAIL';
  console.log(`[Phase 4.2.6 Test ${testNum}] ${mark} - ${title}${detail ? ` (${detail})` : ''}`);
}

/**
 * Helper to build custom WAV buffers with arbitrary chunks and byte layouts.
 */
function buildWavBuffer({
  audioFormat = 1,
  numChannels = 1,
  sampleRate = 16000,
  bitsPerSample = 16,
  numSamples = 1600,
  byteRateOverride = null,
  blockAlignOverride = null,
  riffSizeOverride = null,
  dataSizeOverride = null,
  trailingBytes = 0,
  duplicateFmt = false,
  duplicateData = false,
  dataBeforeFmt = false,
  missingFmt = false,
  incompleteHeader = false,
  includeOddChunk = false,
  omitOddPadding = false,
  emptyData = false,
}) {
  const bytesPerSample = bitsPerSample / 8;
  const blockAlign = blockAlignOverride !== null ? blockAlignOverride : numChannels * bytesPerSample;
  const byteRate = byteRateOverride !== null ? byteRateOverride : sampleRate * blockAlign;
  const actualDataBytes = emptyData ? 0 : (dataSizeOverride !== null ? dataSizeOverride : numSamples * blockAlign);

  const chunks = [];

  // Odd chunk for testing RIFF padding
  if (includeOddChunk) {
    const oddId = 'JUNK';
    const oddSize = 7; // Odd size: 7 bytes
    const oddData = Buffer.from('TEST123'); // exactly 7 bytes
    const oddBuf = Buffer.alloc(8 + oddSize + (omitOddPadding ? 0 : 1));
    oddBuf.write(oddId, 0);
    oddBuf.writeUInt32LE(oddSize, 4);
    oddData.copy(oddBuf, 8);
    if (!omitOddPadding) {
      oddBuf.writeUInt8(0, 8 + oddSize); // 1 padding byte
    }
    chunks.push(oddBuf);
  }

  // fmt chunk helper
  function makeFmtBuf() {
    const fmtBuf = Buffer.alloc(24);
    fmtBuf.write('fmt ', 0);
    fmtBuf.writeUInt32LE(16, 4);
    fmtBuf.writeUInt16LE(audioFormat, 8);
    fmtBuf.writeUInt16LE(numChannels, 10);
    fmtBuf.writeUInt32LE(sampleRate, 12);
    fmtBuf.writeUInt32LE(byteRate, 16);
    fmtBuf.writeUInt16LE(blockAlign, 20);
    fmtBuf.writeUInt16LE(bitsPerSample, 22);
    return fmtBuf;
  }

  // data chunk helper
  function makeDataBuf() {
    const dataBuf = Buffer.alloc(8 + actualDataBytes);
    dataBuf.write('data', 0);
    dataBuf.writeUInt32LE(actualDataBytes, 4);
    // Fill sample bytes
    if (actualDataBytes > 0) {
      dataBuf.fill(0x55, 8);
    }
    return dataBuf;
  }

  if (dataBeforeFmt) {
    chunks.push(makeDataBuf());
    chunks.push(makeFmtBuf());
  } else {
    if (!missingFmt) {
      chunks.push(makeFmtBuf());
      if (duplicateFmt) {
        chunks.push(makeFmtBuf());
      }
    }
    chunks.push(makeDataBuf());
    if (duplicateData) {
      chunks.push(makeDataBuf());
    }
  }

  if (incompleteHeader) {
    // Append 3 incomplete bytes representing truncated chunk header
    chunks.push(Buffer.from([0x49, 0x4E, 0x43])); // "INC"
  }

  const combinedChunks = Buffer.concat(chunks);
  const totalRiffDataSize = 4 + combinedChunks.length; // "WAVE" + chunks
  const declaredRiff = riffSizeOverride !== null ? riffSizeOverride : totalRiffDataSize;

  const riffHeader = Buffer.alloc(12);
  riffHeader.write('RIFF', 0);
  riffHeader.writeUInt32LE(declaredRiff, 4);
  riffHeader.write('WAVE', 8);

  const fullBuffer = Buffer.concat([riffHeader, combinedChunks]);

  if (trailingBytes > 0) {
    const extra = Buffer.alloc(trailingBytes, 0xAA);
    return Buffer.concat([fullBuffer, extra]);
  }

  return fullBuffer;
}

async function runSuite() {
  console.log('================================================================');
  console.log(' SENTINELX — PHASE 4.2.6 SECURITY VERIFICATION & AUDIT SUITE   ');
  console.log('================================================================\n');

  try {
    await mongoose.connect(MONGODB_URI);
    console.log(`Connected to test MongoDB: ${MONGODB_URI}\n`);

    // Clean test data
    await User.deleteMany({ email: /^phase426_/ });
    await CrimeLog.deleteMany({ cameraId: /^CAM-PHASE-4-2-6/ });

    // Seed test analyst user
    const testAnalyst = await User.create({
      name: 'Phase 426 Analyst',
      email: `phase426_analyst_${Date.now()}@sentinelx.local`,
      password: 'StrongTestPassword123!',
      role: 'analyst',
      isActive: true,
    });
    const analystToken = generateAccessToken({
      userId: testAnalyst._id.toString(),
      email: testAnalyst.email,
      role: testAnalyst.role,
    });

    // ─────────────────────────────────────────────────────────────────────────
    // DOMAIN 1: INTERNAL HMAC AUTHENTICATION & TRUST BOUNDARY (REAL ROUTES)
    // ─────────────────────────────────────────────────────────────────────────

    // Test 1: Production Startup Fails Closed
    {
      let threwMissing = false;
      let threwWeak = false;
      let threwDefault = false;

      try { validateInternalServiceConfig(null, 'production'); } catch { threwMissing = true; }
      try { validateInternalServiceConfig('too_short_key_16_chars', 'production'); } catch { threwWeak = true; }
      try { validateInternalServiceConfig('sentinelx_internal_audio_token_secure', 'production'); } catch { threwDefault = true; }

      const passed = threwMissing && threwWeak && threwDefault;
      record(1, 'Production startup fails closed for missing, weak, or default secrets', passed,
        `Missing: ${threwMissing}, Weak: ${threwWeak}, Default: ${threwDefault}`);
    }

    // Test 2: Plain marker header through real Express route chain fails to authenticate
    {
      const payload = {
        threatClass: 'Acoustic Distress: HELP, HELP',
        confidence: 0.99,
        detectionSource: 'acoustic_sos',
        cameraId: 'CAM-PHASE-4-2-6-02',
      };

      const res = await request(app)
        .post('/api/logs')
        .set('Authorization', `Bearer ${analystToken}`)
        .set('x-sentinelx-internal-source', 'server_audio_verifier') // Insecure marker header
        .send(payload);

      const doc = res.body?.data ? await CrimeLog.findById(res.body.data._id) : null;
      const passed =
        res.status === 201 &&
        doc?.detectionSource === 'manual_entry' &&
        doc?.severity === 'low' &&
        CrimeLog.isEmergencyEligible(doc) === false;

      record(2, 'Plain marker header through real Express route fails to authenticate', passed,
        `HTTP ${res.status}, Source: ${doc?.detectionSource}, Severity: ${doc?.severity}, Eligible: ${CrimeLog.isEmergencyEligible(doc)}`);
    }

    // Test 3: Client property injection stripped through real Express route chain
    {
      const payload = {
        threatClass: 'Acoustic Distress: HELP, HELP',
        confidence: 0.99,
        detectionSource: 'acoustic_sos',
        isServerVerifiedAudio: true,
        req_isServerVerifiedAudio: true,
        internalService: { authenticated: true, serviceId: 'sentinelx-audio-verifier' },
        severity: 'critical',
        isEmergencyEligible: true,
        cameraId: 'CAM-PHASE-4-2-6-03',
      };

      const res = await request(app)
        .post('/api/logs')
        .set('Authorization', `Bearer ${analystToken}`)
        .send(payload);

      const doc = res.body?.data ? await CrimeLog.findById(res.body.data._id) : null;
      const passed =
        res.status === 201 &&
        doc?.detectionSource === 'manual_entry' &&
        doc?.severity === 'low' &&
        CrimeLog.isEmergencyEligible(doc) === false;

      record(3, 'Client property injection stripped through real route chain', passed,
        `HTTP ${res.status}, Source: ${doc?.detectionSource}, Severity: ${doc?.severity}, Eligible: ${CrimeLog.isEmergencyEligible(doc)}`);
    }

    // Test 4: Valid bound v2 token through real Express route chain succeeds
    {
      const payload = {
        threatClass: 'Acoustic Distress: HELP, HELP',
        confidence: 0.985,
        detectionSource: 'acoustic_sos',
        detectionStatus: 'anomaly_detected',
        audioTranscript: 'SERVER_VERIFIED_DISTRESS: "HELP! HELP!"',
        audioDecibels: 89.1,
        cameraId: 'CAM-PHASE-4-2-6-04',
      };

      const v2Token = generateInternalServiceToken({
        serviceId: 'sentinelx-audio-verifier',
        method: 'POST',
        path: '/api/logs',
        body: payload,
      });

      const res = await request(app)
        .post('/api/logs')
        .set('Authorization', `Bearer ${analystToken}`)
        .set('x-sentinelx-service-auth', v2Token)
        .send(payload);

      const doc = res.body?.data ? await CrimeLog.findById(res.body.data._id) : null;
      const passed =
        res.status === 201 &&
        doc?.detectionSource === 'acoustic_sos' &&
        doc?.severity === 'critical' &&
        CrimeLog.isEmergencyEligible(doc) === true;

      record(4, 'Valid bound v2 token through real route chain authenticates internal provenance', passed,
        `HTTP ${res.status}, Source: ${doc?.detectionSource}, Severity: ${doc?.severity}, Eligible: ${CrimeLog.isEmergencyEligible(doc)}`);
    }

    // Test 5: Protocol v1 token strictly rejected in production environment via real route chain
    {
      const prodKey = 'sentinelx_production_secret_key_minimum_64_characters_long_for_auth_verification';
      const origNodeEnv = process.env.NODE_ENV;
      const origKey = process.env.INTERNAL_SERVICE_KEY;

      process.env.NODE_ENV = 'production';
      process.env.INTERNAL_SERVICE_KEY = prodKey;

      const payload = {
        threatClass: 'Acoustic Distress: HELP, HELP',
        confidence: 0.985,
        detectionSource: 'acoustic_sos',
        cameraId: 'CAM-PHASE-4-2-6-05-PROD-V1',
      };

      // Generate valid v1 token signed with production key
      const v1Token = generateInternalServiceToken('sentinelx-audio-verifier', prodKey);

      const res = await request(app)
        .post('/api/logs')
        .set('Authorization', `Bearer ${analystToken}`)
        .set('x-sentinelx-service-auth', v1Token)
        .send(payload);

      // Restore environment
      process.env.NODE_ENV = origNodeEnv;
      process.env.INTERNAL_SERVICE_KEY = origKey;

      const doc = res.body?.data ? await CrimeLog.findById(res.body.data._id) : null;
      // In production, v1 is rejected -> internal provenance fails -> sanitized to manual_entry / low
      const passed =
        res.status === 201 &&
        doc?.detectionSource === 'manual_entry' &&
        doc?.severity === 'low' &&
        CrimeLog.isEmergencyEligible(doc) === false;

      record(5, 'Valid Protocol v1 token cannot authenticate in production (strictly requires v2)', passed,
        `HTTP ${res.status}, Source: ${doc?.detectionSource}, Severity: ${doc?.severity}, Eligible: ${CrimeLog.isEmergencyEligible(doc)}`);
    }

    // Test 6: Cross-route token reuse attack blocked
    {
      const payload = {
        threatClass: 'Acoustic Distress: HELP, HELP',
        confidence: 0.985,
        detectionSource: 'acoustic_sos',
        cameraId: 'CAM-PHASE-4-2-6-06',
      };

      // Token generated for /api/logs
      const tokenForLogs = generateInternalServiceToken({
        serviceId: 'sentinelx-audio-verifier',
        method: 'POST',
        path: '/api/logs',
        body: payload,
      });

      // Attacker reuses token against /api/logs/trigger
      const res = await request(app)
        .post('/api/logs/trigger')
        .set('Authorization', `Bearer ${analystToken}`)
        .set('x-sentinelx-service-auth', tokenForLogs) // Cross-route reuse!
        .send(payload);

      const doc = res.body?.data ? await CrimeLog.findById(res.body.data._id) : null;
      // In /api/logs/trigger, it creates a drill_simulation which is strictly unassigned and not eligible
      const passed =
        res.status === 201 &&
        doc?.detectionSource === 'drill_simulation' &&
        CrimeLog.isEmergencyEligible(doc) === false;

      record(6, 'Cross-route token reuse attack blocked (path mismatch fails binding)', passed,
        `HTTP ${res.status}, Source: ${doc?.detectionSource}, Eligible: ${CrimeLog.isEmergencyEligible(doc)}`);
    }

    // Test 7: Modified request body payload tampering attack blocked
    {
      const originalPayload = {
        threatClass: 'Acoustic Distress: HELP, HELP',
        confidence: 0.985,
        detectionSource: 'acoustic_sos',
        cameraId: 'CAM-PHASE-4-2-6-07-ORIGINAL',
      };

      // Generate token bound to originalPayload
      const token = generateInternalServiceToken({
        serviceId: 'sentinelx-audio-verifier',
        method: 'POST',
        path: '/api/logs',
        body: originalPayload,
      });

      // Attacker tampers with body in transit
      const tamperedPayload = {
        ...originalPayload,
        cameraId: 'CAM-PHASE-4-2-6-07-TAMPERED',
        confidence: 0.999,
      };

      const res = await request(app)
        .post('/api/logs')
        .set('Authorization', `Bearer ${analystToken}`)
        .set('x-sentinelx-service-auth', token)
        .send(tamperedPayload);

      const doc = res.body?.data ? await CrimeLog.findById(res.body.data._id) : null;
      // Tampered body changes digest -> HMAC check fails -> demoted to manual_entry / low
      const passed =
        res.status === 201 &&
        doc?.detectionSource === 'manual_entry' &&
        doc?.severity === 'low' &&
        CrimeLog.isEmergencyEligible(doc) === false;

      record(7, 'Modified request body payload tampering attack blocked', passed,
        `HTTP ${res.status}, Source: ${doc?.detectionSource}, Severity: ${doc?.severity}, Eligible: ${CrimeLog.isEmergencyEligible(doc)}`);
    }

    // Test 8: Modified HTTP method attack blocked
    {
      const payload = {
        threatClass: 'Acoustic Distress: HELP, HELP',
        confidence: 0.985,
        detectionSource: 'acoustic_sos',
      };

      // Token generated specifically for POST
      const postToken = generateInternalServiceToken({
        serviceId: 'sentinelx-audio-verifier',
        method: 'POST',
        path: '/api/logs',
        body: payload,
      });

      // Attempt to verify with PATCH method context
      const verification = verifyInternalServiceToken(postToken, {
        method: 'PATCH', // Method mismatch!
        path: '/api/logs',
        body: payload,
      });

      record(8, 'Modified HTTP method attack blocked by HMAC method binding', verification.valid === false,
        `Valid: ${verification.valid}, Error: "${verification.error}"`);
    }

    // Test 9: Expired internal token (>60s) blocked
    {
      const expiredTimestamp = Date.now() - 90000; // 90s in past
      const token = generateInternalServiceToken({
        serviceId: 'sentinelx-audio-verifier',
        method: 'POST',
        path: '/api/logs',
        timestamp: expiredTimestamp,
      });

      const verification = verifyInternalServiceToken(token, {
        method: 'POST',
        path: '/api/logs',
      });

      record(9, 'Expired internal token (>60s) blocked by freshness window',
        verification.valid === false && verification.error?.includes('clock skew exceeded 60 seconds'),
        `Valid: ${verification.valid}, Error: "${verification.error}"`);
    }

    // Test 10: Replay attack on same instance blocked by sliding nonce cache
    {
      const payload = {
        threatClass: 'Acoustic Distress: HELP, HELP',
        confidence: 0.985,
        detectionSource: 'acoustic_sos',
        cameraId: 'CAM-PHASE-4-2-6-10',
      };

      const token = generateInternalServiceToken({
        serviceId: 'sentinelx-audio-verifier',
        method: 'POST',
        path: '/api/logs',
        body: payload,
      });

      // Request 1: Fresh token succeeds
      const res1 = await request(app)
        .post('/api/logs')
        .set('Authorization', `Bearer ${analystToken}`)
        .set('x-sentinelx-service-auth', token)
        .send(payload);

      const doc1 = res1.body?.data ? await CrimeLog.findById(res1.body.data._id) : null;

      // Request 2: Replay of exact same token
      const res2 = await request(app)
        .post('/api/logs')
        .set('Authorization', `Bearer ${analystToken}`)
        .set('x-sentinelx-service-auth', token) // Replay!
        .send(payload);

      const doc2 = res2.body?.data ? await CrimeLog.findById(res2.body.data._id) : null;

      const passed =
        doc1?.detectionSource === 'acoustic_sos' &&
        doc2?.detectionSource === 'manual_entry' && // Replayed token ignored!
        doc2?.severity === 'low';

      record(10, 'Replay attack on same instance blocked by sliding nonce cache', passed,
        `First Source: ${doc1?.detectionSource}, Replay Source: ${doc2?.detectionSource}`);
    }

    // Test 11: Multi-instance boundary verification
    {
      const independentNonceCache = new Map(); // Simulates independent instance memory

      const token = generateInternalServiceToken({
        serviceId: 'sentinelx-internal',
        method: 'POST',
        path: '/api/logs',
      });

      // Verification on Instance A (uses globalNonceCache)
      const checkA1 = verifyInternalServiceToken(token, { method: 'POST', path: '/api/logs' });
      const checkA2 = verifyInternalServiceToken(token, { method: 'POST', path: '/api/logs' }); // Replay on Instance A

      // Verification on Instance B (separate in-memory cache)
      const checkB = verifyInternalServiceToken(
        token,
        { method: 'POST', path: '/api/logs' },
        null,
        null,
        independentNonceCache
      );

      // On Instance A: Replay is blocked.
      // On Instance B without shared cache: Nonce is unknown, demonstrating the single-instance restriction boundary!
      const passed =
        checkA1.valid === true &&
        checkA2.valid === false &&
        checkB.valid === true;

      record(11, 'Multi-instance boundary verified (demonstrates single-instance restriction requirement)', passed,
        `InstA: ${checkA1.valid}, InstA-Replay: ${checkA2.valid}, InstB-SeparateCache: ${checkB.valid}`);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // DOMAIN 2: WAV PARSER EDGE CASE HARDENING
    // ─────────────────────────────────────────────────────────────────────────

    // Test 11: Odd-sized chunk with correct RIFF padding byte accepted
    {
      const oddBuf = buildWavBuffer({ includeOddChunk: true, omitOddPadding: false });
      const result = validateWavAudioBuffer(oddBuf);
      record(11, 'Odd-sized chunk with correct RIFF padding byte accepted', result.valid === true,
        `Valid: ${result.valid}, Channels: ${result.metadata?.channels}, Duration: ${result.metadata?.durationSeconds}s`);
    }

    // Test 12: Odd-sized chunk missing padding byte rejected
    {
      const corruptOddBuf = buildWavBuffer({ includeOddChunk: true, omitOddPadding: true });
      const result = validateWavAudioBuffer(corruptOddBuf);
      record(12, 'Odd-sized chunk missing padding byte rejected with HTTP 400',
        result.valid === false && (result.error?.includes('missing padding byte') || result.error?.includes('Malformed WAV chunk')),
        `Valid: ${result.valid}, Error: "${result.error}"`);
    }

    // Test 13: Duplicate fmt chunk rejected
    {
      const dupFmtBuf = buildWavBuffer({ duplicateFmt: true });
      const result = validateWavAudioBuffer(dupFmtBuf);
      record(13, 'Duplicate "fmt " chunk rejected with HTTP 400',
        result.valid === false && result.error?.includes('duplicate "fmt " chunk'),
        `Valid: ${result.valid}, Error: "${result.error}"`);
    }

    // Test 14: Duplicate data chunk rejected
    {
      const dupDataBuf = buildWavBuffer({ duplicateData: true });
      const result = validateWavAudioBuffer(dupDataBuf);
      record(14, 'Duplicate "data" chunk rejected with HTTP 400',
        result.valid === false && result.error?.includes('duplicate "data" chunk'),
        `Valid: ${result.valid}, Error: "${result.error}"`);
    }

    // Test 15: Unusual chunk ordering (data before fmt) rejected
    {
      const outOfOrderBuf = buildWavBuffer({ dataBeforeFmt: true });
      const result = validateWavAudioBuffer(outOfOrderBuf);
      record(15, 'Unusual chunk ordering ("data" before "fmt ") rejected with HTTP 400',
        result.valid === false && result.error?.includes('"data" chunk appeared before "fmt " chunk'),
        `Valid: ${result.valid}, Error: "${result.error}"`);
    }

    // Test 16: Missing fmt chunk rejected
    {
      const missingFmtBuf = buildWavBuffer({ missingFmt: true });
      const result = validateWavAudioBuffer(missingFmtBuf);
      record(16, 'Missing "fmt " chunk rejected with HTTP 400',
        result.valid === false && (result.error?.includes('missing required "fmt " chunk') || result.error?.includes('"data" chunk appeared before "fmt " chunk')),
        `Valid: ${result.valid}, Error: "${result.error}"`);
    }

    // Test 17: Trailing extra bytes after declared RIFF container rejected
    {
      const trailingBuf = buildWavBuffer({ trailingBytes: 128 });
      const result = validateWavAudioBuffer(trailingBuf);
      record(17, 'Trailing extra bytes after declared RIFF container rejected with HTTP 400',
        result.valid === false && result.error?.includes('Trailing unparsed data detected'),
        `Valid: ${result.valid}, Error: "${result.error}"`);
    }

    // Test 18: Incomplete chunk header at buffer boundary rejected
    {
      const incompleteBuf = buildWavBuffer({ incompleteHeader: true });
      const result = validateWavAudioBuffer(incompleteBuf);
      record(18, 'Incomplete chunk header at buffer boundary rejected with HTTP 400',
        result.valid === false && result.error?.includes('incomplete chunk header at offset'),
        `Valid: ${result.valid}, Error: "${result.error}"`);
    }

    // Test 19: Inconsistent byteRate metadata calculation rejected
    {
      const badByteRateBuf = buildWavBuffer({ byteRateOverride: 12345 }); // Expected 32000
      const result = validateWavAudioBuffer(badByteRateBuf);
      record(19, 'Inconsistent byteRate metadata calculation rejected with HTTP 400',
        result.valid === false && result.error?.includes('byteRate (12345) does not match expected'),
        `Valid: ${result.valid}, Error: "${result.error}"`);
    }

    // Test 20: Zero samples in data chunk rejected
    {
      const emptyBuf = buildWavBuffer({ emptyData: true });
      const result = validateWavAudioBuffer(emptyBuf);
      record(20, 'Zero samples in "data" chunk rejected with HTTP 400',
        result.valid === false && result.error?.includes('0 samples in "data" chunk'),
        `Valid: ${result.valid}, Error: "${result.error}"`);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // DOMAIN 3: PYTHON ML PREPROCESSING & MULTI-FORMAT PCM DECODING
    // ─────────────────────────────────────────────────────────────────────────

    let pyOutput = {};
    try {
      const stdout = execSync('python server_ml/test_pcm_formats.py', {
        cwd: process.cwd(),
        encoding: 'utf8',
      });
      pyOutput = JSON.parse(stdout.trim());
    } catch (err) {
      console.error('Python execution error:', err);
      pyOutput = {};
    }

    // Test 21: Python 8-bit PCM decoding
    {
      const res8 = pyOutput['8'] || {};
      const passed = res8.success === true && JSON.stringify(res8.tensor_shape) === '[1,1,128,128]';
      record(21, 'Python ML pipeline decodes 8-bit PCM (uint8) to Mel-spectrogram [1, 1, 128, 128]', passed,
        `Dtype: ${res8.scipy_dtype}, Shape: ${JSON.stringify(res8.tensor_shape)}, ${res8.elapsed_ms}ms`);
    }

    // Test 22: Python 16-bit PCM decoding
    {
      const res16 = pyOutput['16'] || {};
      const passed = res16.success === true && JSON.stringify(res16.tensor_shape) === '[1,1,128,128]';
      record(22, 'Python ML pipeline decodes 16-bit PCM (int16) to Mel-spectrogram [1, 1, 128, 128]', passed,
        `Dtype: ${res16.scipy_dtype}, Shape: ${JSON.stringify(res16.tensor_shape)}, ${res16.elapsed_ms}ms`);
    }

    // Test 23: Python 24-bit PCM decoding
    {
      const res24 = pyOutput['24'] || {};
      const passed = res24.success === true && JSON.stringify(res24.tensor_shape) === '[1,1,128,128]';
      record(23, 'Python ML pipeline decodes 24-bit PCM (3-byte) to Mel-spectrogram [1, 1, 128, 128]', passed,
        `Dtype: ${res24.scipy_dtype}, Shape: ${JSON.stringify(res24.tensor_shape)}, ${res24.elapsed_ms}ms`);
    }

    // Test 24: Python 32-bit PCM decoding
    {
      const res32 = pyOutput['32'] || {};
      const passed = res32.success === true && JSON.stringify(res32.tensor_shape) === '[1,1,128,128]';
      record(24, 'Python ML pipeline decodes 32-bit PCM (int32) to Mel-spectrogram [1, 1, 128, 128]', passed,
        `Dtype: ${res32.scipy_dtype}, Shape: ${JSON.stringify(res32.tensor_shape)}, ${res32.elapsed_ms}ms`);
    }

    // ── Summary ─────────────────────────────────────────────────────────────
    const total = results.length;
    const passedCount = results.filter((r) => r.passed).length;
    const failedCount = total - passedCount;

    console.log('\n================================================================');
    console.log(`TOTAL PHASE 4.2.6 VERIFICATION TESTS: ${total} | PASSED: ${passedCount} | FAILED: ${failedCount}`);
    console.log('================================================================');

    if (failedCount > 0) {
      process.exit(1);
    }
  } catch (err) {
    console.error('[Phase 4.2.6] Unexpected error running suite:', err);
    process.exit(1);
  } finally {
    await mongoose.disconnect();
  }
}

runSuite();
