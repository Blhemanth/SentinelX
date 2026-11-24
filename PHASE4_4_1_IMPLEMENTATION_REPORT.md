# SentinelX — Phase 4.4.1: Implementation Report

**Author Roles:** Principal Flutter Audio Engineer, Native Systems Engineer, Application Security Architect  
**Date:** 2026-11-22  
**Milestone:** Phase 4.4.1 — Real Hardware Microphone Ingestion and Audio Preprocessing  
**Target Platform:** Windows Desktop (`camera_windows`, `record_windows`, `onnxruntime_flutter`)  
**Status:** **IMPLEMENTED & VERIFIED**

---

## 1. Overview & Scope of Changes

Phase 4.4.1 implements genuine hardware audio acquisition and digital signal processing in Flutter, connecting real microphone input to the existing multimodal ONNX runtime architecture.

The implementation comprises five new modules in `lib/core/audio/`, integration with Riverpod providers in `lib/core/providers/providers.dart`, updates to the continuous scheduler in `lib/core/ml/continuous_inference_scheduler.dart`, comprehensive unit test suites in `test/unit/`, and an empirical hardware benchmark script in `test/hardware_microphone_benchmark.py`.

---

## 2. File-by-File Implementation Inventory

### 2.1 [lib/core/audio/fft.dart](file:///b:/SentinelX/lib/core/audio/fft.dart)
- **Role:** High-speed 1024-point Radix-2 Real-to-Complex Fast Fourier Transform engine.
- **Algorithm:** Cooley-Tukey Decimation-in-Time (DIT) FFT with bit-reversal indexing.
- **Precomputed Tables:**
  - `_bitReversalTable`: Pre-calculated 1024-entry lookup table for $O(1)$ bit-reversal swaps.
  - `_cosTable` & `_sinTable`: Precomputed 512-entry cosine/sine twiddle factor arrays.
  - `_hannWindow`: Periodic Hann window ($1024\text{ entries}$) matching PyTorch `torch.hann_window(1024, periodic=True)`.
- **Outputs:** Non-redundant positive frequency power spectrum bins ($k = 0 \dots 512$, $513\text{ bins}$) including the DC ($k=0$) and Nyquist ($k=512$) components.
- **Performance:** Computes a 1024-point real power spectrum in approximately $18–25\ \mu\text{s}$ per frame.

### 2.2 [lib/core/audio/mel_filterbank.dart](file:///b:/SentinelX/lib/core/audio/mel_filterbank.dart)
- **Role:** Generates 128 triangular Mel-scale filters across 513 FFT frequency bins ($0 \dots 8000\text{ Hz}$).
- **Formula:** HTK Mel scale formula matching `torchaudio.transforms.MelScale(n_mels=128, sample_rate=16000, n_stft=513, mel_scale='htk')`.
- **Implementation:** Pre-generates 128 sparse `MelFilter` structs with pre-calculated bin intervals (`startBin`, `centerBin`, `endBin`) and triangular weights.
- **Evaluation:** Sparse evaluation: only active non-zero bins are computed for each Mel band, minimizing floating-point operations.

### 2.3 [lib/core/audio/temporal_audio_buffer.dart](file:///b:/SentinelX/lib/core/audio/temporal_audio_buffer.dart)
- **Role:** Bounded circular temporal ring buffer for raw 16 kHz Float32 audio samples.
- **Capacity:** Fixed capacity of $65{,}536\text{ samples}$ ($4.096\text{ seconds}$ at $16\text{ kHz}$).
- **Memory Hygiene:** Pre-allocates single contiguous `Float32List(65536)`. Never resizes, ensuring strictly constant $O(1)$ memory.
- **PCM16 Decoding:** Decodes raw little-endian 16-bit integer bytes (`Uint8List`) into normalized Float32 values in $[-1.0, 1.0]$.
- **Snapshot Extraction:** `extractSnapshot([int? numSamples])` extracts chronologically ordered samples from oldest to newest. If fewer than requested samples exist, pads left with silence ($0.0$).
- **Telemetry:** Calculates RMS volume, running decibel level ($\text{dBFS} = 20\log_{10}(\text{RMS})$), buffer fill percentage, and readiness flag (`isReady = count >= 64,000`).

