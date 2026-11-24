# SentinelX — Phase 4.3.2: Continuous Real-Time ONNX Inference Architecture Inspection

**Document Version:** 1.0.0  
**Date:** 2026-11-22  
**Author:** Senior Flutter Desktop Engineer, ONNX Runtime Specialist & Edge AI Architect  
**Classification:** Pre-Implementation Architectural Inspection & Audit  
**Scope:** Flutter Desktop (Windows x64), Android ARM64, Native ONNX Runtime C-FFI, Camera Ingestion Pipeline, Continuous Scheduling, Degraded Mode, Backend Sync & Dispatch Safety  

---

## 1. Executive Summary

Phase 4.3.1 successfully replaced simulated pseudo-random camera frames with genuine physical hardware webcam ingestion via [CameraIngestionService](file:///b:/SentinelX/lib/core/camera/camera_ingestion_service.dart) and [TemporalFrameBuffer](file:///b:/SentinelX/lib/core/camera/temporal_frame_buffer.dart). Physical hardware benchmarks on Windows 11 Desktop confirmed **29.22 FPS**, **33.02 ms average acquisition latency**, and **strictly bounded 2.30 MB memory**.

Phase 4.3.2 establishes the continuous end-to-end inference pipeline:
$$\text{Physical Camera (Webcam)} \xrightarrow{\text{takePicture()}} \text{CameraIngestionService} \xrightarrow{\text{Skia RGB}} \text{TemporalFrameBuffer (16 frames)} \xrightarrow{\text{Float32 Tensor}} \text{ONNX Runtime (AVX2)} \xrightarrow{\text{Predictions}} \text{Throttle/Sync} \xrightarrow{\text{REST API}} \text{MongoDB}$$

Before introducing code changes, this inspection audits the existing codebase across all relevant subsystems to ensure architectural alignment, identify edge cases, enforce dispatch safety, and establish the implementation plan.

---

## 2. Audit of Existing Components

### 2.1 Camera Ingestion & Temporal Buffer
- **[lib/core/camera/camera_frame.dart](file:///b:/SentinelX/lib/core/camera/camera_frame.dart):**
  - Encapsulates `CameraFrame` with metadata (`cameraId`, `deviceName`, `timestamp`, `frameIndex`, `acquisitionLatencyMs`, `status`).
  - Implements `toPlanarNormalized()` which transforms packed $[224, 224, 3]$ RGB uint8 bytes to ImageNet normalized planar float32 arrays $[3, 224, 224]$ ($(\text{pixel}/255 - \mu) / \sigma$).
- **[lib/core/camera/temporal_frame_buffer.dart](file:///b:/SentinelX/lib/core/camera/temporal_frame_buffer.dart):**
  - Maintains a bounded FIFO ring buffer of capacity 16.
  - Enforces monotonic timestamp ordering ($t_0 \le t_1 \le \dots \le t_{15}$).
  - `getPaddedSequence()` provides head-padded clones when fewer than 16 frames have been ingested, ensuring immediate model readiness without crashing.
  - `toTensor1x16x3x224x224()` constructs the contiguous planar float tensor ($1 \times 16 \times 3 \times 224 \times 224 = 2,408,448$ floats, $\approx 9.63\text{ MB}$).
- **[lib/core/camera/camera_ingestion_service.dart](file:///b:/SentinelX/lib/core/camera/camera_ingestion_service.dart):**
  - Operates on Windows Desktop via periodic `CameraController.takePicture()` calls (accommodating `camera_windows` limitations where `startImageStream` is unimplemented).
  - Uses Flutter Skia C++ `ui.instantiateImageCodec` to decode and resize directly to $224 \times 224$ RGB.
  - Deletes temporary files immediately.
  - Emits frames on `frameStream` and telemetry on `telemetryStream`.

### 2.2 Native ONNX Runtime FFI Bridge
- **[lib/services/onnx_native_bridge.dart](file:///b:/SentinelX/lib/services/onnx_native_bridge.dart):**
  - Binds to official `onnxruntime.dll` (v1.32.0, AVX2 multi-threaded `CPUExecutionProvider`).
  - Preloads official DLL to bypass stripped-down Windows 11 Germanium System32 DLL.
  - `initializeSession()` creates `OrtSession` directly from in-memory byte buffer `assets/models/sentinelx_model.onnx` (19.44 MB, 20,386,197 bytes, SHA-256: `79a7b83881078329ce6a4b5d64655823f94432fd340dd6f882d98adc0747fe1f`).
  - `executeInference()` expects:
    - Input 0: `video_frames` `[1, 16, 3, 224, 224]` Float32
    - Input 1: `audio_spectrogram` `[1, 1, 128, 128]` Float32
  - Outputs:
    - Output 0: `threat_probabilities` `[1, 5]` Float32 (Softmax)
    - Output 1: `bounding_boxes` `[1, 4]` Float32 (Sigmoid)
  - Properly releases all native allocated tensors (`OrtValueTensor.release()`) in `finally` blocks to prevent memory leaks.

### 2.3 Acoustic Modality & Degraded Mode Contract
- **Current Limitation:** SentinelX does not currently have a live microphone acquisition pipeline in Flutter Desktop or Android.
- **Contract Requirement:** The ONNX graph strictly requires the `audio_spectrogram` input `[1, 1, 128, 128]`. Passing random noise or zero tensors would introduce unverified artifacts.
- **Authoritative Baseline:** In [server_ml/preprocessor.py](file:///b:/SentinelX/server_ml/preprocessor.py#L279-L292), `get_acoustic_silence()` generates a calibrated baseline tensor filled with $-80.0\text{ dB}$ (top_db log-decibel scale representation of silence).
- **Audit Mandate:** In Flutter, we must implement an equivalent deterministic generator producing `[1, 1, 128, 128]` at $-80.0\text{ dB}$. Every prediction produced using this baseline must be explicitly flagged with `isDegradedMode = true` (`video_only_degraded`), and must NEVER claim verified multimodal accuracy.

### 2.4 Throughput & Concurrency Dynamics
- **Camera Acquisition Rate:** Camera ingestion runs at $\approx 10-30\text{ FPS}$ ($33-100\text{ ms}$ per frame).
- **ONNX Forward Pass Latency:** Native execution on CPU (`CPUExecutionProvider`) takes $\approx 1,300-1,500\text{ ms}$ per pass ($\approx 0.7\text{ FPS}$).
- **Concurrency Danger:** If the scheduler attempted to run a forward pass on every ingested frame, tens of simultaneous FFI threads would deadlock or overwhelm memory.
- **Solution:** Strict non-blocking concurrency guard:
  ```dart
  if (_isInferring) {
    _skippedFramesCount++;
    return;
  }
  ```
  While inference $N$ is executing, camera ingestion continues uninterrupted into the 16-frame rolling buffer. When inference $N$ completes, the next tick grabs the freshest 16 frames. Skipped frame cycles are recorded in real-time telemetry.

### 2.5 Bounding Box Semantics & Viewport Clipping
- Model predicts normalized `[x, y, w, h]` via `nn.Sigmoid()`.
- Phase 4.2.2 established that while coordinates fall in $[0, 1]$, the model does not enforce $x + w \le 1.0$ or $y + h \le 1.0$.
- Bounding box rendering must clip dimensions:
  $$w_{\text{clipped}} = \min(w, 1.0 - x), \quad h_{\text{clipped}} = \min(h, 1.0 - y)$$
- Bounding boxes are explicitly uncalibrated for physical tactical response.

### 2.6 Incident Sync, Throttling & Dispatch Safety
- **Backend Ingestion Contract ([backend/src/controllers/logs.controller.js](file:///b:/SentinelX/backend/src/controllers/logs.controller.js)):**
  - Clients calling `POST /api/logs` without server HMAC auth have `detectionSource` mapped to `manual_entry`.
  - Detections passing through `POST /api/detect` are tagged `ml_real` or `subprocess_fallback`.
  - Severity is derived automatically by Mongoose `pre('save')` based on confidence bands ($< 0.50 \to \text{low}$, $0.50-0.69 \to \text{medium}$, $0.70-0.84 \to \text{high}$, $\ge 0.85 \to \text{critical}$).
  - `Normal` class predictions strictly evaluate to `severity: 'normal'` and `detectionStatus: 'normal'`.
- **Throttling Policy:** Continuous inference completing every $1.4\text{s}$ must NOT flood the database with 40 records per minute:
  1. `Normal` predictions are displayed in the local UI but are NEVER written to the database.
  2. Anomaly predictions ($P \ge 0.50$) are throttled: a cooldown period (e.g. 5 seconds) per camera/threat class prevents duplicate log creation for continuing incidents.
  3. Edge detections are tagged with model metadata and latency metrics.

---

## 3. Structural Gap Analysis

| Subsystem | Existing State | Required Phase 4.3.2 Implementation |
| :--- | :--- | :--- |
| **Acoustic Input** | No audio pipeline; mock random spectrograms in prototype tests | Dedicated [AcousticSilenceGenerator](file:///b:/SentinelX/lib/core/ml/acoustic_silence_generator.dart) producing deterministic $-80.0\text{ dB}$ tensor `[1, 1, 128, 128]` |
| **Inference Loop** | Manual benchmark trigger only | [ContinuousInferenceScheduler](file:///b:/SentinelX/lib/core/ml/continuous_inference_scheduler.dart) listening to camera stream with non-blocking concurrency guard |
| **Degraded Mode Tagging** | Implicit/untracked | Formal `isDegradedMode = true` and `video_only_degraded` metadata flag on all predictions |
| **Backend Sync** | Standalone `CrimeLogService.runDetection()` | [DetectionSyncService](file:///b:/SentinelX/lib/core/ml/detection_sync_service.dart) with stateful 5s cooldown throttling |
| **UI Telemetry HUD** | Camera ingestion status only | Cyberpunk HUD overlay showing Inference State, Degraded Mode Badge, Camera FPS vs Inference FPS, Latency, and Predictions |

---

## 4. Implementation Plan

1. **Step 1: Deterministic Acoustic Silence Generator**
   - Create [lib/core/ml/acoustic_silence_generator.dart](file:///b:/SentinelX/lib/core/ml/acoustic_silence_generator.dart) generating `Float32List(16384)` with $-80.0\text{ dB}$.
2. **Step 2: Continuous Real-Time ONNX Inference Scheduler**
   - Create [lib/core/ml/continuous_inference_scheduler.dart](file:///b:/SentinelX/lib/core/ml/continuous_inference_scheduler.dart).
   - Wire `CameraIngestionService.frameStream` $\to$ `TemporalFrameBuffer.toTensor1x16x3x224x224()` + `AcousticSilenceGenerator` $\to$ `OnnxNativeBridge.executeInference()`.
   - Implement concurrency locks, skipped cycle counters, latency measurement, and prediction normalization with bounding box canvas clipping.
3. **Step 3: Detection Sync & Incident Throttling Service**
   - Create [lib/core/ml/detection_sync_service.dart](file:///b:/SentinelX/lib/core/ml/detection_sync_service.dart).
   - Filter `Normal` classifications; throttle repeated anomaly alerts with a 5-second sliding cooldown window; submit confirmed anomalies to Express backend.
4. **Step 4: Riverpod Providers & UI Integration**
   - Expose scheduler and sync services in [lib/core/providers/providers.dart](file:///b:/SentinelX/lib/core/providers/providers.dart).
   - Update [HardwareCameraView](file:///b:/SentinelX/lib/features/camera/widgets/hardware_camera_view.dart) and [DashboardScreen](file:///b:/SentinelX/lib/features/dashboard/screens/dashboard_screen.dart) to display live inference telemetry, degraded mode warning pill, and clipped bounding boxes.
5. **Step 5: Automated Test Suite**
   - Author [test/unit/continuous_inference_test.dart](file:///b:/SentinelX/test/unit/continuous_inference_test.dart) covering all invariants.
6. **Step 6: Empirical Hardware Benchmark & Full-Stack Regression Verification**
   - Execute benchmark script measuring true Flutter camera ingestion + native ONNX inference performance.
   - Run complete platform regression suite (14+ test suites).
   - Generate `PHASE4_3_2_IMPLEMENTATION_REPORT.md` and `PHASE4_3_2_BENCHMARK_REPORT.md`.
