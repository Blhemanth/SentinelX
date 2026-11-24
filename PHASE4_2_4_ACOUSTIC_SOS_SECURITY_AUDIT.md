# SentinelX — Phase 4.2.4: Acoustic SOS Provenance & Emergency Ingestion Security Audit

**Document Reference:** `PHASE4_2_4_ACOUSTIC_SOS_SECURITY_AUDIT.md`  
**Date:** 2026-11-22  
**Role:** Principal Backend Security Engineer, API Security Auditor, and Emergency Systems Architect  
**Classification:** SAFETY-CRITICAL APPLICATION AUDIT & ARCHITECTURAL REVIEW  
**Status:** COMPLETE & AUTHORITATIVE  

---

## 1. Executive Summary & Audit Context

During the Phase 4.2.3 independent audit, an operational dispatch isolation boundary was established to prevent `drill_simulation` records from triggering real police dispatch. In that phase, an initial heuristic sanitization check was added to `backend/src/controllers/logs.controller.js` to distinguish acoustic distress from other events by checking:
```javascript
const hasAudioEvidence = (payload.audioTranscript && payload.audioTranscript.includes('HELP')) ||
                         (typeof payload.audioDecibels === 'number' && payload.audioDecibels >= 70);
```
An independent security review flagged this heuristic as an **untrusted client input vulnerability**. In a distributed REST environment, `/api/logs` is a JSON endpoint accessed by authenticated network clients. An attacker with standard analyst credentials or a compromised client device can easily fabricate an arbitrary JSON payload:
```json
{
  "threatClass": "Acoustic Distress: HELP, HELP",
  "detectionSource": "acoustic_sos",
  "audioTranscript": "CRITICAL EMERGENCY: HELP! HELP!",
  "audioDecibels": 95.0,
  "confidence": 0.99,
  "severity": "critical"
}
```
Because the heuristic evaluated the client's own strings and numbers, the server assigned `detectionSource: 'acoustic_sos'` and derived `severity: 'critical'`, allowing an unverified client submission to trigger immediate emergency escalation in `CrimeLog.isEmergencyEligible()`.

**Audit Objective:** Perform an end-to-end audit of all audio ingestion, processing, classification, and dispatch pathways across the Python ML microservice, Node.js Express backend, Flutter native client, and React web operations center; determine whether a trusted server-side audio verification pipeline exists; and establish an uncompromising trust boundary.

---

## 2. End-to-End Audio Pipeline Architecture Audit

