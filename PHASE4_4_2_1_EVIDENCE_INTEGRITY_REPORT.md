# SentinelX — Phase 4.4.2.1: Evidence Integrity Report

**Author:** Principal Multimodal Systems Architect, Flutter Windows Engineer, ONNX Runtime Specialist & Performance Auditor  
**Date:** 2026-11-23  
**Audited Artifacts:**
- Implementation Source: `lib/core/utils/monotonic_clock.dart`, `lib/core/camera/camera_ingestion_service.dart`, `lib/core/camera/camera_frame.dart`, `lib/core/camera/temporal_frame_buffer.dart`, `lib/core/audio/audio_ingestion_service.dart`, `lib/core/audio/temporal_audio_buffer.dart`, `lib/core/ml/multimodal_synchronizer.dart`, `lib/core/ml/continuous_inference_scheduler.dart`, `lib/core/ml/onnx_inference_worker.dart`
- Test Runner & Telemetry: `test/flutter_multimodal_hardware_runner.dart`, `test/flutter_multimodal_hardware_telemetry.json`
- Native Library: `B:\SentinelX\onnxruntime.dll`
- Phase 4.4.2 Reports: `PHASE4_4_2_SYNCHRONIZATION_ARCHITECTURE_REPORT.md` through `PHASE4_4_2_FINAL_GATE_REPORT.md`
**Classification:** **VERIFIED & RECONCILED**

---

## 1. Executive Summary & Audit Mandate

Phase 4.4.2 introduced simultaneous physical webcam and microphone ingestion, pure Dart DSP preprocessing, timestamp-based synchronization, and background isolate ONNX inference. An independent technical audit of the Phase 4.4.2 implementation and its eight submitted reports identified measurement inconsistencies, documentation typos, and overclaims regarding statistical stability, frame rates, and model accuracy.

In accordance with Phase 4.4.2.1 mandate, this audit investigated the original source code, Windows Win32 bindings, native ONNX Runtime DLL properties, and raw hardware telemetry. No working code has been refactored or broken. This report details every discrepancy, provides mathematical and architectural reconciliations, establishes precise technical terminology, and documents all remaining operational uncertainties.

---

## 2. Reconciled Evidence & Finding Analysis

### Finding 1: Timestamp Semantics & Ingestion-Time Synchronization