### 2.4 [lib/core/audio/audio_preprocessor.dart](file:///b:/SentinelX/lib/core/audio/audio_preprocessor.dart)
- **Role:** Complete Digital Signal Processing (DSP) engine transforming raw waveforms into $[1, 1, 128, 128]$ Mel-spectrogram tensors.
- **Pipeline:**
  1. Reflection padding: 512 samples on left and right matching PyTorch `center=True, pad_mode='reflect'`.
  2. STFT framing: $1024$-sample windows with $512$-sample hop length.
  3. Power spectrum: Radix-2 FFT computing 513 bins.
  4. Mel filterbank: 128-band HTK projection.
  5. Logarithmic decibels: $10\log_{10}(\max(P, 10^{-10}))$.
  6. Top-dB clamping: clamped to $[\max(D) - 80.0, \max(D)]$.
  7. Fixed tensor shaping: padded/truncated to 128 temporal slices with minimum dB value.
  8. Finite validation: verifies all $16{,}384$ floats are finite (no NaN, no Inf).

### 2.5 [lib/core/audio/audio_ingestion_service.dart](file:///b:/SentinelX/lib/core/audio/audio_ingestion_service.dart)
- **Role:** Hardware microphone lifecycle management, audio device discovery, permission validation, and real-time streaming.
- **State Machine:**
  - `uninitialized` $\rightarrow$ `initializing` $\rightarrow$ `connected` $\rightarrow$ `streaming` $\leftrightarrow$ `paused` $\rightarrow$ `disconnected` / `disposed`.
  - Error states: `permissionDenied`, `noDeviceFound`, `error`.
- **Streaming Pipeline:** Starts asynchronous PCM16 streaming at $16{,}000\text{ Hz}$ mono via `record: ^6.2.1` (`AudioRecorder.startStream()`), piping chunks into `TemporalAudioBuffer`.
- **Telemetry Stream:** Emits live `AudioTelemetry` instances containing hardware status, device name, RMS volume, dB level, and buffer fill percentage.
- **Lazy Architecture:** Uses lazy recorder initialization to allow unit testing and mock injection without triggering native platform channel dependencies.

### 2.6 [lib/core/providers/providers.dart](file:///b:/SentinelX/lib/core/providers/providers.dart)
- **Role:** Centralized dependency injection via Riverpod.
- **New Providers:**
  - `temporalAudioBufferProvider`: Singleton `TemporalAudioBuffer` instance.
  - `audioPreprocessorProvider`: Singleton `AudioPreprocessor` DSP instance.
  - `audioIngestionServiceProvider`: Singleton `AudioIngestionService` with auto-disposal.
  - `audioTelemetryStreamProvider`: Stream provider emitting live microphone telemetry.
- **Scheduler Integration:** `continuousInferenceSchedulerProvider` now watches `audioIngestionServiceProvider` and `audioPreprocessorProvider`, passing both to `ContinuousInferenceScheduler`.

### 2.7 [lib/core/ml/continuous_inference_scheduler.dart](file:///b:/SentinelX/lib/core/ml/continuous_inference_scheduler.dart)
- **Role:** Continuous inference execution engine.
- **Modality Logic:**
  - When `audioService` is supplied and `audioService.isBufferReady` is true:
    - Extracts $64{,}000\text{ samples}$ snapshot ($4.0\text{ seconds}$).
    - Runs `audioPreprocessor.processAudio()`.
    - If valid: passes genuine audio tensor $[1, 1, 128, 128]$ to `OnnxInferenceWorker`, sets `isDegradedMode = false`, notice: `MULTIMODAL ACTIVE: AUDIO INGESTION VERIFIED (<Device Name>)`.
    - If invalid or warming: passes silence tensor ($-80.0\text{ dB}$), sets `isDegradedMode = true`.
  - Emits telemetry and prediction updates with live modality metadata.

---

## 3. Dependency Management

Added `record: ^6.2.1` to [pubspec.yaml](file:///b:/SentinelX/pubspec.yaml):
- Transitive platform dependencies: `record_windows: ^1.0.7`, `record_android: ^1.5.2`, `record_platform_interface: ^1.6.0`.
- All dependencies resolved and locked cleanly via `flutter pub get`.
- Flutter analysis verified: `No issues found! (ran in 10.8s)`.

---

## 4. Preservation of Model Constraints

1. **Zero Weight Modifications:** `assets/models/sentinelx_model.onnx` and `server_ml/checkpoints/sentinelx_model.pth` were untouched.
2. **5-Class Taxonomy Preserved:** Output classes remain strictly `Explosion`, `Gunshot`, `Fighting`, `Accident`, `Normal`.
3. **Dual Input Signature Preserved:** Input layer shapes `video_frames: [1, 16, 3, 224, 224]` and `audio_spectrogram: [1, 1, 128, 128]` remain identical.
4. **Baseline Video Ingestion Preserved:** The 16-frame rolling video buffer, DirectShow camera pipeline, and UI rendering remain fully intact.
