# SentinelX — Phase P1-C: ONNX Model Contract Report

**Milestone:** P1-C (ML Model Integration, Inference Verification & Classification Validation)  
**Date:** November 23, 2026  
**Auditor:** Principal Machine Learning Engineer & ONNX Runtime Specialist  
**Status:** COMPLETE & AUTHORITATIVE  

---

## 1. Model Artifact Specifications

The production ONNX model artifact deployed in the application is located at:
[`assets/models/sentinelx_model.onnx`](file:///b:/SentinelX/assets/models/sentinelx_model.onnx).

| Specification Property | Authoritative Value | Verification Method |
|:---|:---|:---|
| **File Path** | `assets/models/sentinelx_model.onnx` | Filesystem Verification |
| **File Size** | **20,386,197 bytes** (19.4418 MB) | Exact byte count |
| **ONNX IR Version** | **9** | Protobuf model inspection (`onnx.load`) |
| **Opset Version** | **18** | Domain `""` (Default ONNX operator set) |
| **Producer Name** | `onnx.quantize` | Model metadata inspection |
| **Producer Version** | ONNX Runtime Dynamic Quantizer | Model metadata `onnx.infer: onnxruntime.quant` |
| **Quantization Format** | **INT8 Dynamic Quantization** | Operator inspection (`MatMulInteger`, `DynamicQuantizeLinear`) |
| **PyTorch Source Model** | `server_ml/models/sentinelx_model.pth` | 71,045,939 bytes (FP32 checkpoint) |
| **Compression Ratio** | **71.3% size reduction** | 71.05 MB -> 19.44 MB |

---

## 2. Input Tensor Contract

The model graph defines exactly **two input tensors**. Both must be supplied with valid non-null tensors on every forward pass.

```
Input 1: video_frames        [batch_size, 16, 3, 224, 224]  Float32
Input 2: audio_spectrogram   [batch_size, 1, 128, 128]      Float32
```

### 2.1 `video_frames`
- **Tensor Name:** `video_frames`
- **Data Type:** `TensorProto.FLOAT` (Float32, 4 bytes per element)
- **Rank:** 5
- **Dimensionality:** `[batch_size, 16, 3, 224, 224]`
  - Dimension 0: Dynamic batch size (bound to `1` in runtime client).
  - Dimension 1: Sequence length = 16 consecutive temporal frames.
  - Dimension 2: Channels = 3 (RGB planar order).
  - Dimension 3: Height = 224 pixels.
  - Dimension 4: Width = 224 pixels.
- **Total Float Count (Batch=1):** $1 \times 16 \times 3 \times 224 \times 224 = \mathbf{2,408,448\text{ floats}}$ (9,633,792 bytes).
- **Normalization:** ImageNet mean $\mu = [0.485, 0.456, 0.406]$, standard deviation $\sigma = [0.229, 0.224, 0.225]$.

### 2.2 `audio_spectrogram`
- **Tensor Name:** `audio_spectrogram`
- **Data Type:** `TensorProto.FLOAT` (Float32, 4 bytes per element)
- **Rank:** 4
- **Dimensionality:** `[batch_size, 1, 128, 128]`
  - Dimension 0: Dynamic batch size (bound to `1` in runtime client).
  - Dimension 1: Audio channels = 1 (Mono).
  - Dimension 2: Frequency bins = 128 Mel bands ($0\text{ Hz} - 8,000\text{ Hz}$).
  - Dimension 3: Time steps = 128 temporal frames (4.0 seconds at 16 kHz).
- **Total Float Count (Batch=1):** $1 \times 1 \times 128 \times 128 = \mathbf{16,384\text{ floats}}$ (65,536 bytes).
- **Dynamic Range:** Decibels scaled to $[-80.0\text{ dB}, 0.0\text{ dB}]$ relative to peak signal.

---

## 3. Output Tensor Contract

The model graph defines exactly **two output tensors**.

```
Output 1: threat_probabilities   [1, 5]   Float32 (Softmax)
Output 2: bounding_boxes         [1, 4]   Float32 (Sigmoid)
```

### 3.1 `threat_probabilities`
- **Tensor Name:** `threat_probabilities`
- **Data Type:** `TensorProto.FLOAT`
- **Rank:** 2
- **Dimensionality:** `[1, 5]`
- **Interpretation:** Softmax probability distribution over 5 mutually exclusive classes:
  1. Index `0`: `Explosion`
  2. Index `1`: `Gunshot`
  3. Index `2`: `Fighting`
  4. Index `3`: `Accident`
  5. Index `4`: `Normal`
- **Mathematical Invariant:** $\sum_{i=0}^4 P_i = 1.000 \pm 0.005$. Each $P_i \in [0.0, 1.0]$.

### 3.2 `bounding_boxes`
- **Tensor Name:** `bounding_boxes`
- **Data Type:** `TensorProto.FLOAT`
- **Rank:** 2
- **Dimensionality:** `[1, 4]`
- **Interpretation:** Sigmoid-activated normalized spatial bounding box coordinates:
  - Index `0`: $x_{min}$ (Normalized horizontal top-left origin, $[0.0, 1.0]$)
  - Index `1`: $y_{min}$ (Normalized vertical top-left origin, $[0.0, 1.0]$)
  - Index `2`: $w$ (Normalized bounding box width, $[0.0, 1.0]$)
  - Index `3`: $h$ (Normalized bounding box height, $[0.0, 1.0]$)
- **Viewport Canvas Constraint:** In [`lib/core/ml/continuous_inference_scheduler.dart`](file:///b:/SentinelX/lib/core/ml/continuous_inference_scheduler.dart), bounding box coordinates are clipped so that $x_{min} + w \le 1.0$ and $y_{min} + h \le 1.0$.

---

## 4. Execution Provider & Hardware Binding Contract

1. **Target OS & Architecture:** Windows 10/11 x64 (Intel/AMD).
2. **Native Runtime Library:** `onnxruntime.dll` (v1.32.0, 22,668,600 bytes).
3. **Execution Provider:**
   - **`CPUExecutionProvider` (AVX2 Multi-Threaded)**.
   - Configured threads: `intra_op_num_threads = 4`, `inter_op_num_threads = 2`.
   - DirectML (`DmlExecutionProvider`) is **NOT** bundled with the Flutter Windows executable or python onnxruntime packages; attempts to invoke DirectML fallback automatically to `CPUExecutionProvider`.
4. **Isolate Boundary:**
   Native C-FFI calls execute strictly within [`OnnxInferenceWorker`](file:///b:/SentinelX/lib/core/ml/onnx_inference_worker.dart) running on a separate OS background isolate. Memory transfers between the UI isolate and the worker isolate occur via copied `Float32List` buffers.

---

## 5. Contract Validation Summary

- **Shape Enforcement:** Verified via unit tests in [`test/unit/ml_inference_and_contract_test.dart`](file:///b:/SentinelX/test/unit/ml_inference_and_contract_test.dart).
- **Malformed Input Containment:** Tensors not matching `2,408,448` or `16,384` floats are safely rejected with `StateError`.
- **Numerical Sanitization:** Inputs containing `NaN` or `Infinity` are rejected with `ArgumentError`.
- **Output Bounds:** Softmax sum ($1.0 \pm 0.005$) and Sigmoid bounds ($[0.0, 1.0]$) are verified on every inference cycle.