The audit inspected all components involved in audio capture, transport, processing, and persistence:

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   AUDIO PIPELINE ARCHITECTURE                                    │
├──────────────────────────┬─────────────────────────────┬─────────────────────────────────────────┤
│ Layer / Component        │ Inspected Source Files      │ Findings & Provenance Capability        │
├──────────────────────────┼─────────────────────────────┼─────────────────────────────────────────┤
│ 1. Python Audio Preproc  │ `server_ml/preprocessor.py` │ Decodes WAV PCM waveforms; downmixes to │
│                          │                             │ mono; resamples to 16kHz; computes      │
│                          │                             │ 128-band log Mel-spectrogram [1,1,128,  │
│                          │                             │ 128]. NO speech-to-text (ASR) or spoken │
│                          │                             │ keyword-spotting ("HELP") exists.       │
├──────────────────────────┼─────────────────────────────┼─────────────────────────────────────────┤
│ 2. FastAPI Endpoints     │ `server_ml/inference_api.py`│ Exposes `/detect` (base64) & `/detect/  │
│                          │                             │ upload` (multipart). Forwards to        │
│                          │                             │ `SentinelXNet` for 5-class visual-audio │
│                          │                             │ logits. Does NOT output distress text.  │
├──────────────────────────┼─────────────────────────────┼─────────────────────────────────────────┤
│ 3. Express ML Bridge     │ `backend/src/services/`     │ Bridges Express to Python via REST or   │
│                          │ `mlBridge.service.js`       │ subprocess. Only handles multi-modal    │
│                          │                             │ input for 5-class vision/audio model.   │
├──────────────────────────┼─────────────────────────────┼─────────────────────────────────────────┤
│ 4. Express Detection API │ `backend/src/controllers/`  │ `POST /api/detect` ingests video/audio  │
│                          │ `detect.controller.js`      │ bytes; authenticates via JWT & RBAC;    │
│                          │                             │ records genuine detections as `ml_real`.│
├──────────────────────────┼─────────────────────────────┼─────────────────────────────────────────┤
│ 5. Express Log API       │ `backend/src/controllers/`  │ `POST /api/logs` is a JSON REST endpoint│
│                          │ `logs.controller.js`        │ vulnerable to client-spoofed transcripts│
│                          │                             │ and self-proclaimed `acoustic_sos`.     │
├──────────────────────────┼─────────────────────────────┼─────────────────────────────────────────┤
│ 6. Persistence & Pre-Save│ `backend/src/models/`       │ Pre-save hook derives severity. Static  │
│                          │ `CrimeLog.js`               │ method `isEmergencyEligible(log)` marks │
│                          │                             │ `acoustic_sos` with HELP as eligible.   │
├──────────────────────────┼─────────────────────────────┼─────────────────────────────────────────┤
│ 7. Flutter Mobile/Desktop│ `lib/core/services/`        │ `triggerDistress()` generates mock      │
│                          │ `incident_dispatch_`        │ transcript ("HELP! HELP!") and decibels │
│                          │ `repository.dart`           │ (89.4 dB); sends JSON to `/api/logs`.   │
├──────────────────────────┼─────────────────────────────┼─────────────────────────────────────────┤
│ 8. React Command Center  │ `frontend/src/views/`       │ Displays emergency banner when          │
│                          │ `DashboardView.jsx`         │ `detectionSource === 'acoustic_sos'`.   │
└──────────────────────────┴─────────────────────────────┴─────────────────────────────────────────┘
```

---

## 3. Detailed Component Findings

### 3.1 Python Audio Preprocessing (`server_ml/preprocessor.py`)
- **Inspection:** Inspected `preprocess_audio()` and `get_acoustic_silence()`.
- **Capability:** Reads raw WAV bytes via `scipy.io.wavfile.read()`, resamples to 16,000 Hz, downmixes stereo to mono, and applies `torchaudio.transforms.MelSpectrogram(n_mels=128, n_fft=1024, hop_length=512)`. Log-decibel scaling is performed via `AmplitudeToDB(top_db=80.0)`.
- **Limitation:** The output tensor $[1, 1, 128, 128]$ is fed into the 2D ResNet audio backbone of `SentinelXNet`. **The server possesses zero Speech-to-Text (ASR), zero acoustic keyword-spotting (KWS), and zero natural language processing (NLP) models.** It cannot determine whether spoken words contain `"HELP"` or any other distress phrase.

### 3.2 FastAPI ML Microservice (`server_ml/inference_api.py`)
- **Inspection:** Inspected `/detect`, `/detect/upload`, and `/model/info`.
- **Capability:** Model output taxonomy consists of exactly 5 classes:
  $$\text{THREAT\_CLASSES} = [\text{"Explosion"}, \text{"Gunshot"}, \text{"Fighting"}, \text{"Accident"}, \text{"Normal"}]$$
- **Limitation:** Neither `inference_api.py` nor `infer.py` outputs a threat class called `"Acoustic Distress: HELP, HELP"`. The threat class `"Acoustic Distress: HELP, HELP"` is entirely an external domain string utilized by UI simulation and distress triggers.

### 3.3 Express Detection Controller (`backend/src/controllers/detect.controller.js`)
- **Inspection:** Inspected `detect()` endpoint handler.
- **Capability:** Receives video and audio bytes; dispatches to `mlBridge.service.js`; records genuine inferences to MongoDB with `detectionSource: 'ml_real'`.
- **Gap Identified:** Did not previously validate audio MIME signatures (RIFF/WAVE header), decoded buffer byte boundaries, or payload length limits prior to passing to the ML bridge.

### 3.4 Express Logs Controller (`backend/src/controllers/logs.controller.js`)
- **Inspection:** Inspected `createLog()`, `updateDispatchStatus()`, and `mockTrigger()`.
- **Vulnerability Identified:** In `createLog()`, inspecting `payload.audioTranscript.includes('HELP')` and `payload.audioDecibels >= 70` accepted client-supplied metadata as proof of acoustic distress. Because `/api/logs` receives JSON without raw audio waveforms, an untrusted client could dictate its own emergency eligibility.
- **Secondary Gap:** `mockTrigger()` permitted a client to pass `dispatchStatus: 'assigned_police'`, potentially creating a drill simulation that arrived already flagged as assigned.

### 3.5 Flutter Client (`lib/core/services/incident_dispatch_repository.dart`)
- **Inspection:** Inspected `triggerDistress()`.
- **Behavior:** Generates a synthetic `DistressIncident` with `audioTranscript = 'Critical Acoustic Distress Detected: "HELP! HELP! EMERGENCY AT SECTOR"'` and `decibels = 89.4`. Posts this payload as a JSON document to `POST /api/logs`.
- **Classification:** This is client-generated simulated distress. It represents an unverified field report (`manual_entry`), not a cryptographically verified or server-classified acoustic event.

---

## 4. Trust Boundary Analysis: The Client-Trust Anti-Pattern

In an automated incident response system, authorizing law enforcement dispatch based on client-supplied text fields violates core application security principles:

```
UNTRUSTED CLIENT ZONE                     TRUSTED SERVER ZONE
┌─────────────────────────┐               ┌──────────────────────────────────────────────┐
│ Malicious or Buggy      │               │ Express REST Ingestion (/api/logs)           │
│ Network Client          │               │                                              │
│                         │  JSON POST    │ 1. Client supplies:                          │
│ {                       ├──────────────►│    detectionSource: 'acoustic_sos'           │
│   threatClass: 'HELP',  │               │    audioTranscript: 'HELP! HELP!'            │
│   audioTranscript:      │               │    audioDecibels: 92.0                       │
│     'HELP! HELP!',      │               │                                              │
│   audioDecibels: 92.0,  │               │ 2. VULNERABLE CHECK:                         │
│   confidence: 0.99      │               │    payload.audioTranscript.includes('HELP')? │
│ }                       │               │    --> TRUE! (Client supplied it!)           │
│                         │               │                                              │
│                         │               │ 3. RESULT: Escapes to critical emergency!    │
└─────────────────────────┘               └──────────────────────────────────────────────┘
```

### The Inviolable Security Invariant:
**No client-supplied metadata field (`detectionSource`, `detectionStatus`, `severity`, `confidence`, `audioTranscript`, `audioDecibels`) may independently grant emergency dispatch eligibility.** Emergency eligibility is an authoritative server-side determination that must be established exclusively by:
1. Verified server-side multi-modal inference (`detectionSource: 'ml_real'`, `detectionStatus: 'anomaly_detected'`, $\text{confidence} \ge 0.85$, generated via `/api/detect`).
2. An authenticated server-side acoustic speech verification microservice processing raw audio waveforms (currently not implemented).
3. Explicit human operator dispatch action via `PATCH /api/logs/:id/dispatch` with an assigned officer and operational log notes.

---

## 5. Prerequisites for Genuine Server-Side Acoustic SOS Verification

Because the Python microservice does not currently possess an on-prem ASR speech-recognition engine, creating a "fake" server-side audio verifier would create a false sense of security. The following prerequisites must be met before genuine automated Acoustic SOS dispatch can be enabled:

1. **On-Premise ASR/KWS Model:** Integration of a lightweight, low-latency acoustic keyword spotter (e.g., OpenVINO Whisper-Tiny, Vosk, or a dedicated PyTorch CTC keyword spotter) within `server_ml/` trained specifically on distress keywords (`"HELP"`, `"EMERGENCY"`, `"SAVE ME"`).
2. **Raw Audio Waveform Submission:** Clients must stream raw PCM/WAV audio bytes rather than JSON strings.
3. **Calibrated Decibel Measurement:** Decibel calculation must be performed server-side from raw PCM root-mean-square (RMS) amplitude relative to full-scale (dBFS), calibrated against standardized sound pressure levels (SPL).
4. **MIME & Signature Validation:** Binary audio uploads must verify standard RIFF/WAVE header chunks, sample rate (16,000 Hz), bit depth (16-bit PCM), and length ($\le 10$ seconds).
5. **Rate Limiting & Abuse Throttling:** Audio ingestion endpoints must enforce per-camera burst limits to prevent denial-of-service through continuous raw audio submission.

---

## 6. Audit Verdict & Action Items

| Audit Item | Current State | Risk Level | Remediation Implemented in Phase 4.2.4 |
| :--- | :--- | :---: | :--- |
| **Client-Supplied Acoustic SOS** | Accepted if transcript/decibels match heuristic | **CRITICAL** | Stripped and sanitized to `manual_entry` + `low_confidence_review` |
| **Client-Supplied `ml_real`** | Sanitized to `manual_entry` | LOW (Secured) | Maintained and re-verified |
| **Client-Supplied `severity: critical`** | Overwritten by Mongoose pre-save hook | MEDIUM | Stripped explicitly in controller before database write |
| **Drill Simulation Dispatch** | Blocked in `updateDispatchStatus` | LOW (Secured) | Enforced atomically across all routes (`updateDispatchStatus`, `createLog`, `mockTrigger`) |
| **Manual Entry Creation** | Could specify `assigned_police` | MEDIUM | Clamped strictly to `unassigned` on creation |
| **Audio Ingestion Validation** | Missing file signature checks in `/api/detect` | MEDIUM | Added RIFF/WAVE signature check, 10MB size limit, base64 validation |
| **Server-Side Audio ASR** | Not implemented in Python ML microservice | INFORMATIONAL | Formally documented as prerequisite; fake verification avoided |

**Audit Conclusion:** The vulnerability was verified and closed. All client-supplied distress events entering via `/api/logs` are now strictly demoted to `manual_entry` with `severity: 'low'`, requiring human operator review before police dispatch can occur.
