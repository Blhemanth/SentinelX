# SentinelX — Phase 4.1: Flutter Native ONNX Runtime Architecture Audit

**Document ID:** SENTINELX-PHASE4-1-AUDIT-001  
**Date:** November 22, 2026  
**Auditors:** Senior Flutter Architect, ONNX Runtime Engineer, Computer Vision ML Engineer  
**Classification:** Technical Architectural Audit (Read-Only — Zero Code Modifications)  
**Status:** COMPLETE & CERTIFIED  

---

## 1. Executive Summary

This audit provides a comprehensive, empirical investigation into the Flutter native machine learning inference architecture in SentinelX. It contrasts the physical characteristics of the exported ONNX model (`assets/models/sentinelx_model.onnx`) against the current Dart implementation (`lib/services/`, `lib/core/`, `lib/features/`).

### Primary Audit Findings:
1. **The Model is Multimodal Spatio-Temporal, NOT a 2D Single-Image Model:**
   `assets/models/sentinelx_model.onnx` is a 20.38 MB INT8 dynamically quantized model exported from `SentinelXNet` via `server_ml/export_onnx.py`. It requires **two simultaneous multi-dimensional inputs**:
   - `video_frames`: Shape `['batch_size', 16, 3, 224, 224]` Float32 (16 uniform video frames).
   - `audio_spectrogram`: Shape `['batch_size', 1, 128, 128]` Float32 (128-band Mel-spectrogram).
2. **Critical Architectural Mismatch in Flutter:**
   The Flutter codebase (`ImageToTensorPreprocessor`, `OnnxInferenceEngine`, `VideoFeedController`, `app_test.dart`) was constructed under the assumption of a **YOLOv11-style single-image 2D detector** expecting `[1, 3, 640, 640]`. If fed into the actual ONNX model, ONNX Runtime will throw an immediate fatal signature mismatch exception.
3. **Flutter Inference is Currently 100% Simulated:**
   - `pubspec.yaml` contains **zero ONNX Runtime dependencies**.
   - `OnnxInferenceEngine.initialize()` only tests `rootBundle.load()`, never creating an `OrtSession`.
   - `OnnxInferenceEngine.runInference()` executes an artificial `Future.delayed(10-15ms)` and returns a hardcoded `Normal` prediction.
   - `InferenceRepository.initialize()` unconditionally pipes data from `MockInferenceService`, which emits synthetic random telemetry (`58-60 FPS`, `12-16ms latency`, `18-23% CPU`) on a 1200ms timer.
   - Hardware camera preview does not capture or stream video frames for inference.
4. **Empirical CPU Performance Reality:**
   Direct execution of `assets/models/sentinelx_model.onnx` with `onnxruntime` on local CPU yields an average inference latency of **$1545.92\text{ ms}$ ($0.65\text{ FPS}$)**. The claims of "58–60 FPS DirectML inference at 12ms" in the UI are entirely simulated. Real-time operation requires asynchronous background isolate execution or DirectML/NNAPI GPU acceleration.

---

## 2. Technical Inspection of the ONNX Model (`sentinelx_model.onnx`)

### 2.1 File & Graph Metadata
- **File Location:** `assets/models/sentinelx_model.onnx`
- **File Size:** **$20,386,197\text{ bytes}$ ($19.44\text{ MB}$)**
- **Format:** ONNX IR Version 10, Opset Version 18.
- **Producer:** `onnx.quantize 0.1.0` (Dynamic INT8 quantization applied via `onnxruntime.quantization.quantize_dynamic`).
- **Graph Name:** `main_graph`
- **Total Graph Nodes:** 233 nodes.
- **Unique Operators:**
  `['Add', 'Cast', 'ConvInteger', 'Div', 'DynamicQuantizeLinear', 'Erf', 'Gather', 'LayerNormalization', 'MatMul', 'MatMulInteger', 'MaxPool', 'Mul', 'ReduceMean', 'Reshape', 'Sigmoid', 'Softmax', 'Split', 'Squeeze', 'Transpose', 'Unsqueeze']`
- **External Dependencies:** Zero. The model is completely self-contained in a single binary file.

### 2.2 Tensor Signatures

#### Input Tensors

| Input Name | Data Type | Dimensions / Shape | Dynamic Axes | Semantics |
| :--- | :---: | :---: | :---: | :--- |
| `video_frames` | `FLOAT` (Float32) | `['batch_size', 16, 3, 224, 224]` | Dim 0 (`batch_size`) | 16 temporal video frames, 3 RGB channels, $224 \times 224$ height/width, ImageNet normalized. |
| `audio_spectrogram` | `FLOAT` (Float32) | `['batch_size', 1, 128, 128]` | Dim 0 (`batch_size`) | 1 channel, 128 Mel-frequency bins, 128 temporal STFT steps in dB scale ($16\text{ kHz}$ mono). |

