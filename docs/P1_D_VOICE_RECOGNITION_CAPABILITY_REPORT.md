# SentinelX — Milestone P1-D: Voice Recognition Capability & Hardware Telemetry Report

**Document ID:** `DOC-P1-D-VOICE-RECOGNITION-001`  
**Milestone:** P1-D (Help Detection, SOS Workflow & Incident Dispatch Restoration)  
**System Architecture:** Windows Audio Pipeline / Physical Microphone Telemetry / Model Inference Boundary  
**Authoritative Classification:** Audio Capabilities & Hardware Acoustic Transparency  

---

## 1. Objective & Transparency Mandate

A core requirement of Milestone P1-D is total truthfulness regarding machine learning capabilities, speech processing pipelines, and acoustic distress detection. SentinelX must never simulate, fake, or falsely advertise speech recognition or wake-word detection when such capabilities do not exist in the codebase.

This report establishes the verified state of voice recognition in SentinelX, defines what the physical audio pipeline actually performs, and presents the roadmap for future speech processing integration.

---

## 2. Capability Audit & Forensic Reality

### 2.1 Absence of Speech-to-Text / Wake-Word Engine
* **Installed Engines:** **None.**
* **Package Verification:**
  - `pubspec.yaml`: No `speech_to_text`, `vosk_flutter`, `porcupine_flutter`, or `picovoice`.
  - `backend/package.json`: No speech recognition libraries or Google Speech API bindings.
  - `server_ml/requirements.txt`: Contains `torch`, `torchaudio`, `librosa`, `onnx`, `onnxruntime`, `numpy`, `opencv-python`. No Whisper, Kaldi, or Vosk models.
* **Architecture Reality:** The onnx model `assets/models/sentinelx_model.onnx` (`SentinelXNet`) accepts audio tensors shaped `[1, 1, 128, 128]` representing Mel-spectrograms of 1-second audio clips. Mel-spectrograms capture acoustic frequency distributions, not phonetic transcriptions or natural language tokens.
* **Conclusion:** **SentinelX does NOT possess automatic speech recognition (ASR) or voice keyword spotting.** Spoken words such as "HELP, HELP" cannot be detected phonetically by the current ML model or runtime isolate.

---

## 3. Verified Physical Microphone Ingestion & Telemetry

While speech-to-text is offline, SentinelX features a fully functional, verified physical audio telemetry pipeline:
1. **Physical Microphone Capture:**
   - Device: Realtek Microphone Array (Windows Core Audio API via `record_windows`).
   - Format: 16,000 Hz, 16-bit linear PCM, mono, 32,000 bytes/sec.
2. **DSP Processing:**
   - Computes authentic, calibrated root-mean-square decibel full-scale (dBFS):
     $$\text{dBFS} = 20 \log_{10}\left(\frac{\text{RMS}}{32768.0}\right)$$
   - Computes 10-bin spectral frequency distribution ($0.0 \dots 1.0$) for visual spectrum monitoring.
3. **Threshold vs Speech Distinction:**
   - Shouting or loud acoustic bursts produce authentic elevated dBFS readings in the Audio Monitor.
   - However, loud sounds are energy surges, not semantic distress keywords.
4. **UI Transparency:**
   The application dashboard explicitly displays:
   `ACOUSTIC PIPELINE: Realtek 16 kHz PCM Active • Voice Keyword Spotting: Offline (Manual SOS Trigger)`

---

## 4. Distress Drill Simulation Workflow

To allow operators, instructors, and presentation audiences to safely test acoustic distress procedures without pretending speech recognition exists:
1. **Confirmation Prompt:**
   Clicking `TRIGGER DISTRESS DRILL` launches an explicit confirmation dialog:
   > **CONFIRM DISTRESS DRILL**  
   > Initiating a simulated emergency distress drill on camera [CAM-001]. A simulation incident will be persisted to MongoDB for training and audit review.  
   >  
   > **Capability & Drill Isolation Notice:**  
   > • Voice Keyword Spotting: Offline (Manual SOS Drill Mode)  
   > • Isolation: Blocked from live police dispatch  
   > • Backend Persistence: Saved as `isSimulation: true` with MongoDB ObjectId  
2. **Authentic Record Generation:**
   On confirmation, the client posts `isSimulation: true` and `detectionSource: 'drill_simulation'` to `/api/logs`, creating an authoritative audit record with calibrated telemetry.
3. **Control Room Modal:**
   Surfaces the incident with an orange `[TRAINING DRILL SIMULATION]` header and enables assignment strictly to simulated training units (`Simulated Police Patrol Unit #104`).

---

## 5. Future Speech Processing Roadmap

When on-device keyword spotting is scheduled for implementation (e.g., Phase 5):
1. **On-Device Vosk Small Engine:**
   - Lightweight offline acoustic model (`vosk-model-small-en-us-0.15`, ~40 MB).
   - Runs in a background Flutter isolate without cloud latency or external API dependencies.
2. **Dedicated Wake-Word Spotter:**
   - Custom keyword detector trained specifically on emergency phonemes ("HELP", "EMERGENCY", "ASSISTANCE").
   - Integrated downstream from `AudioIngestionService` before multimodal fusion.
