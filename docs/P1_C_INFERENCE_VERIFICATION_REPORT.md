# SentinelX — Phase P1-C: Inference Verification Report

**Milestone:** P1-C (ML Model Integration, Inference Verification & Classification Validation)  
**Date:** November 23, 2026  
**Auditor:** Principal Machine Learning Engineer & QA Auditor  
**Status:** COMPLETE & AUTHORITATIVE  

---

## 1. Executive Summary

This report verifies the end-to-end execution of the machine learning inference pipeline on Windows desktop x64.

The complete pipeline:
```
Camera / Microphone Ingestion
             │
             ▼
Temporal Buffering & Synchronization
             │
             ▼
Audio / Video Preprocessing
             │
             ▼
OnnxInferenceWorker (Background Isolate)
             │
             ▼
Native C-FFI Forward Pass (onnxruntime.dll v1.32.0)
             │
             ▼
Output Parsing (Softmax & Sigmoid)
             │
             ▼
ContinuousInferenceScheduler & DetectionSyncService
```
was audited against all 18 mandated verification categories. All 18 categories passed with zero failures.

---

## 2. Background Worker Architecture

Inference is offloaded from Flutter's main UI thread to a dedicated background Dart isolate managed by [`OnnxInferenceWorker`](file:///b:/SentinelX/lib/core/ml/onnx_inference_worker.dart):

```
┌────────────────────────────────────────────────────────┐
│                      UI Isolate                        │
│                                                        │
│  ContinuousInferenceScheduler                          │
│   • Assembles video tensor (2,408,448 floats)          │
│   • Assembles audio tensor (16,384 floats)             │
│   • Sends _WorkerInferenceRequest via SendPort         │
└──────────────────────────┬─────────────────────────────┘
                           │ Inter-Isolate Message Passing
                           ▼
┌────────────────────────────────────────────────────────┐
│                 Worker Isolate (OS Thread)             │
│                                                        │
│  _onnxWorkerEntryPoint                                 │
│   • Preloads onnxruntime.dll via Dart FFI              │
│   • Allocates OrtValueTensor for inputs                │
│   • Executes session.run(runOptions, inputs)           │
│   • Releases native input & output OrtValue tensors    │
│   • Returns _WorkerInferenceResponse via SendPort      │
└────────────────────────────────────────────────────────┘
```

### Safety & Lifecycle Controls:
1. **Zero UI Blocking:** Native inference forward pass (~1,076 ms) runs entirely on a background OS thread, guaranteeing that Flutter dashboard animations, 60 FPS camera preview, and user navigation remain completely fluid.
2. **Deterministic Cleanup:** Every native `OrtValueTensor` allocated during a forward pass is explicitly released via `release()` inside a `finally` block, preventing native C++ memory leaks.
3. **Worker Restart Capability:** If an unexpected isolate crash or native exception occurs, `OnnxInferenceWorker` automatically restarts the worker isolate and reinitializes the ONNX session without crashing the host application.

---

## 3. 18-Category Verification Results Matrix

The comprehensive test suite in [`test/unit/ml_inference_and_contract_test.dart`](file:///b:/SentinelX/test/unit/ml_inference_and_contract_test.dart) was executed. All 18 categories passed:

| # | Verification Category | Test Assertion | Result | Evidence |
|:---:|:---|:---|:---:|:---|
| **1** | Model File Loading | File exists, size = 20,386,197 bytes, ONNX protobuf header tag 0x08 | **VERIFIED** | Category 1 Test Passed |
| **2** | Input/Output Metadata | Validated input names (`video_frames`, `audio_spectrogram`) and output names (`threat_probabilities`, `bounding_boxes`) | **VERIFIED** | Category 2 Test Passed |
| **3** | Audio Preprocessing Parity | `AudioPreprocessor` produces 16,384 floats with 126 STFT frames and 80 dB clamp | **VERIFIED** | Category 3 Test Passed |
| **4** | Video Preprocessing Parity | `TemporalFrameBuffer` produces 2,408,448 floats with ImageNet $\mu, \sigma$ normalization | **VERIFIED** | Category 4 Test Passed |
| **5** | Shape Acceptance | `OnnxInferenceWorker.infer` accepts exact tensor shapes | **VERIFIED** | Category 5 Test Passed |
| **6** | Malformed Shape Rejection | Worker rejects truncated video or audio tensors throwing `StateError` | **VERIFIED** | Category 6 Test Passed |
| **7** | NaN / Infinity Rejection | Worker sanitizes input buffers; non-finite floats reject with `ArgumentError` | **VERIFIED** | Category 7 Test Passed |
| **8** | Stale Video Frame Rejection | `VideoWindowMetadata.isStale` correctly identifies frames exceeding max age | **VERIFIED** | Category 8 Test Passed |
| **9** | Stale Audio Chunk Rejection | `AudioWindowMetadata.isStale` correctly identifies audio exceeding max age | **VERIFIED** | Category 9 Test Passed |
| **10** | Output Interpretation | Softmax sum = $1.0 \pm 0.005$, Sigmoid coordinates bounded in $[0.0, 1.0]$ | **VERIFIED** | Category 10 Test Passed |
| **11** | Class Mapping Taxonomy | 5 classes: `Explosion`, `Gunshot`, `Fighting`, `Accident`, `Normal` | **VERIFIED** | Category 11 Test Passed |
| **12** | Low-Confidence Handling | Confidence $< 0.50$ classified as `LOW (SUPPRESSED / NOISE)`, `isActionable == false` | **VERIFIED** | Category 12 Test Passed |
| **13** | CPU Worker Execution | `OnnxInferenceWorker` initializes on background isolate with ONNX v1.32.0 | **VERIFIED** | Category 13 Test Passed |
| **14** | CPU Execution Provider Verification | Windows desktop explicitly configured with `CPU Multi-Threaded (AVX2)` | **VERIFIED** | Category 14 Test Passed |
| **15** | Repeated Inference Stability | 10+ sequential cycles maintain telemetry and zero state drift | **VERIFIED** | Category 15 Test Passed |
| **16** | Resource Cleanup | Worker isolate terminates cleanly; native tensors freed | **VERIFIED** | Category 16 Test Passed |
| **17** | Incident Creation Restrictions | Predictions with confidence $< 0.50$ create 0 incidents in `DetectionSyncService` | **VERIFIED** | Category 17 Test Passed |
| **18** | Security Regression Check | Verified user auth headers and RBAC boundaries intact | **VERIFIED** | Category 18 Test Passed |

---

## 4. Concurrency Guard Verification

In [`ContinuousInferenceScheduler`](file:///b:/SentinelX/lib/core/ml/continuous_inference_scheduler.dart):
```dart
Future<void> _onCameraFrameReceived(CameraFrame frame) async {
  if (_status != ContinuousInferenceStatus.running) return;

  // Strict Concurrency Guard: Do not queue overlapping forward passes
  if (_isInferring) {
    _skippedCycles++;
    _emitTelemetry();
    return;
  }
...
```
Because the camera acquires frames at ~4–10 FPS while CPU ONNX forward passes take ~1,076 ms, approximately 3–8 camera frames arrive while inference is active. The concurrency guard safely skips these frames rather than queuing an unbounded backlog of heavy tensors in memory.
