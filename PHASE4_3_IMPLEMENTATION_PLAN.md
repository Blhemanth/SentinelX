# SentinelX — Phase 4.3: Real-Time Edge Inference & Background Isolate Architecture Plan

**Document Version:** 1.0.0  
**Date:** 2026-11-22  
**Author:** Principal Flutter Architect, ONNX Runtime Systems Engineer & ML Edge Specialist  
**Classification:** Strategic Architectural & Implementation Plan  
**Target Scope:** Flutter Desktop (Windows x64), Flutter Mobile (Android ARM64), Native ONNX C-FFI, Dart Background Isolates  

---

## 1. Executive Summary & Objective

Phase 4.2 proved that the multimodal ONNX model (`assets/models/sentinelx_model.onnx`, 19.44 MB) executes natively via C-FFI on Windows Desktop x64 and compiles for Android ARM64. However, multi-pass empirical benchmarking revealed that full multimodal forward inference requires **$1{,}300\text{ ms} - 1{,}600\text{ ms}$ on CPU** (`CPUExecutionProvider` with native AVX2).

If executed synchronously on the main thread, this computation would drop the Flutter UI framerate to **$\sim 0.62\text{ FPS}$**, completely stalling the event loop, freezing user interactions, and causing severe stutter in camera view rendering.

### Primary Phase 4.3 Objective
To architect, implement, and verify a **zero-jank, continuous edge inference pipeline** capable of streaming live camera frames and audio waveforms into a dedicated **background worker Dart Isolate**, executing native ONNX Runtime inference, and synchronizing predictions to the UI at a **stable 60 FPS**.

---

## 2. Architectural Blueprint: The Multi-Isolate Pipeline

```
+-------------------------------------------------------------------------------------------------------+
|                                        MAIN FLUTTER UI ISOLATE                                        |
|                                                                                                       |
|  +----------------------------------+                   +------------------------------------------+  |
|  |     Camera Preview Widget        |                   |      Detection Overlay Painter           |  |
|  |   - 30/60 FPS Hardware Render    |                   |   - Normalized Bounding Boxes [x,y,w,h]  |  |
|  |   - Zero-Copy GPU Texture        |                   |   - Canvas Clamping (min(w, 1.0 - x))    |  |
|  +----------------------------------+                   +------------------------------------------+  |
|                    │                                                         ▲                        |
|   Image Stream     ▼                                                         │  Prediction Event      |
|  +----------------------------------+                   +------------------------------------------+  |
|  |   Camera Frame Downsampler       |                   |       Inference Riverpod State           |  |
|  |   - Decimates to 10 FPS          |                   |   - Threat Class & Confidence            |  |
|  |   - Dispatches to Isolate Port   |                   |   - Telemetry Latency & Source           |  |
|  +----------------------------------+                   +------------------------------------------+  |
|                    │                                                         ▲                        |
+--------------------│---------------------------------------------------------│------------------------+
                     │                                                         │
         SendPort    ▼                                                         │  ReceivePort
   (TransferableTypedData / Shared Memory)                       (InferenceResult Event)
+-------------------------------------------------------------------------------------------------------+
|                                    BACKGROUND INFERENCE WORKER ISOLATE                                |
|                                                                                                       |
|  +-------------------------------------------------------------------------------------------------+  |
|  |                                  Sliding Temporal Ring Buffers                                  |  |
|  |  - Video Buffer: 16 Uniform Frames [1, 16, 3, 224, 224] (ImageNet Normalized Float32List)       |  |
|  |  - Audio Buffer: 1-Second Mel-Spectrogram [1, 1, 128, 128] (Or Calibrated -80dB Baseline)      |  |
|  +-------------------------------------------------------------------------------------------------+  |
|                                                  │                                                    |
|                                                  ▼                                                    |
|  +-------------------------------------------------------------------------------------------------+  |
|  |                              Native ONNX Runtime C-FFI Execution                                |  |
|  |  - Session: OrtSession initialized once inside Isolate memory space                             |  |
|  |  - Provider: CPUExecutionProvider (AVX2 Multi-Threaded)                                         |  |
|  |  - Forward Pass: [video_frames, audio_spectrogram] -> [threat_probabilities, bounding_boxes]    |  |
|  +-------------------------------------------------------------------------------------------------+  |
|                                                  │                                                    |
|                                                  ▼                                                    |
|  +-------------------------------------------------------------------------------------------------+  |
|  |                              Post-Processing & Anomaly Detection                                |  |
|  |  - Softmax / ArgMax extraction across 5 classes (Normal, Fighting, Robbery, Burglary, Weapon)  |  |
|  |  - Bounding Box Normalization & Clamping Validation                                             |  |
|  |  - Threshold Evaluation (Emergency threshold: 0.85; Review threshold: 0.50)                     |  |
|  +-------------------------------------------------------------------------------------------------+  |
+-------------------------------------------------------------------------------------------------------+
```

---

## 3. Detailed Component Specifications

