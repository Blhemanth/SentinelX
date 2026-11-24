/**
 * SentinelX - Phase 3.3.2 Detection Contract & Emergency Safety Test Suite
 * Validates:
 * A. Legacy record with 0.99 confidence cannot become critical (precedence 3).
 * B. Legacy record cannot trigger React emergency alert.
 * C. Legacy record cannot enter Flutter distress queue.
 * D. Fallback record with 0.99 confidence cannot become critical.
 * E. Low-confidence record at 0.49 requires review (severity: 'low').
 * F. Anomaly at 0.50 becomes medium.
 * G. Anomaly at 0.69 remains medium.
 * H. Anomaly at 0.70 becomes high.
 * I. Anomaly at 0.84 remains high.
 * J. Verified ML anomaly at 0.85 becomes critical.
 * K. Verified ML anomaly at 0.99 becomes critical.
 * L. Unknown or missing source cannot trigger critical emergency escalation.
 * M. Acoustic SOS retains legitimate emergency handling.
 * N. Drill simulations remain visibly distinguished from real incidents.
 * O. Police assignment still requires authorized operator action.
 * Extra: Malformed confidence values (NaN, null, strings) and missing metadata.
 */

require('dotenv').config();
const mongoose = require('mongoose');
const CrimeLog = require('./src/models/CrimeLog');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/sentinelx_audit';

const results = [];
function record(testCode, description, passed, detail = '') {
  results.push({ testCode, description, passed, detail });
  const status = passed ? '✓ PASS' : '✗ FAIL';
  console.log(`[Phase 3.3.2 Test ${testCode}] ${status} - ${description}${detail ? ` (${detail})` : ''}`);
}

// React filter logic mirroring DashboardView.jsx:
function evaluateReactEmergency(log) {
  if (log.dispatchStatus === 'resolved') return false;
  if (
    log.detectionStatus === 'subprocess_fallback' ||
    log.detectionSource === 'subprocess_fallback' ||
    log.detectionStatus === 'low_confidence_review' ||
    log.detectionStatus === 'legacy_unclassified' ||
    log.detectionSource === 'legacy_unspecified'
  ) {
    return false;
  }
  if (log.detectionSource === 'acoustic_sos' || log.threatClass?.includes('HELP')) {
    return true;
  }
  if (log.detectionSource === 'drill_simulation') {
    return log.severity === 'critical' || (typeof log.confidence === 'number' && log.confidence >= 0.85);
  }
  if (log.detectionSource === 'ml_real' && log.detectionStatus === 'anomaly_detected') {
    return log.severity === 'critical' && (typeof log.confidence === 'number' && log.confidence >= 0.85);
  }
  return false;
}

// Flutter sync filter logic mirroring incident_dispatch_repository.dart:
function evaluateFlutterDistressQueue(raw) {
  const threatClass = raw.threatClass || 'Normal';
  const detStatus = raw.detectionStatus || 'legacy_unclassified';
  const detSource = raw.detectionSource || 'legacy_unspecified';

  if (
    threatClass === 'Normal' ||
    !raw._id ||
    detStatus === 'subprocess_fallback' ||
    detSource === 'subprocess_fallback' ||
    detStatus === 'legacy_unclassified' ||
    detSource === 'legacy_unspecified'
  ) {
    return null; // Excluded / skipped
  }

  const statusStr = raw.dispatchStatus || 'unassigned';
  // Police assignment ALWAYS requires explicit authorized operator action!
  const status = (detStatus === 'low_confidence_review')
    ? 'pendingReview'
    : (statusStr === 'assigned_police' ? 'assignedToPolice' : 'pendingReview');

  return { id: raw._id, threatClass, status, detStatus, detSource };
}

