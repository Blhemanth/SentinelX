/**
 * SentinelX — Phase 4.2.3 Dispatch Isolation & Safety Verification Suite
 * Tests:
 * 1. Critical drill simulation can NEVER be emergency eligible.
 * 2. High-confidence drill simulation can NEVER be emergency eligible.
 * 3. Manual dispatch attempt on drill simulation via updateDispatchStatus returns 400 Bad Request.
 * 4. Drill simulation submitted with assigned_police on creation is clamped to unassigned.
 * 5. Client attempt to spoof detectionSource: 'ml_real' via createLog is sanitized to manual_entry.
 * 6. Client attempt to spoof detectionSource: 'acoustic_sos' on non-acoustic threat is sanitized.
 * 7. Client attempt to spoof detectionSource: 'acoustic_sos' without audio evidence is sanitized.
 * 8. Genuine Acoustic SOS with valid distress keywords and audio transcript retains critical emergency eligibility.
 * 9. Genuine verified ml_real anomaly at >=0.85 retains critical emergency eligibility.
 * 10. Normal prediction at 0.99 confidence is never emergency eligible.
 * 11. Subprocess fallback at 0.99 confidence is never emergency eligible.
 * 12. Legacy unclassified at 0.99 confidence is never emergency eligible.
 * 13. Boundary 0.49 -> low severity, not emergency eligible.
 * 14. Boundary 0.50 -> medium severity, not emergency eligible.
 * 15. Boundary 0.70 -> high severity, not emergency eligible.
 * 16. Boundary 0.849 -> high severity, not emergency eligible.
 * 17. Boundary 0.85 -> critical severity, emergency eligible (ml_real).
 */

require('dotenv').config();
const mongoose = require('mongoose');
const CrimeLog = require('./src/models/CrimeLog');
const { createLog, updateDispatchStatus } = require('./src/controllers/logs.controller');
const { generateInternalServiceToken } = require('./src/middleware/internalAuth');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/sentinelx_audit';

const results = [];
function record(testCode, description, passed, detail = '') {
  results.push({ testCode, description, passed, detail });
  const status = passed ? '✓ PASS' : '✗ FAIL';
  console.log(`[Phase 4.2.3 Test ${testCode}] ${status} - ${description}${detail ? ` (${detail})` : ''}`);
}

// Mock Express response helper
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