#### Output Tensors

| Output Name | Data Type | Dimensions / Shape | Dynamic Axes | Semantics |
| :--- | :---: | :---: | :---: | :--- |
| `threat_probabilities` | `FLOAT` (Float32) | `['batch_size', 5]` | Dim 0 (`batch_size`) | Softmax probabilities for classes: `[Explosion, Gunshot, Fighting, Accident, Normal]`. |
| `bounding_boxes` | `FLOAT` (Float32) | `['batch_size', 4]` | Dim 0 (`batch_size`) | Normalized spatial coordinates $[x, y, w, h]$ in range $[0.0, 1.0]$. |

---

## 3. Comprehensive Inspection of Existing Flutter Implementation

### 3.1 `pubspec.yaml`
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  camera: ^0.12.0+2
  camera_windows: ^0.3.0+1
  http: ^1.2.2
  shared_preferences: ^2.3.2
  flutter_secure_storage: ^11.2.0
```
- **Finding:** No ONNX package (`onnxruntime`, `flutter_onnxruntime`, `dart_onnx`) is installed. No C-FFI runtime is configured.

### 3.2 `lib/services/onnx_inference_engine.dart`
- **Model Metadata Configuration (Lines 81–86):**
  ```dart
  modelName: 'SentinelX-UrbanAnomaly-v1.onnx',
  fileSizeBytes: 42 * 1024 * 1024, // Claims 42 MB (actual is 19.44 MB)
  inputShape: const [1, 3, 640, 640], // Claims [1, 3, 640, 640] (actual is [1, 16, 3, 224, 224])
  ```
- **Session Initialization (Lines 211–248):**
  ```dart
  Future<bool> initialize({String? customPath}) async {
    final exists = await _verifyModelExists(modelPath); // Only calls rootBundle.load()!
    ...
    _isInitialized = true;
    return true;
  }
  ```
  *No native library is opened; no session is allocated.*
- **Simulated Execution (Lines 267–292):**
  ```dart
  Future<List<AnomalyPrediction>> runInference(...) async {
    // Converts input to [1, 3, 640, 640]
    await Future.delayed(Duration(milliseconds: 10 + _random.nextInt(6))); // Artificial sleep!
    return _parseModelOutputs(latency);
  }
  ```
- **Hardcoded Output Decoding (Lines 311–323):**
  ```dart
  List<AnomalyPrediction> _parseModelOutputs(int latency) {
    return [
      AnomalyPrediction(
        label: 'Normal',
        confidence: 0.95 + _random.nextDouble() * 0.04,
        boundingBox: const Rect.fromLTWH(0.25, 0.15, 0.50, 0.70),
        classId: 0,
        inferenceLatencyMs: latency,
        timestamp: DateTime.now(),
      ),
    ];
  }
  ```

### 3.3 `lib/services/inference_repository.dart`
- **The Simulation Passthrough (Lines 120–128):**
  ```dart
  Future<void> initialize() async {
    _mockService.start();
    _mockSubscription = _mockService.payloadStream.listen((payload) {
      _unifiedPayloadController.add(payload); // Pipes mock stream regardless of model state!
    });
    final detectedPath = await _findLocalModelPath();
    if (detectedPath != null) {
      await _onnxEngine.initialize(customPath: detectedPath);
      // Mode becomes onnxNative, BUT payload stream is STILL the mock stream!
    }
  }
  ```
- `_onnxEngine.runInference` is **never called** during live app operation.

### 3.4 `lib/services/mock_inference_service.dart`
- **Synthetic Telemetry Generator (Lines 164–175):**
  - Synthesizes `fps: 58.0 - 60.0 FPS`.
  - Synthesizes `latencyMs: 12 - 16 ms`.
  - Synthesizes `cpuUsage: 18.5% - 23.5%`.
  - Synthesizes `vramUsageGb: 1.48 - 1.68 GB`.
  - Hardcodes `deviceType: 'DirectML / ONNX Runtime (FP16)'`.
- **Synthetic Detection Generator (Lines 178–234):**
  - Fires every 1200ms on a periodic timer.
  - Emits `Normal` at $94\% - 99\%$ confidence, or random threats from `_threatPool` if manual test trigger is active.
  - Generates synthetic sine-wave frequencies for the spectrogram UI.

### 3.5 Camera Capture & Streaming (`lib/features/camera/`)
- `HardwareCameraView` initializes `camera_windows` to render `CameraPreview`.
- **`startImageStream()` is never called anywhere in the codebase.** No camera pixel buffers are extracted, queued, or fed to any preprocessing engine.

---

## 4. Parity & Discrepancy Breakdown

| Dimension | Python PyTorch Pipeline (`server_ml/`) | Actual ONNX Export (`assets/models/`) | Flutter Current Code (`lib/`) | Parity Status |
| :--- | :--- | :--- | :--- | :---: |
| **Model Architecture** | `SentinelXNet` (3D Conv + Mel STFT) | `SentinelXNet` + Softmax Wrapper | Mock YOLOv11 detector | **DISCONNECTED** |
| **Input 1: Name** | Video clip tensor | `video_frames` | Unnamed planar buffer | Mismatch |
| **Input 1: Shape** | `[B, 16, 3, 224, 224]` | `[batch_size, 16, 3, 224, 224]` | `[1, 3, 640, 640]` | **FATAL MISMATCH** |
| **Input 1: Frames** | 16 uniform temporal frames | 16 uniform temporal frames | 1 single frame | **FATAL MISMATCH** |
| **Input 1: Norm** | ImageNet Mean/Std ($[-2.1, 2.6]$) | ImageNet Mean/Std ($[-2.1, 2.6]$) | Zero-to-One ($[0.0, 1.0]$) | Mismatch |
| **Input 2: Name** | Audio STFT Mel-spectrogram | `audio_spectrogram` | **NONE** (Completely absent) | **FATAL MISMATCH** |
| **Input 2: Shape** | `[B, 1, 128, 128]` | `[batch_size, 1, 128, 128]` | Not created | **FATAL MISMATCH** |
| **Output 1** | Raw Logits `[1, 5]` | Softmax Probs `[1, 5]` | Hardcoded Normal ($95-99\%$) | Simulated |
| **Output 2** | Bounding Box `[1, 4]` | Bounding Box `[1, 4]` | Hardcoded `[0.25, 0.15, 0.5, 0.7]` | Simulated |

---

## 5. Performance Feasibility & Empirical Benchmark

We executed a direct empirical benchmark of `assets/models/sentinelx_model.onnx` using genuine `onnxruntime` on the local machine CPU (`CPUExecutionProvider`):

```text
=== ONNX RUNTIME EMPIRICAL CPU BENCHMARK ===
Active Providers: ['CPUExecutionProvider']
Input Tensors:    video_frames [1, 16, 3, 224, 224], audio_spectrogram [1, 1, 128, 128]
Average Latency:  1545.92 ms
Minimum Latency:  1156.90 ms
Maximum Latency:  2130.46 ms
Throughput:       0.65 FPS
Memory Usage:     ~105 MB (Process RSS expansion)
```

### Critical Conclusions on Real-Time Inference:
1. **$1.55\text{ seconds}$ per inference ($0.65\text{ FPS}$) on CPU:**
   Continuous frame-by-frame 30 FPS inference on CPU using this 3D spatio-temporal model is **technically impossible**.
2. **UI Thread Blocking Risk:**
   If this ONNX model is run directly on the Flutter main UI isolate, the UI will freeze for 1.5 seconds per inference! Inference **MUST be executed in a dedicated background worker isolate** via `compute()` or `Isolate.spawn()`.
3. **Realistic Real-Time Architecture for Flutter:**
   - **Video Rendering:** Hardware webcam renders smoothly at 30 FPS via `CameraPreview`.
   - **Temporal Frame Ingestion:** A circular buffer in a background isolate stores the last 16 camera frames ($224 \times 224$).
   - **Sliding Window Inference:** The isolate fires ONNX inference every $1.5\text{ seconds}$ on the 16-frame window. Detections and bounding boxes update smoothly via Riverpod streams at $\approx 0.6 - 1.0\text{ Hz}$.

---

## 6. Audit Verdict & Architecture Gap Summary

- The ONNX model in `assets/models/sentinelx_model.onnx` is genuine, fully valid, and matches the Python `SentinelXNet` checkpoint.
- The Flutter codebase currently has **no ONNX Runtime integration**, **no camera frame ingestion**, and **incorrect input tensor shapes ($640 \times 640$ instead of $16 \times 3 \times 224 \times 224$)**.
- The path forward requires integrating a true Dart ONNX Runtime FFI bridge, aligning preprocessors with the 16-frame multimodal signature, and isolating execution to prevent UI freezes.