#### A. Empirical Investigation
Inspection of [lib/core/camera/camera_ingestion_service.dart](file:///b:/SentinelX/lib/core/camera/camera_ingestion_service.dart) reveals the exact call sequence during video capture:
```dart
// 1. Hardware capture via CameraController
final xFile = await _controller!.takePicture();
final jpegBytes = await xFile.readAsBytes();
...
// 2. High-performance Skia C++ decode & resize to 224x224 RGB
final rgbBytes = await _decodeAndResizeRgb(jpegBytes, 224, 224);

stopwatch.stop();
final latencyMs = stopwatch.elapsedMilliseconds;

_frameIndex++;
final captureTime = MonotonicClock.now(); // <-- TIMESTAMP RECORDED HERE
```
Inspection of [lib/core/audio/audio_ingestion_service.dart](file:///b:/SentinelX/lib/core/audio/audio_ingestion_service.dart) reveals the exact chunk delivery listener:
```dart
_streamSubscription = stream.listen(
  (Uint8List chunk) {
    final monoNow = MonotonicClock.now(); // <-- TIMESTAMP RECORDED HERE
    temporalBuffer.pushPcm16Bytes(
      chunk,
      captureTime: monoNow.utc,
      monotonicUs: monoNow.monotonicUs,
    );
```

#### B. Architectural Reconciliation
1. **Camera Frame Timing:** The camera timestamp is captured *after* physical camera sensor exposure, *after* Win32 DirectShow driver delivery, *after* JPEG disk writes/reads, and *after* Skia C++ decoding/resizing. The elapsed acquisition latency is explicitly measured as $120–240\text{ ms}$.
2. **Audio Chunk Timing:** The audio timestamp is captured when the Windows WASAPI streaming audio client delivers a buffer chunk across the platform channel into the Dart event loop callback.
3. **Hardware Limitation:** Neither `camera_windows` nor `record_windows` exposes physical hardware sensor exposure registers or hardware clock timestamps to Flutter.
4. **Conclusion & Terminology Correction:** The system measures **software stream ingestion-time synchronization** (delivery-time alignment), *not* physical hardware exposure-time alignment. Claims of "sub-25ms physical capture-time alignment" are formally amended to **"sub-25ms software delivery-time alignment"**.
5. **Clock Domain Compatibility:** Both services query `MonotonicClock.now()`, which reads a single static `Stopwatch` instance mapped to Win32 `QueryPerformanceCounter` (QPC). The monotonic clock domain is strictly identical and immune to NTP drift.
6. **Fallback Behavior:** If monotonic timestamps are zero or absent, `MultimodalSynchronizer` falls back to UTC difference. If stream age exceeds $2{,}000\text{ ms}$, the stream is flagged stale and fails closed to degraded mode ($-80.0\text{ dB}$ silence plane).

---

### Finding 2: Statistical Reconciliation of Synchronization Telemetry

#### A. Empirical Investigation
In [test/flutter_multimodal_hardware_telemetry.json](file:///b:/SentinelX/test/flutter_multimodal_hardware_telemetry.json), exactly 4 inference evaluations were performed during the 14.47-second run:
- Pass 1: `uninitializedOrStale` (Audio warming up: 35,169 / 64,000 samples)
- Pass 2: `videoOnlyDegraded` (Audio buffer validating: 37,409 / 64,000 samples)
- Pass 3: `synchronized` (Audio-video offset: 16 ms)
- Pass 4: `synchronized` (Audio-video offset: 20 ms)

#### B. Mathematical Recalculation
In [lib/core/ml/multimodal_synchronizer.dart](file:///b:/SentinelX/lib/core/ml/multimodal_synchronizer.dart), `_calculateJitter()` executes:
$$\sigma = \sqrt{\frac{1}{N}\sum_{i=1}^{N}(x_i - \bar{x})^2}$$
For observations $x \in \{16, 20\}$ ($N = 2$):
- **Sample Count:** $N = 2$
- **Mean Offset:** $\bar{x} = \frac{16 + 20}{2} = 18.0\text{ ms}$
- **Minimum Offset:** $16\text{ ms}$
- **Maximum Offset:** $20\text{ ms}$
- **Population Standard Deviation ($\sigma_p$):** $\sqrt{\frac{(16-18)^2 + (20-18)^2}{2}} = \sqrt{\frac{4+4}{2}} = \mathbf{2.0\text{ ms}}$
- **Sample Standard Deviation ($s$, Bessel's Correction):** $\sqrt{\frac{(16-18)^2 + (20-18)^2}{2-1}} = \sqrt{\frac{8}{1}} = \mathbf{2.83\text{ ms}}$
- **Rejection Count:** $0$ rejections

#### C. Statistical Claim Correction
The reported $2.0\text{ ms}$ jitter is the **population standard deviation** of the internal rolling buffer, while the unbiased **sample standard deviation** is $2.83\text{ ms}$. Crucially, **two observations ($N=2$) do not establish long-term statistical stability**. The Phase 4.4.2 run verified functional multimodal synchronization across consecutive cycles, but long-term sustained stability over hundreds of cycles is marked as **PENDING (Scheduled for Phase 4.4.3 / Phase 4.5 sustained multi-minute execution)**.

---

### Finding 3: Camera Acquisition Frame Rate & Execution Duration

#### A. Empirical Investigation
The Phase 4.4.2 reports presented three divergent figures:
1. "Approximately 10 FPS" (Architecture Report)
2. "7.15–7.33 FPS" (Performance Report)
3. "60 frames over 14.465 seconds" (Final Gate Report)

#### B. Mathematical Reconciliation
From `test/flutter_multimodal_hardware_telemetry.json`:
- `start_utc`: `2026-11-23T02:59:57.850577Z`
- `end_utc`: `2026-11-23T03:00:12.316375Z`
- `duration_seconds`: `14.465` s
- `total_captured_frames`: `60` frames

The true aggregate physical capture rate is:
$$\text{FPS}_{\text{capture}} = \frac{60\text{ frames}}{14.465\text{ s}} = \mathbf{4.148\text{ FPS}}$$

#### C. Root Cause & Disaggregation
1. **Why 4.15 FPS vs 10 FPS Target?** In `CameraIngestionService`, the acquisition loop sets a target timer interval of $100\text{ ms}$ ($10\text{ FPS}$). However, `takePicture()` involves Win32 DirectShow camera exposure, file system write of JPEG bytes, and Skia decoding to uncompressed RGB. This combined decode latency took $120–240\text{ ms}$. Because the `_isAcquiring` concurrency guard drops timer ticks while acquisition is in flight, the effective physical capture rate yielded $\approx 4.15\text{ FPS}$.
2. **Where Did 7.15–7.33 FPS Come From?** In Phase 4.3.5, the camera ran in video-only mode without audio streaming, sustaining $7.15\text{ FPS}$ (60s run) and $7.33\text{ FPS}$ (Phase 4.3.5.2 600s baseline). Conflating the historical video-only baseline with the Phase 4.4.2 multimodal test was an error across distinct measurement windows.
3. **Disaggregated Frame Accounting (Phase 4.4.2):**
   - **Physical frames captured & decoded:** 60 frames.
   - **Frames inserted into `TemporalFrameBuffer`:** 60 frames.
   - **Frames retained in rolling window:** 16 frames.
   - **Frames evicted by ring buffer:** 44 frames.
   - **Inference forward passes triggered:** 4 passes.
   - **Frames skipped by scheduler concurrency guard:** 56 frames (dropped while ~2.47s inference passes were in-flight).

---

### Finding 4: Inference Latency Timing Boundaries & ONNX Versioning

#### A. Latency Boundaries Breakdown
From `test/flutter_multimodal_hardware_telemetry.json`:
- **Pass 1 (Degraded):** Total $2{,}779\text{ ms}$ (Native C-FFI $2{,}772\text{ ms}$, Transfer $7\text{ ms}$)
- **Pass 2 (Degraded):** Total $2{,}688\text{ ms}$ (Native C-FFI $2{,}682\text{ ms}$, Transfer $6\text{ ms}$)
- **Pass 3 (Multimodal Synchronized):** Total **$2{,}497\text{ ms}$** (Native C-FFI $2{,}492\text{ ms}$, Transfer $5\text{ ms}$)
- **Pass 4 (Multimodal Synchronized):** Total **$2{,}446\text{ ms}$** (Native C-FFI $2{,}441\text{ ms}$, Transfer $5\text{ ms}$)

#### B. Mean Latency Reconciliation
- **Multimodal Synchronized Mean (Passes 3 & 4):** $\frac{2497 + 2446}{2} = \mathbf{2{,}471.5\text{ ms}}$
- **Degraded / Cold-Start Mean (Passes 1 & 2):** $\frac{2779 + 2688}{2} = \mathbf{2{,}733.5\text{ ms}}$
- **Aggregate Run Mean (All 4 Passes):** $\frac{2779 + 2688 + 2497 + 2446}{4} = \mathbf{2{,}602.5\text{ ms}}$
- **Clarification:** The reported $2{,}471.5\text{ ms}$ applies **exclusively to the two synchronized multimodal passes**. Conflating synchronized steady-state with degraded warmup is avoided.

#### C. ONNX Runtime DLL Version Resolution (1.32.0 vs 1.20.1)
- In `PHASE4_4_2_PERFORMANCE_REPORT.md` Section 4 and `PHASE4_4_2_FINAL_GATE_REPORT.md`, the text erroneously referenced `onnxruntime.dll v1.20.1`.
- Direct file version inspection of `B:\SentinelX\onnxruntime.dll` via PowerShell confirmed:
  ```
  FileVersion    : 1.32.0.20261112.6.fab30a4
  ProductVersion : 1.32.0.20261112.6.fab30a4
  ProductName    : Microsoft® Windows® Operating System
  ```
- Direct execution of `onnx_native_execution_test.dart` and `flutter_multimodal_hardware_runner.dart` confirmed runtime string:
  ```
  [Test 1] Native ONNX Runtime Version: 1.32.0
  [Worker] Background isolate ready: ONNX Runtime 1.32.0
  ```
- **Correction:** The loaded and running ONNX Runtime version is **1.32.0** (`1.32.0.20261112.6.fab30a4`). The reference to "1.20.1" was an errant copy-paste typo from upstream ONNX documentation.

---

### Finding 5: Memory Domain Disaggregation & Leak Claims

#### A. Empirical Measurements
From `test/flutter_multimodal_hardware_telemetry.json`:
- `initial_rss_mb`: `210.23 MB`
- `peak_rss_mb`: `838.59 MB`
- `final_rss_mb`: `743.29 MB`

#### B. Memory Domain Disaggregation
1. **Video Buffer Allocation:** `TemporalFrameBuffer(capacity: 16)` holds 16 uncompressed RGB frames ($16 \times 224 \times 224 \times 3\text{ bytes} = \mathbf{2.30\text{ MB}}$).
2. **Transient Planar Tensor Allocation:** `CameraFrame.toPlanarNormalized()` generates a Float32 array of shape $[1, 16, 3, 224, 224]$ ($16 \times 3 \times 224 \times 224 \times 4\text{ bytes} = \mathbf{9.19\text{ MB}}$). This is allocated per pass and transferred to the worker isolate. Conflating the 2.30 MB RGB storage with the 9.19 MB planar tensor is corrected.
3. **Audio Buffer Allocation:** `TemporalAudioBuffer(capacity: 65536)` pre-allocates a single `Float32List(65536)` ($\mathbf{256.0\text{ KB}}$), operating as a circular ring buffer with $O(1)$ memory.
4. **Native Allocations:** Managed inside `onnxruntime.dll` (weights $20.4\text{ MB}$, execution graph workspace memory arena).
5. **Memory Claim Correction:** Process RSS measures OS physical page working set. RSS expanding to 838.59 MB and contracting to 743.29 MB shows bounded stabilization, but **does not prove zero native micro-leaks**. True zero-leak proof requires native profilers (e.g., Windows Performance Toolkit / ETW). This limitation is explicitly documented.

---

### Finding 6: Flutter UI Timing & Presentation Dynamics

#### A. Empirical Measurements
From `test/flutter_multimodal_hardware_telemetry.json`:
- `total_rendered_frames`: `127`
- `measured_ui_fps`: `8.78 FPS`
- `jank_frames`: `7`
- `jank_percentage`: `5.51%`
- `fluid_percentage`: `94.49%`

#### B. Technical Clarification
1. **Jank Metric:** A frame is classified as jank if $\text{buildDuration} + \text{rasterDuration} > 16.67\text{ ms}$. Out of 127 frames, 120 completed build and rasterization within $16.67\text{ ms}$ ($94.49\%$ non-jank).
2. **Demand-Driven Presentation:** In Flutter Desktop, the engine renders on-demand when widgets are marked dirty. Over 14.465s, 127 frames were rasterized ($8.78\text{ FPS}$ delivery rate, $113.9\text{ ms}$ average presentation interval).
3. **Correction:** The $94.49\%$ fluidity figure represents the fraction of frames that built and rasterized within the $16.67\text{ ms}$ budget; it must **not** be described or claimed as a "60 FPS rendering rate".

---

### Finding 7: Model Output Ground-Truth Accuracy Boundaries

#### A. Empirical Model Outputs
- Pass 3: Class `Fighting` ($28.90\%$), bbox $[0.4174, 0.4809, 0.5572, 0.5191]$
- Pass 4: Class `Fighting` ($28.68\%$), bbox $[0.4161, 0.4844, 0.5587, 0.5156]$

#### B. Critical Boundary Clarification
1. **Functional Verification (VERIFIED):** The model ran successfully via native C-FFI, ingested physical normalized tensors, and produced valid floating-point numbers without NaN or null crashes.
2. **Detection Accuracy (UNVERIFIED):** Testing occurred in a static developer room. A 28.9% probability for `Fighting` across a 5-class near-uniform distribution is a low-confidence artifact of an uncalibrated room scene.
3. **Safety Contract:** Under SentinelX rules, any confidence $<0.50$ is forced to `low` severity and `low_confidence_review`, with `isEmergencyEligible = false`.
4. **Correction:** The model output must not be cited as evidence of "correct threat classification" or "accurate bounding box localization". Ground-truth validation remains scheduled for Phase 4.5.

---

### Finding 8: Security Regression Verification

#### A. Audit Verification
All security controls established in Phase 4.2.6 were re-tested across the 4 backend security suites:
- `backend/test_phase4_2_6_verification.js`: 25 / 25 pass
- `backend/test_phase4_2_5_adversarial.js`: 19 / 19 pass
- `backend/test_phase4_2_3_dispatch_isolation.js`: 17 / 17 pass
- `backend/test_phase4_2_4_adversarial.js`: 15 / 15 pass
- **Total Security Tests:** **76 / 76 pass (100%)**.

#### B. Trust Boundaries Confirmed
1. Zero HMAC keys exist in the Flutter client (`lib/`, `assets/`, `windows/`).
2. Public client submissions via `POST /api/logs` are stripped of `severity` and forced to `manual_entry`.
3. Server-to-server endpoints enforce Protocol v2 HMAC-SHA256 request-binding (method, path, body hash, timestamp, nonce).
4. Drill simulations are strictly isolated from real police dispatches.

---

## 3. Evidence Reconciliation Master Table

| # | Discrepancy / Parameter | Original Phase 4.4.2 Claim | Corrected Phase 4.4.2.1 Claim | Evidence Source | Verification Method | Remaining Uncertainty |
| :-: | :--- | :--- | :--- | :--- | :--- | :--- |
| **1** | **Timestamp Timing Semantics** | "Physical capture-time alignment" | **Software stream ingestion-time alignment** (post-decode for camera, callback arrival for audio) | `camera_ingestion_service.dart:231`, `audio_ingestion_service.dart:210` | Source code call-graph inspection | DirectShow hardware exposure registers unavailable in Flutter plugin |
| **2** | **Synchronization Statistics** | "$18.0\text{ ms}$ mean, $2.0\text{ ms}$ jitter proves long-term stability" | **$N=2$ observations; population SD = $2.0\text{ ms}$; sample SD = $2.83\text{ ms}$**. Long-term stability is **PENDING** | `flutter_multimodal_hardware_telemetry.json:28`, `multimodal_synchronizer.dart:295` | Sample ($s$) vs Population ($\sigma_p$) formula recalculation | Requires multi-minute sustained test ($N \ge 100$) |
| **3** | **Camera Frame Rate** | "7.15–7.33 FPS sustained / ~10 FPS" | **$4.15\text{ FPS}$ aggregate** ($60\text{ frames} / 14.465\text{ s}$) due to $120–240\text{ ms}$ `takePicture` + Skia decode latency | `flutter_multimodal_hardware_telemetry.json:7,15` | Exact interval arithmetic ($60 / 14.465$) | Future camera stream API may bypass JPEG re-encoding |
| **4** | **Inference Latency** | "$2,471.5\text{ ms}$ average latency across run" | **$2,471.5\text{ ms}$ applies only to the 2 synchronized passes**; degraded passes averaged $2,733.5\text{ ms}$; overall run averaged **$2,602.5\text{ ms}$** | `flutter_multimodal_hardware_telemetry.json:41-185` | Per-pass arithmetic disaggregation | AVX2 CPU execution variance under thermal load |
| **5** | **ONNX Runtime Version** | "onnxruntime.dll v1.20.1" | **v1.32.0** (`FileVersion: 1.32.0.20261112.6.fab30a4`) | `B:\SentinelX\onnxruntime.dll`, `OrtEnv.version` | PowerShell `Get-Item.VersionInfo` & test log verification | None (1.20.1 was documentation typo) |
| **6** | **Memory Buffer vs Tensor** | "2.30 MB video buffer memory" | **2.30 MB RGB byte storage** (16 frames); **9.19 MB planar Float32 tensor** (allocated per forward pass) | `temporal_frame_buffer.dart:94`, `camera_frame.dart:69` | Array dimension size calculation | Native ONNX arena sub-allocation sizes |
| **7** | **Zero Memory Leak Claims** | "Zero memory leaks proven by RSS" | **Bounded working-set stabilization proven** ($210 \to 838 \to 743\text{ MB}$); zero native micro-leaks cannot be proven without ETW | `flutter_multimodal_hardware_telemetry.json:194` | Memory domain boundary analysis | Native heap micro-fragmentation undetected by RSS |
| **8** | **UI Rendering Cadence** | "60 FPS presentation / 94.49% fluid" | **8.78 FPS demand-driven presentation rate**; **94.49% of frames built and rasterized in $\le 16.67\text{ ms}$** | `flutter_multimodal_hardware_telemetry.json:187-193` | `FrameTiming` threshold analysis | Display refresh rate vs engine dirty mark pacing |
| **9** | **Threat Classification Accuracy** | "Accurate Fighting detection and localization" | **Functional inference execution verified**; ground-truth detection accuracy / localization is **UNVERIFIED** | `flutter_multimodal_hardware_telemetry.json:60-74` | 4-tier validation model; absence of ground-truth test set | Awaits Phase 4.5 independent 1,000-clip dataset |
| **10**| **Security Trust Boundaries** | "100% security contract compliance" | **VERIFIED (100% preserved)**; 76 / 76 security tests pass; zero client secrets | `backend/test_phase4_2_6_verification.js` etc. | Executed full security regression suite | Distributed Redis cache required for multi-instance clusters |

---

## 4. Audit Conclusion & Operational Posture

The Phase 4.4.2.1 audit establishes that the core technical implementations of monotonic timestamping, dual-device streaming, pure Dart DSP preprocessing, background isolate execution, and security trust boundaries are sound, verified, and functioning properly. All documentation inconsistencies, statistical misattributions, and version typos have been completely resolved and corrected.
