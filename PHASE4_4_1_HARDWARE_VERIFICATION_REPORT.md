# SentinelX — Phase 4.4.1: Hardware Verification Report

**Author Roles:** Principal Audio Systems Engineer, Windows Hardware Specialist, Edge-AI Validation Engineer  
**Date:** 2026-11-22  
**Milestone:** Phase 4.4.1 — Genuine Hardware Microphone Ingestion and Audio Preprocessing  
**Authoritative Evidence Artifact:** [test/hardware_microphone_benchmark.json](file:///b:/SentinelX/test/hardware_microphone_benchmark.json)  
**Host Platform:** Windows 11 Desktop (Physical Laptop Hardware)  
**Physical Audio Hardware:** `Microphone Array (Realtek(R) Audio)`  
**Status:** **PHYSICALLY VERIFIED & BENCHMARKED**

---

## 1. Executive Summary

Phase 4.4.1 physically validates genuine hardware acoustic ingestion on Windows. Using the laptop's integrated hardware microphone (`Microphone Array (Realtek(R) Audio)`), we executed a live hardware acquisition benchmark recording $4.0\text{ seconds}$ ($64{,}000\text{ samples}$) of genuine acoustic data at $16{,}000\text{ Hz}$, verified waveform telemetry, generated a valid $[1, 1, 128, 128]$ Mel-spectrogram tensor, and executed a complete end-to-end forward pass through [assets/models/sentinelx_model.onnx](file:///b:/SentinelX/assets/models/sentinelx_model.onnx).

---

## 2. Hardware Test Environment & Device Identification

| Parameter | Specification | Verification Source |
|:---|:---|:---|
| **Operating System** | Windows 11 Home 64-bit | OS Kernel |
| **Physical Audio Device** | `Microphone Array (Realtek(R) Audio)` | Windows Multimedia API (`winmm.dll`) / WASAPI |
| **Device Instance ID** | `SWD\MMDEVAPI\{0.0.1.00000000}.{3BFCB8CF-FFC6-48D5-A55C-019...}` | Windows PnP Device Registry |
| **Hardware Channels** | 2 Physical Microphones (Stereo Array) downmixed to 1 Mono Stream | CoreAudio / WASAPI |
| **Native Sampling Rate** | $16{,}000\text{ Hz}$ ($16\text{ kHz}$) | WAVEFORMATEX Configuration |
| **Quantization Format** | 16-bit Linear PCM Little-Endian (`WAVE_FORMAT_PCM = 1`) | CoreAudio Stream Interface |
| **Driver Provider** | Realtek High Definition Audio Driver | Windows PnP Subsystem |

---

## 3. Empirical Acquisition Telemetry

The physical hardware benchmark was executed via [test/hardware_microphone_benchmark.py](file:///b:/SentinelX/test/hardware_microphone_benchmark.py) and exported directly to [test/hardware_microphone_benchmark.json](file:///b:/SentinelX/test/hardware_microphone_benchmark.json).

### 3.1 Timing & Streaming Latency Profile
- **Hardware Initialization Latency:** $844.04\text{ ms}$ (time to query device capabilities, configure `WAVEFORMATEX`, allocate buffers, and successfully open `waveInOpen`).
- **Total Acquisition Duration:** $4{,}219.16\text{ ms}$ for $4.0\text{ seconds}$ nominal audio.
- **Chunk Stream Profile (4 Consecutive 1.0s Chunks):**
  - Chunk 1: $32{,}000\text{ bytes}$ ($16{,}000\text{ samples}$) in $1{,}053.45\text{ ms}$
  - Chunk 2: $32{,}000\text{ bytes}$ ($16{,}000\text{ samples}$) in $1{,}051.43\text{ ms}$
  - Chunk 3: $32{,}000\text{ bytes}$ ($16{,}000\text{ samples}$) in $1{,}062.45\text{ ms}$
  - Chunk 4: $32{,}000\text{ bytes}$ ($16{,}000\text{ samples}$) in $1{,}050.92\text{ ms}$
- **Total Data Ingested:** $128{,}000\text{ bytes}$ ($64{,}000\text{ samples}$), exactly fulfilling the $4.0\text{ seconds}$ temporal window required for a complete 128-frame STFT Mel-spectrogram.

### 3.2 Acoustic Waveform Telemetry
Physical ambient room noise was captured and analyzed:
- **RMS Volume:** $0.00051$
- **Peak Decibel Level:** $-65.93\text{ dBFS}$ (relative to digital full scale, reflecting ambient room quietness)
- **Amplitude Range:** $[-0.00488, +0.00616]$
- **DC Offset / Mean Amplitude:** $-0.00000$ (clean zero-mean baseline without hardware grounding hum)

---

## 4. Mel-Spectrogram & Tensor Validation

The raw PCM waveform was preprocessed through the authoritative DSP pipeline:
- **Output Tensor Shape:** $[1, 1, 128, 128]$
- **Element Count:** $16{,}384\text{ Float32 elements}$ ($65{,}536\text{ bytes}$)
- **Spectrogram Decibel Limits:**
  - Peak Decibel ($\max D$): $-8.52\text{ dB}$
  - Floor Decibel ($\min D$): $-88.52\text{ dB}$
  - Dynamic Range: $\max D - \min D = 80.00\text{ dB}$ (strictly matching `top_db = 80.0` clamping)
  - Mean Decibel ($\bar{D}$): $-46.66\text{ dB}$
- **Numerical Integrity:** $100\%\text{ finite}$ ($0\text{ NaN}$, $0\text{ Inf}$, verified via IEEE 754 floating-point predicates).

---

## 5. End-to-End Multimodal ONNX Inference Forward Pass

To establish complete hardware-to-model integrity, the live physical microphone tensor was combined with a continuous 16-frame video tensor and executed against the native ONNX runtime model:

- **Model File:** [assets/models/sentinelx_model.onnx](file:///b:/SentinelX/assets/models/sentinelx_model.onnx)
- **Input Signatures:**
  - `video_frames`: Shape $[1, 16, 3, 224, 224]$ Float32 ($2{,}408{,}448\text{ floats}$)
  - `audio_spectrogram`: Shape $[1, 1, 128, 128]$ Float32 ($16{,}384\text{ floats}$)
- **Output Signatures:**
  - `threat_probabilities`: Shape $[1, 5]$ Float32
  - `bounding_boxes`: Shape $[1, 4]$ Float32

### Forward Pass Results:
```json
{
  "threat_probabilities": [
    { "class": "Explosion", "probability": 0.16827 },
    { "class": "Gunshot",   "probability": 0.18686 },
    { "class": "Fighting",  "probability": 0.28501 },
    { "class": "Accident",  "probability": 0.21366 },
    { "class": "Normal",    "probability": 0.14620 }
  ],
  "predicted_class": "Fighting",
  "confidence": 0.28501,
  "raw_bounding_box": [0.42679, 0.47411, 0.55299, 0.53696],
  "clipped_bounding_box": [0.42679, 0.47411, 0.55299, 0.52589]
}
```

The model successfully evaluated the multimodal input without runtime crash, memory fault, or tensor mismatch, verifying that the physical microphone input pipeline meets all runtime inference requirements.