### 3.1 Background Worker Isolate Lifecycle & Communication
1. **Spawning:** The background isolate is spawned on application startup via `Isolate.spawn(inferenceWorkerEntryPoint, initPayload)`.
2. **Model Initialization:** The 19.44 MB ONNX model buffer (`ByteData`) is passed once during isolate initialization. The `OrtSession` is constructed and cached inside isolate memory, preventing duplicate native DLL allocations.
3. **Bidirectional Channel:**
   - `commandPort` (`SendPort`): Main UI thread sends `InferenceCommand.processFrame(frameBytes, width, height, format)` and `InferenceCommand.processAudio(pcmBytes)`.
   - `resultPort` (`ReceivePort`): Background isolate emits `InferenceResponse(threatClass, confidence, bbox, inferenceMs)`.
4. **Backpressure & Drop Policy:** If a new frame arrives while native ONNX inference is actively executing ($1.3\text{s}$ latency), the isolate updates its internal ring buffer but drops excess triggers until the current inference pass completes. This prevents queuing memory leaks.

### 3.2 Video Preprocessing & Temporal Ring Buffer
1. **Camera Frame Extraction:**
   - Windows: Media Foundation capture via `camera_windows`.
   - Android: CameraX YUV420 capture via `camera_android_camerax`.
2. **Downsampling:** Raw camera preview runs at $30\text{ FPS}$ on GPU. Frames captured for inference are sampled at $\sim 10\text{ FPS}$ and resized to $224 \times 224 \times 3$ RGB.
3. **Temporal Sampling:** The sliding buffer holds 16 frames. When full, it constructs the NCHW tensor:
   $$\text{Shape: } [1, 16, 3, 224, 224] \quad (\approx 9.63\text{ MB Float32List})$$
4. **Standardization:** Pixels normalized using standard ImageNet parameters:
   $$\mu = [0.485, 0.456, 0.406], \quad \sigma = [0.229, 0.224, 0.225]$$

### 3.3 Audio Stream & Baseline Ingestion
1. **Microphone Capture:** 16 kHz, 16-bit Mono Linear PCM.
2. **Temporal Window:** 1.0 second buffer ($16{,}000$ samples).
3. **Calibrated Baseline:** If audio capture is disabled, unavailable, or silent, the isolate automatically supplies the calibrated acoustic silence baseline tensor:
   $$\text{audio\_spectrogram: } [1, 1, 128, 128] \quad (\text{filled with } -80.0\text{ dB})$$

### 3.4 Bounding Box Post-Processing & Canvas Painter
1. **Raw Model Output:** 4 floats representing $[y_{min}, x_{min}, y_{max}, x_{max}]$.
2. **Coordinate Normalization:** Converted to $[x, y, w, h]$ format normalized in $[0.0, 1.0]$.
3. **Boundary Clamping:**
   $$\text{render\_w} = \min(w, 1.0 - x), \qquad \text{render\_h} = \min(h, 1.0 - y)$$
4. **UI Painter:** `DetectionOverlayPainter` renders a high-visibility neon HUD bounding box with confidence pill and threat class label directly over the camera texture.

---

## 4. Phase 4.3 Implementation Roadmap & Milestones

| Milestone | Task Description | Deliverables | Verification Target |
| :---: | :--- | :--- | :--- |
| **Stage 1** | **Isolate Infrastructure & Messaging** | `lib/core/ml/inference_worker.dart`<br>`lib/core/ml/inference_protocol.dart` | Zero memory leak; bidirectional message ping $<2\text{ms}$. |
| **Stage 2** | **Temporal Ring Buffer & Image Pipeline** | `lib/core/ml/temporal_frame_buffer.dart`<br>`lib/core/ml/image_preprocessor.dart` | Correct tensor shape `[1, 16, 3, 224, 224]` verified via unit test. |
| **Stage 3** | **Audio Pipeline & Silence Baseline** | `lib/core/ml/audio_spectrogram_generator.dart` | Exact `[1, 1, 128, 128]` spectrogram or calibrated $-80\text{dB}$ fallback. |
| **Stage 4** | **In-Isolate Native ONNX Execution** | `lib/core/ml/native_onnx_service.dart` | Isolate runs inference in background without blocking UI thread. |
| **Stage 5** | **Riverpod Integration & 60 FPS UI Overlay** | `lib/features/camera/presentation/widgets/hardware_camera_view.dart`<br>`lib/core/providers/detection_provider.dart` | Profile mode verifies solid $60\text{ FPS}$ UI under continuous inference. |

---

## 5. Safety Invariants & Engineering Constraints

1. **Strict Threat Taxonomy:** Model output classes remain strictly mapped to:
   `0: Normal`, `1: Fighting`, `2: Robbery`, `3: Burglary`, `4: Weapon_Detected`.
2. **Emergency Threshold Preservation:** Real emergency escalation requires $\text{confidence} \ge 0.85$ and a genuine anomaly class.
3. **Dispatch Isolation:** Local edge detections are tagged as `detectionSource: 'ml_real'`. They do NOT trigger external police dispatch directly from the client; dispatch eligibility is derived authoritatively by the Express backend.
4. **Fail-Safe UI Thread Isolation:** If the background isolate crashes or encounters an out-of-memory condition, the UI isolate catches the error via `isolate.addErrorListener` and presents a graceful warning banner without crashing the application.
