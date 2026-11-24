# SentinelX — Phase 3 ML Pipeline Test & Verification Report

**Execution Date:** November 22, 2026  
**Auditor / Engineer:** Principal ML Engineer & Full-Stack Software Architect  
**Subsystems Tested:**
1. Python Preprocessor Engine (`server_ml/preprocessor.py`)
2. Python CLI Multimodal Inference Engine (`server_ml/infer.py`)
3. FastAPI Microservice (`server_ml/inference_api.py`)
4. Express Backend ML Bridge (`backend/src/services/mlBridge.service.js`)
5. MongoDB CrimeLog Ingestion Pipeline (`backend/src/models/CrimeLog.js`)
**Overall Status:** **100% PASSED (23/23 Tests Across All Tiers)**

---

## 1. Executive Summary

Phase 3 automated testing validated that the SentinelX Machine Learning pipeline is operating with **genuine video decoding, genuine acoustic feature extraction, strict checkpoint weight verification, and true neural network forward-pass inference**.

Testing was executed using real, dynamically generated media (OpenCV MP4 video clips and Scipy 16kHz WAV audio files). All synthetic random tensor substitutes (`torch.randn`) and artificial hardcoded prediction overrides were eliminated from the production path.

---

## 2. Test Environment Specification

- **Operating System:** Windows 11 Enterprise (x64)
- **CPU:** Intel Core i7 / AMD Multi-Core Host
- **RAM:** 32 GB DDR5
- **Python Version:** Python 3.13.x (WindowsApps)
- **PyTorch Build:** `torch 2.15.0+cpu`
- **Audio Processing:** `torchaudio 2.11.1+cpu`
- **Computer Vision:** `opencv-python 4.13.0`
- **Acoustic Decoding:** `scipy 1.18.1`
- **Web Microservice:** `fastapi 0.148.0` / `uvicorn 0.54.0`
- **Database:** Local MongoDB Community Edition (`127.0.0.1:27017`)

---

## 3. Comprehensive Test Results Matrix

### 3.1 Python ML Pipeline Test Suite (`server_ml/test_ml_pipeline.py`)

Executed via `python server_ml/test_ml_pipeline.py`. Total test duration: **4.767s**.

| # | Test Case Description | Input Media | Expected Behavior | Actual Result | Status | Latency |
|---|---|---|---|---|---|---|
| **01** | Strict Checkpoint Loading | `server_ml/models/sentinelx_model.pth` | Loads into `SentinelXNet` with `strict=True` with 0 missing / unexpected keys | 0 missing, 0 unexpected keys; state dict strictly verified | **✓ PASS** | 383 ms |
| **02** | Video Preprocessing Shape & Range | Real 24-frame 30fps MP4 video (`320x240`) | Decodes via `cv2`, extracts 16 frames, normalizes to `[1, 16, 3, 224, 224]` | Output shape `(1, 16, 3, 224, 224)`; ImageNet normalized range ($[-2.11, 2.64]$) | **✓ PASS** | 76.2 ms |
| **03** | Short Video Padding (<16 Frames) | Real 6-frame MP4 clip (`160x120`) | Repeats last frame to yield exactly 16 frames without error | Output shape `(1, 16, 3, 224, 224)`; 16 valid frames | **✓ PASS** | 18.4 ms |
| **04** | Audio Preprocessing & Mel-Spectrogram | Real 1.0s 16kHz WAV audio (dual-tone) | Decodes waveform, computes 128-band Mel-spec, outputs `[1, 1, 128, 128]` | Output shape `(1, 1, 128, 128)`; finite log-dB values | **✓ PASS** | 3.4 ms |
| **05** | Acoustic Silence Baseline | `None` (Video-only mode) | Generates calibrated -80.0 dB baseline tensor `[1, 1, 128, 128]` | Output shape `(1, 1, 128, 128)`; constant -80.0 dB floor | **✓ PASS** | 0.1 ms |
| **06** | Corrupt / Empty Media Handling | Corrupted binary file & empty byte stream | Raises descriptive `ValueError` without substituting random tensors | `ValueError: OpenCV could not open video` & `ValueError: Failed to read WAV` caught | **✓ PASS** | 2.1 ms |
| **07** | Multimodal Neural Forward Pass | Genuine MP4 video + Genuine WAV audio | Emits raw logits ($[1, 5]$), softmax probabilities, normalized bbox | Output class: `Fighting`, Confidence: `28.25%`, BBox: `[0.4128, 0.4855, 0.5592, 0.5027]` | **✓ PASS** | 558.1 ms |
| **08** | Video-Only Inference Mode | Genuine MP4 video + Silence baseline | Forward pass completes with `audio_present: false` | Valid threat prediction from visual cues; confidence in $[0, 1]$ | **✓ PASS** | 492.3 ms |
| **09** | FastAPI Service Health & Model Info | HTTP GET `/health` & `/model/info` | Responds with HTTP 200, `status: 'online'`, `model_loaded: true` | HTTP 200; 5 threat classes; model loaded verified | **✓ PASS** | 12.0 ms |
| **10** | FastAPI Base64 JSON Ingestion | HTTP POST `/detect` with base64 video/audio | Decodes base64 payload, returns structured JSON detection | HTTP 200; `threat_class` returned with complete latency metrics | **✓ PASS** | 579.0 ms |
| **11** | FastAPI Multipart Upload Ingestion | HTTP POST `/detect/upload` (multipart) | Streams multipart files, executes real inference | HTTP 200; `audio_present: true`, bounding box validated | **✓ PASS** | 519.0 ms |
| **12** | FastAPI Rejection of Corrupt Upload | HTTP POST `/detect/upload` (corrupted file) | Rejects corrupted file with HTTP 400 Bad Request | HTTP 400 Bad Request; descriptive error returned | **✓ PASS** | 2.5 ms |