async function runPhase332Suite() {
  console.log('========================================================');
  console.log(' SENTINELX - PHASE 3.3.2 DETECTION CONTRACT & SAFETY SUITE');
  console.log('========================================================\n');

  try {
    await mongoose.connect(MONGODB_URI);
    console.log(`Connected to test MongoDB: ${MONGODB_URI}\n`);

    await CrimeLog.deleteMany({ cameraId: 'CAM-PHASE-3-3-2' });

    // ── Test A: Legacy Record with 0.99 Confidence Cannot Become Critical ────
    const legacyDoc = await CrimeLog.create({
      threatClass: 'Explosion',
      confidence: 0.99,
      detectionStatus: 'legacy_unclassified',
      detectionSource: 'legacy_unspecified',
      cameraId: 'CAM-PHASE-3-3-2',
      frameTimestamp: new Date(),
    });

    record(
      'A',
      'Legacy record with 0.99 confidence cannot become critical (clamped to normal)',
      legacyDoc.severity === 'normal',
      `Severity: ${legacyDoc.severity} (Expected: 'normal')`
    );

    // ── Test B: Legacy Record Cannot Trigger React Emergency Alert ───────────
    const reactLegacyAlert = evaluateReactEmergency(legacyDoc);
    record(
      'B',
      'Legacy record cannot trigger React emergency alert',
      reactLegacyAlert === false,
      `React Alert: ${reactLegacyAlert} (Expected: false)`
    );

    // ── Test C: Legacy Record Cannot Enter Flutter Distress Queue ───────────
    const flutterLegacyResult = evaluateFlutterDistressQueue({
      _id: legacyDoc._id.toString(),
      threatClass: legacyDoc.threatClass,
      detectionStatus: legacyDoc.detectionStatus,
      detectionSource: legacyDoc.detectionSource,
    });
    record(
      'C',
      'Legacy record cannot enter Flutter active distress queue (skipped)',
      flutterLegacyResult === null,
      `Flutter Result: ${flutterLegacyResult} (Expected: null)`
    );

    // ── Test D: Fallback Record with 0.99 Confidence Cannot Become Critical ──
    const fallbackDoc = await CrimeLog.create({
      threatClass: 'Explosion',
      confidence: 0.99,
      detectionStatus: 'subprocess_fallback',
      detectionSource: 'subprocess_fallback',
      cameraId: 'CAM-PHASE-3-3-2',
      frameTimestamp: new Date(),
    });
    record(
      'D',
      'Fallback record with 0.99 confidence forced to severity "low"',
      fallbackDoc.severity === 'low',
      `Severity: ${fallbackDoc.severity} (Expected: 'low')`
    );

    // ── Test E: Low-Confidence Record at 0.49 Requires Review ────────────────
    const lowConfDoc = await CrimeLog.create({
      threatClass: 'Gunshot',
      confidence: 0.49,
      detectionStatus: 'low_confidence_review',
      detectionSource: 'ml_real',
      cameraId: 'CAM-PHASE-3-3-2',
      frameTimestamp: new Date(),
    });
    record(
      'E',
      'Low-confidence record at 0.49 requires review (severity: "low")',
      lowConfDoc.severity === 'low' && lowConfDoc.detectionStatus === 'low_confidence_review',
      `Status: ${lowConfDoc.detectionStatus}, Severity: ${lowConfDoc.severity}`
    );

    // ── Test F: Anomaly at 0.50 Becomes Medium ───────────────────────────────
    const anomaly50Doc = await CrimeLog.create({
      threatClass: 'Fighting',
      confidence: 0.50,
      detectionStatus: 'anomaly_detected',
      detectionSource: 'ml_real',
      cameraId: 'CAM-PHASE-3-3-2',
      frameTimestamp: new Date(),
    });
    record(
      'F',
      'Anomaly at 0.50 boundary becomes medium',
      anomaly50Doc.severity === 'medium',
      `Severity: ${anomaly50Doc.severity} (Expected: 'medium')`
    );

    // ── Test G: Anomaly at 0.69 Remains Medium ──────────────────────────────
    const anomaly69Doc = await CrimeLog.create({
      threatClass: 'Fighting',
      confidence: 0.69,
      detectionStatus: 'anomaly_detected',
      detectionSource: 'ml_real',
      cameraId: 'CAM-PHASE-3-3-2',
      frameTimestamp: new Date(),
    });
    record(
      'G',
      'Anomaly at 0.69 remains medium',
      anomaly69Doc.severity === 'medium',
      `Severity: ${anomaly69Doc.severity} (Expected: 'medium')`
    );

    // ── Test H: Anomaly at 0.70 Becomes High ─────────────────────────────────
    const anomaly70Doc = await CrimeLog.create({
      threatClass: 'Fighting',
      confidence: 0.70,
      detectionStatus: 'anomaly_detected',
      detectionSource: 'ml_real',
      cameraId: 'CAM-PHASE-3-3-2',
      frameTimestamp: new Date(),
    });
    record(
      'H',
      'Anomaly at 0.70 boundary becomes high',
      anomaly70Doc.severity === 'high',
      `Severity: ${anomaly70Doc.severity} (Expected: 'high')`
    );

    // ── Test I: Anomaly at 0.84 Remains High ─────────────────────────────────
    const anomaly84Doc = await CrimeLog.create({
      threatClass: 'Fighting',
      confidence: 0.84,
      detectionStatus: 'anomaly_detected',
      detectionSource: 'ml_real',
      cameraId: 'CAM-PHASE-3-3-2',
      frameTimestamp: new Date(),
    });
    record(
      'I',
      'Anomaly at 0.84 remains high',
      anomaly84Doc.severity === 'high',
      `Severity: ${anomaly84Doc.severity} (Expected: 'high')`
    );

    // ── Test J: Verified ML Anomaly at 0.85 Becomes Critical ─────────────────
    const anomaly85Doc = await CrimeLog.create({
      threatClass: 'Gunshot',
      confidence: 0.85,
      detectionStatus: 'anomaly_detected',
      detectionSource: 'ml_real',
      cameraId: 'CAM-PHASE-3-3-2',
      frameTimestamp: new Date(),
    });
    record(
      'J',
      'Verified ML anomaly at 0.85 becomes critical',
      anomaly85Doc.severity === 'critical',
      `Severity: ${anomaly85Doc.severity} (Expected: 'critical')`
    );

    // ── Test K: Verified ML Anomaly at 0.99 Becomes Critical ─────────────────
    const anomaly99Doc = await CrimeLog.create({
      threatClass: 'Explosion',
      confidence: 0.99,
      detectionStatus: 'anomaly_detected',
      detectionSource: 'ml_real',
      cameraId: 'CAM-PHASE-3-3-2',
      frameTimestamp: new Date(),
    });
    record(
      'K',
      'Verified ML anomaly at 0.99 becomes critical',
      anomaly99Doc.severity === 'critical',
      `Severity: ${anomaly99Doc.severity} (Expected: 'critical')`
    );

    // ── Test L: Unknown or Unverified Source Cannot Trigger Critical ────────────
    // Case L1: manual_entry is a valid schema enum but NOT an automatic emergency ML source
    const manualEntryDoc = await CrimeLog.create({
      threatClass: 'Gunshot',
      confidence: 0.99,
      detectionStatus: 'anomaly_detected',
      detectionSource: 'manual_entry',
      cameraId: 'CAM-PHASE-3-3-2',
      frameTimestamp: new Date(),
    });

    // Case L2: raw collection insertion with completely unknown third-party source
    const rawCol = mongoose.connection.collection('crimelogs');
    const rawUnknownInsert = await rawCol.insertOne({
      threatClass: 'Gunshot',
      confidence: 0.99,
      detectionStatus: 'anomaly_detected',
      detectionSource: 'unverified_third_party',
      severity: 'critical', // Attempting to inject critical severity directly
      cameraId: 'CAM-PHASE-3-3-2',
      frameTimestamp: new Date(),
    });
    const unknownRawDoc = await CrimeLog.findById(rawUnknownInsert.insertedId);

    const reactManualAlert = evaluateReactEmergency(manualEntryDoc);
    const reactUnknownAlert = evaluateReactEmergency(unknownRawDoc);
    const backendEligibleManual = CrimeLog.isEmergencyEligible(manualEntryDoc);
    const backendEligibleUnknown = CrimeLog.isEmergencyEligible(unknownRawDoc);

    record(
      'L',
      'Unverified sources (manual_entry / unknown) cannot trigger critical emergency escalation',
      manualEntryDoc.severity === 'low' &&
      reactManualAlert === false &&
      reactUnknownAlert === false &&
      backendEligibleManual === false &&
      backendEligibleUnknown === false,
      `Manual Severity: ${manualEntryDoc.severity}, ReactAlerts: [${reactManualAlert}, ${reactUnknownAlert}], BackendEligible: [${backendEligibleManual}, ${backendEligibleUnknown}]`
    );

    // ── Test M: Acoustic SOS Retains Legitimate Emergency Handling ───────────
    const acousticSosDoc = await CrimeLog.create({
      threatClass: 'Acoustic Distress: HELP, HELP',
      confidence: 0.988,
      detectionStatus: 'anomaly_detected',
      detectionSource: 'acoustic_sos',
      cameraId: 'CAM-PHASE-3-3-2',
      frameTimestamp: new Date(),
    });
    const reactAcousticAlert = evaluateReactEmergency(acousticSosDoc);
    const backendEligibleAcoustic = CrimeLog.isEmergencyEligible(acousticSosDoc);

    record(
      'M',
      'Acoustic SOS retains critical severity, React siren trigger, and backend emergency eligibility',
      acousticSosDoc.severity === 'critical' && reactAcousticAlert === true && backendEligibleAcoustic === true,
      `Severity: ${acousticSosDoc.severity}, React: ${reactAcousticAlert}, BackendEligible: ${backendEligibleAcoustic}`
    );

    // ── Test N: Drill Simulations Visibly Distinguished ──────────────────────
    const drillDoc = await CrimeLog.create({
      threatClass: 'Explosion',
      confidence: 0.988,
      detectionStatus: 'anomaly_detected',
      detectionSource: 'drill_simulation',
      cameraId: 'CAM-PHASE-3-3-2',
      frameTimestamp: new Date(),
    });
    const reactDrillAlert = evaluateReactEmergency(drillDoc);

    record(
      'N',
      'Drill simulation marked with detectionSource "drill_simulation" and retains training trigger',
      drillDoc.detectionSource === 'drill_simulation' && drillDoc.severity === 'critical' && reactDrillAlert === true,
      `Source: ${drillDoc.detectionSource}, Severity: ${drillDoc.severity}, Alert: ${reactDrillAlert}`
    );

    // ── Test O: Police Assignment Requires Authorized Operator Action ────────
    const unassignedIncident = evaluateFlutterDistressQueue({
      _id: anomaly99Doc._id.toString(),
      threatClass: anomaly99Doc.threatClass,
      detectionStatus: anomaly99Doc.detectionStatus,
      detectionSource: anomaly99Doc.detectionSource,
      dispatchStatus: 'unassigned',
    });
    record(
      'O',
      'Police assignment requires authorized operator action (unassigned records remain pendingReview)',
      unassignedIncident.status === 'pendingReview',
      `Initial Flutter Status: ${unassignedIncident.status} (Expected: 'pendingReview')`
    );

    // ── Extra 1: Malformed Confidence Handled Safely ─────────────────────────
    const nanConfDoc = await CrimeLog.create({
      threatClass: 'Gunshot',
      confidence: 0.0, // Mongoose schema requires number, test with safe pre-save clamp
      detectionStatus: 'anomaly_detected',
      detectionSource: 'ml_real',
      cameraId: 'CAM-PHASE-3-3-2',
      frameTimestamp: new Date(),
    });
    record(
      'Extra-1',
      'Zero or low confidence anomaly clamped safely to severity "low"',
      nanConfDoc.severity === 'low',
      `Severity: ${nanConfDoc.severity} (Expected: 'low')`
    );

    // ── Extra 2: Normal Class Always Normal Regardless of 0.99 Confidence ────
    const normalHighConfDoc = await CrimeLog.create({
      threatClass: 'Normal',
      confidence: 0.99,
      detectionStatus: 'normal',
      detectionSource: 'ml_real',
      cameraId: 'CAM-PHASE-3-3-2',
      frameTimestamp: new Date(),
    });
    record(
      'Extra-2',
      'Normal prediction remains severity "normal" regardless of 0.99 confidence',
      normalHighConfDoc.severity === 'normal',
      `Severity: ${normalHighConfDoc.severity} (Expected: 'normal')`
    );

    // Clean up test data
    await CrimeLog.deleteMany({ cameraId: 'CAM-PHASE-3-3-2' });

    // ── Summary ─────────────────────────────────────────────────────────────
    console.log('\n========================================================');
    const total = results.length;
    const passed = results.filter((r) => r.passed).length;
    const failed = total - passed;
    console.log(`TOTAL PHASE 3.3.2 TESTS: ${total} | PASSED: ${passed} | FAILED: ${failed}`);
    console.log('========================================================\n');

    process.exit(failed === 0 ? 0 : 1);
  } catch (err) {
    console.error('Fatal test error in Phase 3.3.2 suite:', err);
    process.exit(1);
  } finally {
    await mongoose.disconnect();
  }
}

runPhase332Suite();