async function runPhase423Suite() {
  console.log('========================================================');
  console.log(' SENTINELX - PHASE 4.2.3 DISPATCH ISOLATION & SAFETY SUITE');
  console.log('========================================================\n');

  try {
    await mongoose.connect(MONGODB_URI);
    console.log(`Connected to test MongoDB: ${MONGODB_URI}\n`);

    await CrimeLog.deleteMany({ cameraId: 'CAM-PHASE-4-2-3' });

    // ── Test 1: Critical Drill Simulation is NEVER Emergency Eligible ───────
    const critDrill = await CrimeLog.create({
      threatClass: 'Explosion',
      confidence: 0.99,
      detectionStatus: 'anomaly_detected',
      detectionSource: 'drill_simulation',
      cameraId: 'CAM-PHASE-4-2-3',
      frameTimestamp: new Date(),
    });
    const critDrillEligible = CrimeLog.isEmergencyEligible(critDrill);
    record(
      '1',
      'Critical drill simulation is strictly isolated from emergency dispatch',
      critDrillEligible === false && critDrill.severity === 'critical',
      `Severity: ${critDrill.severity}, EmergencyEligible: ${critDrillEligible} (Expected: false)`
    );

    // ── Test 2: High-Confidence Drill Simulation is NEVER Emergency Eligible ──
    const highConfDrill = await CrimeLog.create({
      threatClass: 'Fighting',
      confidence: 0.88,
      detectionStatus: 'anomaly_detected',
      detectionSource: 'drill_simulation',
      cameraId: 'CAM-PHASE-4-2-3',
      frameTimestamp: new Date(),
    });
    const highDrillEligible = CrimeLog.isEmergencyEligible(highConfDrill);
    record(
      '2',
      'High-confidence drill simulation is strictly isolated from emergency dispatch',
      highDrillEligible === false,
      `EmergencyEligible: ${highDrillEligible} (Expected: false)`
    );

    // ── Test 3: Manual Dispatch Attempt on Drill Simulation via API Returns 400 ─
    const reqDispatch = {
      params: { id: critDrill._id.toString() },
      body: {
        dispatchStatus: 'assigned_police',
        assignedTo: 'Unit 104',
        policeNotes: 'Attempting to dispatch drill simulation',
      },
    };
    const resDispatch = createMockRes();
    await updateDispatchStatus(reqDispatch, resDispatch);
    record(
      '3',
      'Attempt to dispatch drill simulation to police returns HTTP 400 Bad Request',
      resDispatch.statusCode === 400 && resDispatch.body.success === false,
      `HTTP Status: ${resDispatch.statusCode}, Error: "${resDispatch.body?.error}"`
    );

    // ── Test 4: Drill Simulation Submitted with assigned_police is Clamped ────
    const reqCreateDrill = {
      body: {
        threatClass: 'Explosion',
        confidence: 0.92,
        detectionSource: 'drill_simulation',
        detectionStatus: 'anomaly_detected',
        dispatchStatus: 'assigned_police',
        cameraId: 'CAM-PHASE-4-2-3',
      },
    };
    const resCreateDrill = createMockRes();
    await createLog(reqCreateDrill, resCreateDrill);
    const createdDrill = resCreateDrill.body?.data;
    record(
      '4',
      'Drill simulation created with assigned_police is clamped to unassigned',
      resCreateDrill.statusCode === 201 && createdDrill?.dispatchStatus === 'unassigned',
      `DispatchStatus: "${createdDrill?.dispatchStatus}" (Expected: 'unassigned')`
    );

    // ── Test 5: Client Attempt to Spoof ml_real is Sanitized to manual_entry ──
    const reqSpoofMl = {
      body: {
        threatClass: 'Explosion',
        confidence: 0.99,
        detectionSource: 'ml_real', // Untrusted REST claim without /api/detect
        detectionStatus: 'anomaly_detected',
        cameraId: 'CAM-PHASE-4-2-3',
      },
    };
    const resSpoofMl = createMockRes();
    await createLog(reqSpoofMl, resSpoofMl);
    const spoofedMlDoc = resSpoofMl.body?.data;
    const spoofMlEligible = CrimeLog.isEmergencyEligible(spoofedMlDoc);
    record(
      '5',
      'Client attempt to spoof ml_real via POST /api/logs sanitized to manual_entry',
      spoofedMlDoc?.detectionSource === 'manual_entry' && spoofMlEligible === false,
      `Sanitized Source: "${spoofedMlDoc?.detectionSource}", EmergencyEligible: ${spoofMlEligible}`
    );

    // ── Test 6: Client Spoofing acoustic_sos on Non-Acoustic Threat Sanitized ─
    const reqSpoofAcoustic = {
      body: {
        threatClass: 'Explosion', // Invalid acoustic class
        confidence: 0.99,
        detectionSource: 'acoustic_sos',
        detectionStatus: 'anomaly_detected',
        cameraId: 'CAM-PHASE-4-2-3',
      },
    };
    const resSpoofAcoustic = createMockRes();
    await createLog(reqSpoofAcoustic, resSpoofAcoustic);
    const spoofedAcousticDoc = resSpoofAcoustic.body?.data;
    const spoofAcousticEligible = CrimeLog.isEmergencyEligible(spoofedAcousticDoc);
    record(
      '6',
      'Acoustic SOS claim on non-acoustic threat sanitized to manual_entry',
      spoofedAcousticDoc?.detectionSource === 'manual_entry' && spoofAcousticEligible === false,
      `Sanitized Source: "${spoofedAcousticDoc?.detectionSource}", EmergencyEligible: ${spoofAcousticEligible}`
    );

    // ── Test 7: Acoustic SOS Claim Without Audio Distress Evidence Sanitized ──
    const reqNoEvidenceAcoustic = {
      body: {
        threatClass: 'Acoustic Distress: HELP, HELP',
        confidence: 0.95,
        detectionSource: 'acoustic_sos',
        detectionStatus: 'anomaly_detected',
        audioTranscript: 'Quiet conversation in hallway', // Missing distress keywords
        audioDecibels: 42.0, // Low decibels
        cameraId: 'CAM-PHASE-4-2-3',
      },
    };
    const resNoEvidence = createMockRes();
    await createLog(reqNoEvidenceAcoustic, resNoEvidence);
    const noEvidenceDoc = resNoEvidence.body?.data;
    const noEvidenceEligible = CrimeLog.isEmergencyEligible(noEvidenceDoc);
    record(
      '7',
      'Acoustic SOS claim without audio evidence sanitized to manual_entry',
      noEvidenceDoc?.detectionSource === 'manual_entry' && noEvidenceEligible === false,
      `Sanitized Source: "${noEvidenceDoc?.detectionSource}", EmergencyEligible: ${noEvidenceEligible}`
    );

    // ── Test 8: Genuine Acoustic SOS Authenticated with Distress Evidence ────
    const reqGenuineAcoustic = {
      headers: {
        'x-sentinelx-service-auth': generateInternalServiceToken('sentinelx-audio-verifier'),
      },
      body: {
        threatClass: 'Acoustic Distress: HELP, HELP',
        confidence: 0.985,
        detectionSource: 'acoustic_sos',
        detectionStatus: 'anomaly_detected',
        audioTranscript: 'CRITICAL DISTRESS: "HELP! HELP! EMERGENCY AT SECTOR GATE"',
        audioDecibels: 88.4,
        cameraId: 'CAM-PHASE-4-2-3',
      },
    };
    const resGenuineAcoustic = createMockRes();
    await createLog(reqGenuineAcoustic, resGenuineAcoustic);
    const genuineAcousticDoc = resGenuineAcoustic.body?.data;
    const genuineAcousticEligible = CrimeLog.isEmergencyEligible(genuineAcousticDoc);
    record(
      '8',
      'Genuine Acoustic SOS with distress evidence authenticated and emergency eligible',
      genuineAcousticDoc?.detectionSource === 'acoustic_sos' &&
      genuineAcousticDoc?.severity === 'critical' &&
      genuineAcousticEligible === true,
      `Source: "${genuineAcousticDoc?.detectionSource}", Severity: "${genuineAcousticDoc?.severity}", EmergencyEligible: ${genuineAcousticEligible}`
    );

    // ── Test 9: Genuine ml_real Anomaly at >=0.85 Retains Emergency Eligibility
    const genuineMlDoc = await CrimeLog.create({
      threatClass: 'Explosion',
      confidence: 0.88,
      detectionStatus: 'anomaly_detected',
      detectionSource: 'ml_real',
      cameraId: 'CAM-PHASE-4-2-3',
      frameTimestamp: new Date(),
    });
    const genuineMlEligible = CrimeLog.isEmergencyEligible(genuineMlDoc);
    record(
      '9',
      'Genuine ml_real anomaly at >=0.85 retains emergency dispatch eligibility',
      genuineMlDoc.severity === 'critical' && genuineMlEligible === true,
      `Severity: "${genuineMlDoc.severity}", EmergencyEligible: ${genuineMlEligible}`
    );

    // ── Test 10: Normal Prediction at 0.99 Confidence is NEVER Emergency Eligible
    const normalDoc = await CrimeLog.create({
      threatClass: 'Normal',
      confidence: 0.99,
      detectionStatus: 'normal',
      detectionSource: 'ml_real',
      cameraId: 'CAM-PHASE-4-2-3',
      frameTimestamp: new Date(),
    });
    const normalEligible = CrimeLog.isEmergencyEligible(normalDoc);
    record(
      '10',
      'Normal prediction at 0.99 confidence is clamped to normal and not eligible',
      normalDoc.severity === 'normal' && normalEligible === false,
      `Severity: "${normalDoc.severity}", EmergencyEligible: ${normalEligible}`
    );

    // ── Test 11: Subprocess Fallback at 0.99 is NEVER Emergency Eligible ─────
    const fallbackDoc = await CrimeLog.create({
      threatClass: 'Gunshot',
      confidence: 0.99,
      detectionStatus: 'subprocess_fallback',
      detectionSource: 'subprocess_fallback',
      cameraId: 'CAM-PHASE-4-2-3',
      frameTimestamp: new Date(),
    });
    const fallbackEligible = CrimeLog.isEmergencyEligible(fallbackDoc);
    record(
      '11',
      'Subprocess fallback at 0.99 confidence is clamped to low and not eligible',
      fallbackDoc.severity === 'low' && fallbackEligible === false,
      `Severity: "${fallbackDoc.severity}", EmergencyEligible: ${fallbackEligible}`
    );

    // ── Test 12: Legacy Unclassified at 0.99 is NEVER Emergency Eligible ────
    const legacyDoc = await CrimeLog.create({
      threatClass: 'Fighting',
      confidence: 0.99,
      detectionStatus: 'legacy_unclassified',
      detectionSource: 'legacy_unspecified',
      cameraId: 'CAM-PHASE-4-2-3',
      frameTimestamp: new Date(),
    });
    const legacyEligible = CrimeLog.isEmergencyEligible(legacyDoc);
    record(
      '12',
      'Legacy unclassified at 0.99 confidence is clamped to normal and not eligible',
      legacyDoc.severity === 'normal' && legacyEligible === false,
      `Severity: "${legacyDoc.severity}", EmergencyEligible: ${legacyEligible}`
    );

    // ── Test 13: Boundary 0.49 -> low severity, not eligible ────────────────
    const b049 = await CrimeLog.create({
      threatClass: 'Fighting',
      confidence: 0.49,
      detectionStatus: 'low_confidence_review',
      detectionSource: 'ml_real',
      cameraId: 'CAM-PHASE-4-2-3',
      frameTimestamp: new Date(),
    });
    record('13', 'Boundary 0.49 -> low severity, not emergency eligible', b049.severity === 'low' && !CrimeLog.isEmergencyEligible(b049));

    // ── Test 14: Boundary 0.50 -> medium severity, not eligible ─────────────
    const b050 = await CrimeLog.create({
      threatClass: 'Fighting',
      confidence: 0.50,
      detectionStatus: 'anomaly_detected',
      detectionSource: 'ml_real',
      cameraId: 'CAM-PHASE-4-2-3',
      frameTimestamp: new Date(),
    });
    record('14', 'Boundary 0.50 -> medium severity, not emergency eligible', b050.severity === 'medium' && !CrimeLog.isEmergencyEligible(b050));

    // ── Test 15: Boundary 0.70 -> high severity, not eligible ───────────────
    const b070 = await CrimeLog.create({
      threatClass: 'Fighting',
      confidence: 0.70,
      detectionStatus: 'anomaly_detected',
      detectionSource: 'ml_real',
      cameraId: 'CAM-PHASE-4-2-3',
      frameTimestamp: new Date(),
    });
    record('15', 'Boundary 0.70 -> high severity, not emergency eligible', b070.severity === 'high' && !CrimeLog.isEmergencyEligible(b070));

    // ── Test 16: Boundary 0.849 -> high severity, not eligible ──────────────
    const b0849 = await CrimeLog.create({
      threatClass: 'Fighting',
      confidence: 0.849,
      detectionStatus: 'anomaly_detected',
      detectionSource: 'ml_real',
      cameraId: 'CAM-PHASE-4-2-3',
      frameTimestamp: new Date(),
    });
    record('16', 'Boundary 0.849 -> high severity, not emergency eligible', b0849.severity === 'high' && !CrimeLog.isEmergencyEligible(b0849));

    // ── Test 17: Boundary 0.85 -> critical severity, emergency eligible ─────
    const b085 = await CrimeLog.create({
      threatClass: 'Fighting',
      confidence: 0.85,
      detectionStatus: 'anomaly_detected',
      detectionSource: 'ml_real',
      cameraId: 'CAM-PHASE-4-2-3',
      frameTimestamp: new Date(),
    });
    record('17', 'Boundary 0.85 -> critical severity, emergency eligible (ml_real)', b085.severity === 'critical' && CrimeLog.isEmergencyEligible(b085));

    // Cleanup
    await CrimeLog.deleteMany({ cameraId: 'CAM-PHASE-4-2-3' });

    console.log('\n========================================================');
    const total = results.length;
    const passed = results.filter((r) => r.passed).length;
    const failed = total - passed;
    console.log(`TOTAL PHASE 4.2.3 TESTS: ${total} | PASSED: ${passed} | FAILED: ${failed}`);
    console.log('========================================================\n');

    process.exit(failed === 0 ? 0 : 1);
  } catch (err) {
    console.error('Fatal test error in Phase 4.2.3 suite:', err);
    process.exit(1);
  } finally {
    await mongoose.disconnect();
  }
}

runPhase423Suite();