---

### 3.2 Express Backend Integration Test Suite (`backend/test_ml_express_integration.js`)

Executed via `node backend/test_ml_express_integration.js`.

| # | Test Case Description | Expected Behavior | Actual Result | Status | Latency |
|---|---|---|---|---|---|
| **01** | Analyst Authentication | Obtains signed JWT access token for analyst | Authenticated; Bearer token generated | **✓ PASS** | 12 ms |
| **02** | Express `/api/detect` Status | Responds with HTTP 200 on real video/audio | Status: HTTP 200 | **✓ PASS** | 2,760 ms |
| **03** | Threat Class Output | Predicted class matches taxonomy (5 classes) | Predicted: `Fighting` | **✓ PASS** | — |
| **04** | Confidence Score Bounds | Confidence is a valid float in $[0.0, 1.0]$ | Confidence: `28.21%` | **✓ PASS** | — |
| **05** | Bounding Box Structure | Bounding box has normalized $x, y, w, h \in [0, 1]$ | Coordinates: `[0.4128, 0.4855, 0.5592, 0.5027]` | **✓ PASS** | — |
| **06** | Separate Latency Metrics | Subdocument contains separate prep/infer latencies | `modelInferenceMs: 1308.85ms`, `totalLatencyMs: 2760.56ms` | **✓ PASS** | — |
| **07** | Detection Source Tagging | Genuine ML detection tagged as `'ml_real'` | `detectionSource: "ml_real"` | **✓ PASS** | — |
| **08** | MongoDB Document Persistence | `CrimeLog` record saved to MongoDB with `'ml_real'` | DB document created with ID `6b01e574d392730c77e94c4e` | **✓ PASS** | — |
| **09** | MongoDB Metrics Schema | Latency metrics subdocument stored in MongoDB | Stored in database with all 4 timing fields | **✓ PASS** | — |
| **10** | Demonstration Drill Endpoint | `POST /api/logs/trigger` responds with HTTP 201 | Status: HTTP 201 Created | **✓ PASS** | 8 ms |
| **11** | Drill Source Distinction | Simulation drill saved with `'drill_simulation'` | Database document tagged with `detectionSource: "drill_simulation"` | **✓ PASS** | — |

---

## 4. Latency & Performance Breakdown

Across 10 measured multimodal executions on real media (CPU mode):

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        MEASURED INFERENCE LATENCY BREAKDOWN (CPU)                      │
├──────────────────────────────┬──────────────┬──────────────┬───────────────────────────┤
│ Pipeline Stage               │ Average (ms) │ Min (ms)     │ % of Total Pipeline Time  │
├──────────────────────────────┼──────────────┼──────────────┼───────────────────────────┤
│ Video Decoding & Resize      │ 76.2 ms      │ 62.1 ms      │ 13.6%                     │
│ Audio Mel-Spectrogram Gen    │ 3.4 ms       │ 2.8 ms       │ 0.6%                      │
│ PyTorch Forward Pass (CPU)   │ 476.1 ms     │ 412.0 ms     │ 85.3%                     │
│ IPC & JSON Serialization     │ 2.4 ms       │ 1.8 ms       │ 0.5%                      │
├──────────────────────────────┼──────────────┼──────────────┼───────────────────────────┤
│ TOTAL END-TO-END PIPELINE    │ 558.1 ms     │ 478.7 ms     │ 100.0% (~1.79 FPS on CPU) │
└──────────────────────────────┴──────────────┴──────────────┴───────────────────────────┘
```

*Note: On an NVIDIA GPU accelerator with CUDA / TensorRT enabled, the PyTorch forward pass is projected to decrease from ~476 ms to < 18 ms, unlocking ~15–30 FPS real-time surveillance processing.*

---

## 5. Technical Limitations & Disclosure

In compliance with engineering standards:
1. **Real-World Anomaly Detection Accuracy:**
   While the ingestion pipeline decodes genuine video frames and computes authentic Mel-spectrograms matching the dataset preprocessing specification, **real-world detection accuracy and F1 score have NOT been established in this audit**. Statistical accuracy can only be verified against a fully labelled benchmark dataset (such as the complete XD-Violence or UCF-Crime test split).
2. **CPU Inference Throughput:**
   In CPU-only execution, processing a 16-frame clip requires ~558 ms (~1.8 clips/sec). For high-frame-rate real-time surveillance across dozens of concurrent camera streams, GPU acceleration (CUDA) or ONNX DirectML/OpenVINO execution is required.
3. **No Retraining Conducted:**
   The neural network was strictly not retrained; the existing checkpoint (`sentinelx_model.pth`) was verified and preserved without parameter modification.

---

## 6. Sign-off & Conclusion

Phase 3 (Real Python Video/Audio ML Ingestion) has been **fully implemented, verified, and validated**. All tests pass with zero errors, and the entire simulation gap in the backend inference pipeline has been permanently resolved.
