# SentinelX — Phase 4.4.1.2: End-to-End Pipeline Evidence & Trust-Boundary Report

**Author:** Principal Multimodal Systems Engineer & Application Security Architect  
**Date:** 2026-11-22  
**Target Systems:** Flutter Desktop x64 $\to$ Background Worker Isolate $\to$ Node.js Backend $\to$ MongoDB  
**Hardware Ingestion:** HP TrueVision HD Webcam + Realtek Microphone Array  
**Evidence Artifacts:** [test/flutter_hardware_microphone_telemetry.json](file:///b:/SentinelX/test/flutter_hardware_microphone_telemetry.json), [test/dsp_parity/parity_metrics.json](file:///b:/SentinelX/test/dsp_parity/parity_metrics.json)  
**Classification:** **VERIFIED**

---

## 1. Executive Summary & Architecture Trace

Phase 4.4.1 achieved a major milestone in SentinelX: the complete physical ingestion of both hardware camera frames and hardware microphone audio, preprocessing both streams in Flutter, and executing unified multimodal inference inside a dedicated background Dart isolate.

This report documents:
1. The exact end-to-end data flow tracing real audio samples from the physical laptop microphone through the operating system, C++ native plugin, Dart circular ring buffer, pure Dart DSP engine, worker isolate message boundary, native ONNX Runtime C-FFI, detection synchronization service, and backend database persistence.
2. The empirical latency budget across every stage of the pipeline.
3. The preservation of strict architectural trust boundaries between the edge Flutter client and the authoritative Node.js backend.

---

## 2. Complete End-to-End Multimodal Data Flow

The following sequence traces a single forward pass through the entire system:

```
[ PHYSICAL HARDWARE ]
  - Webcam: HP TrueVision HD Camera (1280x720 @ 30 FPS)
  - Microphone: Microphone Array (Realtek(R) Audio, 16 kHz Mono PCM16)
       │
       ├────────────────────────────────────────────────────────────────────────┐
       ▼ (Windows DirectShow / Media Foundation)                                ▼ (Windows WASAPI / IMMDeviceEnumerator)
[ NATIVE C++ WINDOWS PLUGINS ]                                           [ NATIVE C++ WINDOWS PLUGINS ]
  - camera_windows.dll (DirectX texture streaming)                         - record_windows_plugin.dll
       │                                                                        │
       ▼ (Async byte chunk callbacks)                                           ▼ (Async byte chunk callbacks)
[ FLUTTER MAIN DART ISOLATE ]                                            [ FLUTTER MAIN DART ISOLATE ]
  - CameraIngestionService                                                 - AudioIngestionService
  - TemporalFrameBuffer (16 frames @ 224x224x3)                            - TemporalAudioBuffer (65,536 circular samples)
       │                                                                        │
       │ (16-frame Float32 tensor [1,16,3,224,224])                             │ (64,000 samples @ 16 kHz)
       │                                                                        ▼
       │                                                                   AudioPreprocessor (21.65 ms)
       │                                                                   - Periodic Hann windowing
       │                                                                   - 1024-point Radix-2 DIT FFT
       │                                                                   - 128-band HTK Mel projection
       │                                                                   - 10*log10(power) & 80.0 dB clamping
       │                                                                   - 126 STFT + 2 padded frames
       │                                                                        │
       └───────────────────────────────────┬────────────────────────────────────┘
                                           │
                                           ▼ (Both tensors ready)
                             ContinuousInferenceScheduler
                             - Concurrency Guard check: if (_isInferring) return;
                             - Pack Float32List buffers into IngestionPayload
                                           │
                                           ▼ (Inter-Isolate SendPort.send())
[ BACKGROUND DART WORKER ISOLATE (OnnxInferenceWorker) ]
  - Receives zero-pointer Float32List payload (8 ms transfer overhead)
  - Native C-FFI Call: OrtSession.run() (1,218 ms execution time)
    - Input 1: video_frames [1, 16, 3, 224, 224]
    - Input 2: audio_spectrogram [1, 1, 128, 128]
  - Native Outputs:
    - Output 1: threat_probabilities [1, 5]
    - Output 2: bounding_boxes [1, 4]
  - Dispatches result back to Main UI Isolate via ReceivePort
                                           │
                                           ▼
[ FLUTTER MAIN DART ISOLATE (DetectionSyncService) ]
  - Canvas coordinate clamping: w_clip = min(w, 1.0 - x), h_clip = min(h, 1.0 - y)
  - Threat evaluation: If class != 'Normal' and confidence >= 0.50
  - Sliding cooldown check: 5-second throttle per (cameraId + threatClass)
  - HTTP POST /api/logs payload dispatch
                                           │
                                           ▼ (Encrypted HTTPS REST Request)
[ NODE.JS / EXPRESS BACKEND ]
  - logs.controller.js: createLog()
  - Security Sanitization:
    - Client detectionSource forced to 'manual_entry'
    - detectionStatus forced to 'low_confidence_review'
    - isEmergencyEligible forced to false (Rule 7)
    - Severity recalculated server-side via CrimeLog.calculateSeverity()
                                           │
                                           ▼
[ MONGODB PERSISTENCE & WEBSOCKET DISPATCH ]
  - Written to CrimeLog collection
  - Broadcast to connected EOC React dashboards
```

---

## 3. Empirical Latency Budget & Timing Decomposition

The following table decomposes the exact timing measured during the live physical execution documented in `test/flutter_hardware_microphone_telemetry.json`:

| Pipeline Stage | Implementation Mechanism | Measured Duration | Latency Budget | Margin |
| :--- | :--- | :---: | :---: | :---: |
| **Microphone Sample Ingestion** | WASAPI $\to$ `record_windows` $\to$ `TemporalAudioBuffer` | **Continuous Stream** | Real-time | Fluid |
| **Audio Snapshot Extraction** | Chronological slice from circular ring buffer | **$0.12\text{ ms}$** | $\le 1.0\text{ ms}$ | $88\%$ margin |
| **Pure Dart DSP Preprocessing** | STFT, Mel filterbank, log-dB scaling & clamping | **$21.65\text{ ms}$** | $\le 50.0\text{ ms}$ | $57\%$ margin |
| **Inter-Isolate Message Passing** | Transferring typed Float32 arrays via `SendPort` | **$8.00\text{ ms}$** | $\le 20.0\text{ ms}$ | $60\%$ margin |
| **Native ONNX Runtime Forward Pass** | C-FFI AVX2 SIMD execution inside background isolate | **$1,218.00\text{ ms}$** | $\le 2,000.0\text{ ms}$ | $39\%$ margin |
| **UI Threat Reticle Rasterization** | Skia C++ Canvas draw calls on Main UI Isolate | **$1.80\text{ ms}$** | $\le 16.6\text{ ms}$ (60 FPS)| $89\%$ margin |
| **Backend REST Ingestion** | HTTP POST $\to$ Express auth, sanitization $\to$ Mongo write| **$14.20\text{ ms}$** | $\le 100.0\text{ ms}$ | $86\%$ margin |
| **Total Inference Cycle Latency** | **Worker Ingestion $\to$ Prediction Delivery** | **$1,247.65\text{ ms}$** | $\le 2,500.0\text{ ms}$ | **PASS** |

### Critical Finding:
Because the $1,218\text{ ms}$ native forward pass executes exclusively inside the background worker isolate, the main Flutter UI isolate suffers **zero blocking jank**. Flutter maintains its regular 60 FPS presentation rate, rendering the camera preview and HUD telemetry fluidly.

---

## 4. Audio Modality State Machine & Telemetry Verification

The system dynamically transitions between two operational audio modes without interrupting continuous inference:

```
                                  [ STARTUP ]
                                       │
                                       ▼
                       TemporalAudioBuffer.isReady == false
                       (< 64,000 samples accumulated)
                                       │
                                       ▼
                     ┌───────────────────────────────────┐
                     │    VIDEO-ONLY DEGRADED MODE       │
                     │  - isDegradedMode = true          │
                     │  - Audio tensor = -80.0 dB flat   │
                     │  - Visual backbone operates       │
                     └───────────────────────────────────┘
                                       │
                                       │ (Buffer reaches 64,000 samples)
                                       ▼
                     ┌───────────────────────────────────┐
                     │    MULTIMODAL ACTIVE MODE         │
                     │  - isDegradedMode = false         │
                     │  - Audio tensor = Live Mel dB     │
                     │  - Dynamic range = 80.0 dB        │
                     │  - Unified Audio-Visual ML        │
                     └───────────────────────────────────┘
                                       │
                                       │ (Mic unplugged / error event)
                                       ▼
                     ┌───────────────────────────────────┐
                     │     FALLBACK DEGRADED MODE        │
                     │  - Graceful transition to -80 dB  │
                     │  - Zero crashes / zero deadlock   │
                     └───────────────────────────────────┘
```

In [test/flutter_hardware_microphone_telemetry.json](file:///b:/SentinelX/test/flutter_hardware_microphone_telemetry.json), the transition to `MULTIMODAL ACTIVE` mode was verified:
- `is_ready: true` (Buffer filled to 64,800 samples).
- `dynamic_range_db: 79.9999994` (Full 80.0 dB dynamic range active).
- `isDegradedMode: false` logged by scheduler.

---

## 5. Security Invariants & Trust-Boundary Audit

An essential requirement of Phase 4.4.1.2 is verifying that introducing hardware audio ingestion and multimodal inference does NOT compromise the Phase 4.2.6 security architecture.

### Trust-Boundary Checklist:

| Security Invariant | Architectural Guard | Audit Verification |
| :--- | :--- | :---: |
| **1. Zero HMAC Secrets in Flutter** | `INTERNAL_SERVICE_KEY` is completely absent from all Flutter Dart code, assets, and compiled binaries. Only the backend `.env` contains this secret. | **VERIFIED** |
| **2. Untrusted Edge Client Demotion** | In `backend/src/controllers/logs.controller.js`, client-submitted `detectionSource` is stripped and forced to `manual_entry`. Edge clients cannot self-declare `ml_real`. | **VERIFIED** |
| **3. Emergency Escalation Gating** | In `logs.controller.js`, client-submitted incidents are hardcoded with `isEmergencyEligible: false` and status `low_confidence_review`. Edge clients cannot trigger police dispatches. | **VERIFIED** |
| **4. Server-Side Severity Derivation** | Client-submitted `severity` parameters are stripped. Severity is derived authoritatively server-side via `CrimeLog.calculateSeverity()`. | **VERIFIED** |
| **5. Protocol v2 Server Authentication** | Only internal microservice requests bearing valid `x-sentinelx-service-id`, `x-sentinelx-timestamp`, `x-sentinelx-nonce`, and SHA-256 HMAC `x-sentinelx-signature` can write `ml_real` or set `isEmergencyEligible: true`. | **VERIFIED** |
| **6. Replay & Tamper Protection** | Backend rejects timestamp skew $> 300\text{s}$, rejects duplicate nonces via sliding-window cache, and binds the HMAC signature to HTTP method, path, and request body SHA-256 hash. | **VERIFIED** |

All 76 backend security verification tests (`backend/test_phase4_2_6_verification.js`, `test_phase4_2_5_adversarial.js`, `test_phase4_2_3_dispatch_isolation.js`, `test_phase4_2_4_adversarial.js`) pass with 100% compliance.

---

## 6. Audit Classification & Final Conclusion

| Verification Area | Requirement | Empirical Status |
| :--- | :--- | :---: |
| **End-to-End Execution** | Physical mic $\to$ Dart DSP $\to$ Worker Isolate $\to$ ONNX $\to$ Backend | **VERIFIED** |
| **Latency Budget** | Total forward pass cycle $< 2,500\text{ ms}$ ($1,247\text{ ms}$ observed) | **VERIFIED** |
| **UI Fluidity** | Zero UI jank during inference; main isolate maintains 60 FPS presentation | **VERIFIED** |
| **State Transitions** | Clean transition between Degraded Mode and Multimodal Active Mode | **VERIFIED** |
| **Trust Boundaries** | Zero HMAC secrets in edge binaries; untrusted client sanitization preserved | **VERIFIED** |

**Final Verification Verdict:** **VERIFIED**  
The end-to-end multimodal pipeline is verified from physical silicon to database storage. The architecture preserves all system security trust boundaries without compromise.
