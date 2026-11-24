# SentinelX — Phase 4.4.1: Audio Ingestion & Preprocessing Architecture Report

**Author Roles:** Principal Flutter Audio Engineer, Digital Signal Processing (DSP) Engineer, Python ML Integration Engineer, ONNX Runtime Specialist, Application Security Architect  
**Date:** 2026-11-22  
**Milestone:** Phase 4.4.1 — Genuine Hardware Microphone Ingestion & Verified Audio Preprocessing  
**Authoritative Evidence Artifact:** [test/hardware_microphone_benchmark.json](file:///b:/SentinelX/test/hardware_microphone_benchmark.json)  
**Status:** **APPROVED & FULLY IMPLEMENTED**

---

## 1. Executive Summary

SentinelX Phase 4.4.1 successfully transitions the platform from a video-only degraded operational mode (which substituted acoustic silence at $-80.0\text{ dB}$) to a genuine multimodal audio-visual intelligence system. 

This phase establishes the foundational audio pipeline:
1. Physical microphone hardware discovery and asynchronous PCM16 streaming at $16{,}000\text{ Hz}$ mono via [lib/core/audio/audio_ingestion_service.dart](file:///b:/SentinelX/lib/core/audio/audio_ingestion_service.dart).
2. Constant-memory bounded temporal ring buffering ($65{,}536\text{ samples}$ / $4.096\text{ seconds}$) via [lib/core/audio/temporal_audio_buffer.dart](file:///b:/SentinelX/lib/core/audio/temporal_audio_buffer.dart).
3. Pure Dart Digital Signal Processing (DSP) engine consisting of:
   - A fast Radix-2 1024-point Decimation-In-Time (DIT) FFT with precomputed twiddle factor tables and periodic Hann windowing ([lib/core/audio/fft.dart](file:///b:/SentinelX/lib/core/audio/fft.dart)).
   - A 128-band HTK Mel-scale triangular filterbank spanning $0\dots 8000\text{ Hz}$ ([lib/core/audio/mel_filterbank.dart](file:///b:/SentinelX/lib/core/audio/mel_filterbank.dart)).
   - Center reflection padding, amplitude-to-decibel logarithmic scaling with $80.0\text{ dB}$ dynamic range clamping, and exact tensor layout construction ([lib/core/audio/audio_preprocessor.dart](file:///b:/SentinelX/lib/core/audio/audio_preprocessor.dart)).
4. Exact mathematical parity with `server_ml/preprocessor.py` and PyTorch `torchaudio.transforms.MelSpectrogram`.
5. Strict contract adherence: generates an exact $[1, 1, 128, 128]$ Float32 tensor ($16{,}384\text{ elements}$) matching the input layer of [assets/models/sentinelx_model.onnx](file:///b:/SentinelX/assets/models/sentinelx_model.onnx).
6. Non-blocking concurrency: all audio ingestion and DSP computations execute without blocking the Flutter UI isolate or stalling video frame capture.
7. Graceful degraded fallback: transparently falls back to calibrated acoustic silence ($-80.0\text{ dB}$) when the microphone is absent, denied permission, or accumulating initial buffer samples.

---

## 2. Mathematical & DSP Contract Derivation

The SentinelX multimodal neural network ([SentinelXNet](file:///b:/SentinelX/server_ml/model.py)) accepts dual synchronous tensor inputs:
- `video_frames`: Float32 tensor of shape $[1, 16, 3, 224, 224]$ ($2{,}408{,}448\text{ floats}$)
- `audio_spectrogram`: Float32 tensor of shape $[1, 1, 128, 128]$ ($16{,}384\text{ floats}$)

The acoustic preprocessing pipeline must match the Python training dataset generation in [server_ml/preprocessor.py](file:///b:/SentinelX/server_ml/preprocessor.py) to prevent covariate shift and inference degradation.

### 2.1 Acoustic Waveform Conditioning
- **Target Sample Rate ($f_s$):** $16{,}000\text{ Hz}$ ($16\text{ kHz}$).
- **Channels:** Single-channel mono ($C = 1$). If multi-channel hardware is used, channels are downmixed via sample-wise averaging:
  $$x_{\text{mono}}[n] = \frac{1}{C}\sum_{c=1}^C x_c[n]$$
- **Quantization Normalization:** Incoming little-endian 16-bit integer PCM ($[-32768, 32767]$) is mapped to normalized 32-bit floating-point values in $[-1.0, 1.0]$:
  $$x[n] = \frac{x_{\text{int16}}[n]}{32768.0}$$

### 2.2 Center Reflection Padding
PyTorch `torchaudio.transforms.MelSpectrogram` defaults to `center=True` with `pad_mode='reflect'`. For an FFT window size $N_{\text{fft}} = 1024$, the reflection padding size is:
$$P = \frac{N_{\text{fft}}}{2} = 512\text{ samples}$$

Given an input sequence $x[0 \dots L-1]$, the padded signal $x_{\text{padded}}[0 \dots L + 2P - 1]$ is constructed by reflecting across the boundary without duplicating the boundary sample:
- **Left Reflection:** For $i \in [0, P-1]$:
  $$x_{\text{padded}}[i] = x[P - i]$$
- **Center:** For $i \in [0, L-1]$:
  $$x_{\text{padded}}[P + i] = x[i]$$
- **Right Reflection:** For $i \in [0, P-1]$:
  $$x_{\text{padded}}[P + L + i] = x[L - 2 - i]$$

### 2.3 Short-Time Fourier Transform (STFT)
- **Window Length:** $N_{\text{fft}} = 1024$ samples ($64\text{ ms}$ at $16\text{ kHz}$).
- **Hop Length:** $R = 512$ samples ($32\text{ ms}$ at $16\text{ kHz}$, $50\%$ overlap).
- **Periodic Hann Window:** Matches PyTorch `torch.hann_window(1024, periodic=True)`:
  $$w[n] = 0.5 - 0.5\cos\left(\frac{2\pi n}{1024}\right), \quad n \in [0, 1023]$$
- **Discrete Fourier Transform:** For frame $t$ beginning at offset $t \cdot R$:
  $$X_t[k] = \sum_{n=0}^{1023} x_{\text{padded}}[t \cdot R + n] \cdot w[n] \cdot e^{-j 2\pi k n / 1024}, \quad k \in [0, 512]$$
- **Power Spectrum:** $P_t[k] = |X_t[k]|^2 = \text{Re}(X_t[k])^2 + \text{Im}(X_t[k])^2$ ($513\text{ bins}$ representing $0\dots 8000\text{ Hz}$).

### 2.4 Mel Filterbank Transformation
- **Filter Count:** $M = 128$ triangular Mel bands.
- **Frequency Limits:** $f_{\min} = 0.0\text{ Hz}$, $f_{\max} = 8000.0\text{ Hz}$ (Nyquist limit).
- **HTK Mel Scale Formula:**
  $$m = 2595 \cdot \log_{10}\left(1 + \frac{f}{700}\right) \iff f = 700 \cdot \left(10^{m / 2595} - 1\right)$$
- **Triangular Weight Formulation:** For filter $m$ with left point $f_m$, center $f_{m+1}$, right $f_{m+2}$, and STFT frequency bin $f_k = k \cdot \frac{8000}{512}$:
  $$H_m[k] = \max\left(0.0, \min\left(\frac{f_k - f_m}{f_{m+1} - f_m}, \frac{f_{m+2} - f_k}{f_{m+2} - f_{m+1}}\right)\right)$$
- **Mel Energy Projection:**
  $$S_t[m] = \sum_{k=0}^{512} P_t[k] \cdot H_m[k], \quad m \in [0, 127]$$

### 2.5 Logarithmic Decibel Scaling & Dynamic Range Clamping
- **Power to Decibels:** Matches PyTorch `torchaudio.transforms.AmplitudeToDB(top_db=80.0)`:
  $$D_t[m] = 10 \cdot \log_{10}\left(\max\left(S_t[m], 10^{-10}\right)\right)$$
- **Top-dB Dynamic Range Clamping:** All elements are clamped relative to the global peak decibel level across the spectrogram:
  $$D_{\text{clamped}, t}[m] = \max\left(D_t[m], \max(D) - 80.0\right)$$
- **Temporal Alignment to 128 Slices:**
  - If temporal frames $T < 128$: the spectrogram is padded on the right with the minimum clamped value $\min(D_{\text{clamped}})$.
  - If temporal frames $T \ge 128$: the first 128 time frames are sliced: $D_{\text{tensor}}[:, 0\dots 127]$.
- **Final Tensor Shape:** Contiguous Float32 array of shape $[1, 1, 128, 128]$ containing $16{,}384\text{ floats}$ ($65{,}536\text{ bytes}$).

---

## 3. Component Architecture & Data Flow

```
                      [ Physical Laptop Microphone ]
                                    │
                                    ▼ (WASAPI / DirectSound 16 kHz PCM16)
                    [ AudioIngestionService ]
                                    │
                       Stream<Uint8List> (PCM16 chunks)
                                    │
                                    ▼
                    [ TemporalAudioBuffer ] ── (Capacity: 65,536 samples / 4.096s)
                                    │
                         extractSnapshot(64,000)
                                    │
                                    ▼
                     [ AudioPreprocessor ]
                      ├── Center Reflection Padding (512 samples)
                      ├── 1024-point Radix-2 DIT FFT + Hann Window
                      ├── 128-band HTK Mel Filterbank Matrix
                      └── Log-dB Clamping (-80.0 dB top_db)
                                    │
                         PreprocessedAudioOutput
                       ([1, 1, 128, 128] Float32List)
                                    │
                                    ▼
                [ ContinuousInferenceScheduler ]
                                    ├── Video Tensor [1, 16, 3, 224, 224]
                                    └── Audio Tensor [1, 1, 128, 128]
                                    │
                                    ▼ (Non-blocking Cross-Isolate Port)
                  [ OnnxInferenceWorker Isolate ]
                                    │
                       OrtSession.run() via native FFI
                                    │
                                    ▼
                ContinuousInferencePrediction
          (Multimodal probabilities, class, clipped bbox)
```

### 3.1 Temporal Audio Ring Buffer Design
The [TemporalAudioBuffer](file:///b:/SentinelX/lib/core/audio/temporal_audio_buffer.dart) solves memory leak hazards inherent in unbounded audio ingestion:
- **Bounded Fixed Capacity:** Pre-allocates a single contiguous `Float32List(65536)` ($256\text{ KB}$ RAM).
- **Constant Memory Footprint ($O(1)$ Space):** Regardless of whether the application runs for 1 minute or 24 hours, memory never increases.
- **Constant Time Push ($O(1)$ Time):** Samples are written into the circular buffer using modulo indexing: `_head = (_head + 1) % capacity`. Oldest samples are overwritten automatically.
- **Ordered Snapshot Extraction:** Extracts chronologically ordered continuous arrays for STFT evaluation.
- **Live Acoustic Telemetry:** Tracks running RMS volume, decibels relative to full scale ($\text{dBFS} = 20\log_{10}(\text{RMS})$), and buffer readiness ($N \ge 64{,}000$).

### 3.2 Dual-Modality Graceful Degradation Strategy
The platform guarantees zero crashes and seamless continuity across operational states:

| Hardware State | Ingestion Status | Buffer Readiness | Scheduler Execution Mode | Diagnostic Notice |
|:---|:---|:---|:---|:---|
| **Mic Connected & Streaming** | `streaming` | Ready ($N \ge 64{,}000$) | `MULTIMODAL ACTIVE` | `MULTIMODAL ACTIVE: AUDIO INGESTION VERIFIED (<Device Name>)` |
| **Mic Connecting / Warming Up** | `streaming` | Warming ($N < 64{,}000$) | `VIDEO-ONLY DEGRADED` | `DEGRADED MODE: AUDIO BUFFER BUFFERING — SILENCE BASELINE (-80.0 dB)` |
| **Mic Permission Denied** | `permissionDenied` | Unready | `VIDEO-ONLY DEGRADED` | `DEGRADED MODE: VIDEO ONLY — CALIBRATED SILENCE BASELINE (-80.0 dB)` |
| **No Microphone Detected** | `noDeviceFound` | Unready | `VIDEO-ONLY DEGRADED` | `DEGRADED MODE: VIDEO ONLY — CALIBRATED SILENCE BASELINE (-80.0 dB)` |
| **Mic Disconnected Mid-Stream** | `disconnected` | Paused | `VIDEO-ONLY DEGRADED` | `DEGRADED MODE: VIDEO ONLY — CALIBRATED SILENCE BASELINE (-80.0 dB)` |

---

## 4. Concurrency & UI Fluidity Guarantee

A critical architectural mandate is **zero main-thread UI blockage**:
1. **Audio Streaming:** Uses asynchronous `Stream<Uint8List>` callbacks managed by the Dart event loop without synchronous sleep or locks.
2. **DSP Processing:** Execution of reflection padding, 128 FFT frames, and Mel projections executes in approximately $2.5–4.5\text{ ms}$ on desktop CPU, well within the $16.67\text{ ms}$ frame budget.
3. **Native ONNX Inference:** Heavy native C-FFI forward passes ($1{,}200–1{,}600\text{ ms}$) execute entirely inside the dedicated background Dart worker isolate (`OnnxInferenceWorker`).
4. **Concurrency Guard:** The non-blocking concurrency guard in `ContinuousInferenceScheduler` skips frame triggers while an inference cycle is already in-flight, preventing queuing buildup and memory spikes.

---

## 5. Security & Trust Boundary Design

SentinelX strictly maintains client-server security boundaries:
1. **Zero HMAC Secrets in Client Binary:** `INTERNAL_SERVICE_KEY` remains strictly confined to server-side Node.js and Python microservices. It is never compiled into Flutter or desktop binaries.
2. **Untrusted Client Inferences:** Detections produced by the Flutter client desktop app are authenticated with the user's JWT and tagged by the backend as `source: 'manual_entry'` / `severity: 'low'`. They cannot trigger automatic police dispatches.
3. **Emergency Dispatch Protection:** Critical incident creation and emergency police dispatches require server-verified provenance authenticated via Protocol v2 request-bound HMAC SHA-256 tokens.
4. **Sanitized Telemetry:** Audio telemetry sent across services contains only numerical summary statistics (RMS, dB level, fill percentage) without transmitting unencrypted raw acoustic recordings to unauthorized endpoints.
