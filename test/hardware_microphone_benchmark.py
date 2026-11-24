#!/usr/bin/env python3
"""
SentinelX — Phase 4.4.1 Hardware Microphone Benchmark & Audio Acquisition Verifier
Directly interfaces with physical Windows laptop microphone (Microphone Array (Realtek(R) Audio)) via Windows Multimedia API (winmm).
Measures:
1. Microphone initialization latency
2. Hardware audio acquisition latency & throughput
3. 64,000-sample (4.0s @ 16 kHz) temporal buffer ingestion
4. PCM16 to Float32 normalization & acoustic telemetry (RMS, dB level, peak amplitude)
5. 128x128 Mel-spectrogram generation via server_ml/preprocessor.py
6. Strict ONNX model tensor shape validation [1, 1, 128, 128]
7. Structured telemetry JSON export to test/hardware_microphone_benchmark.json
"""

import os
import sys
import time
import json
import math
import ctypes
import ctypes.wintypes
from pathlib import Path
import numpy as np

# Add project root to sys.path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from server_ml.preprocessor import preprocess_audio

WAVE_FORMAT_PCM = 1

class WAVEFORMATEX(ctypes.Structure):
    _fields_ = [
        ("wFormatTag", ctypes.wintypes.WORD),
        ("nChannels", ctypes.wintypes.WORD),
        ("nSamplesPerSec", ctypes.wintypes.DWORD),
        ("nAvgBytesPerSec", ctypes.wintypes.DWORD),
        ("nBlockAlign", ctypes.wintypes.WORD),
        ("wBitsPerSample", ctypes.wintypes.WORD),
        ("cbSize", ctypes.wintypes.WORD),
    ]

class WAVEHDR(ctypes.Structure):
    pass
WAVEHDR._fields_ = [
    ("lpData", ctypes.c_char_p),
    ("dwBufferLength", ctypes.wintypes.DWORD),
    ("dwBytesRecorded", ctypes.wintypes.DWORD),
    ("dwUser", ctypes.c_void_p),
    ("dwFlags", ctypes.wintypes.DWORD),
    ("dwLoops", ctypes.wintypes.DWORD),
    ("lpNext", ctypes.POINTER(WAVEHDR)),
    ("reserved", ctypes.c_void_p),
]

class WAVEINCAPSW(ctypes.Structure):
    _fields_ = [
        ("wMid", ctypes.wintypes.WORD),
        ("wPid", ctypes.wintypes.WORD),
        ("vDriverVersion", ctypes.c_uint),
        ("szPname", ctypes.c_wchar * 32),
        ("dwFormats", ctypes.c_uint),
        ("wChannels", ctypes.wintypes.WORD),
        ("wReserved1", ctypes.wintypes.WORD),
    ]


def benchmark_hardware_microphone(device_index=0, sample_rate=16000, duration_seconds=4.0):
    print("=" * 70)
    print(" SENTINELX — PHASE 4.4.1 PHYSICAL HARDWARE MICROPHONE VERIFICATION ")
    print("=" * 70)

    winmm = ctypes.windll.winmm

    results = {
        "device_index": device_index,
        "device_name": "Microphone Array (Realtek(R) Audio)",
        "hardware_opened": False,
        "initialization_time_ms": 0.0,
        "sample_rate_hz": sample_rate,
        "channels": 1,
        "bit_depth": 16,
        "duration_seconds": duration_seconds,
        "target_samples": int(sample_rate * duration_seconds),
        "total_samples_captured": 0,
        "total_bytes_recorded": 0,
        "acquisition_duration_ms": 0.0,
        "chunk_latencies_ms": [],
        "waveform_metrics": {
            "min_amplitude": 0.0,
            "max_amplitude": 0.0,
            "mean_amplitude": 0.0,
            "rms_volume": 0.0,
            "peak_db_level": -100.0,
        },
        "mel_spectrogram_metrics": {
            "tensor_shape": [],
            "num_elements": 0,
            "min_db": 0.0,
            "max_db": 0.0,
            "mean_db": 0.0,
            "preprocessing_latency_ms": 0.0,
            "is_finite": False,
        },
        "timestamp_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }

    # 1. Query device name
    caps = WAVEINCAPSW()
    if winmm.waveInGetDevCapsW(device_index, ctypes.byref(caps), ctypes.sizeof(caps)) == 0:
        results["device_name"] = caps.szPname
        print(f"[Device] Hardware Audio Device: {caps.szPname}")
    else:
        print(f"[Device] Using default device index: {device_index}")

    # 2. Configure 16 kHz Mono 16-bit PCM Audio Format
    wfx = WAVEFORMATEX()
    wfx.wFormatTag = WAVE_FORMAT_PCM
    wfx.nChannels = 1
    wfx.nSamplesPerSec = sample_rate
    wfx.wBitsPerSample = 16
    wfx.nBlockAlign = 2
    wfx.nAvgBytesPerSec = sample_rate * 2
    wfx.cbSize = 0

    hWaveIn = ctypes.wintypes.HANDLE()

    # 3. Open Microphone Hardware & Measure Init Latency
    init_start = time.perf_counter()
    res = winmm.waveInOpen(ctypes.byref(hWaveIn), device_index, ctypes.byref(wfx), 0, 0, 0)
    init_end = time.perf_counter()
    init_ms = (init_end - init_start) * 1000.0
    results["initialization_time_ms"] = round(init_ms, 2)

    if res != 0:
        print(f"[FAIL] waveInOpen returned error code: {res}")
        results["hardware_opened"] = False
        return results

    results["hardware_opened"] = True
    print(f"[PASS] Hardware Microphone Opened in {init_ms:.2f} ms")

    try:
        # 4. Stream 4 chunks of 1.0 second each (16,000 samples = 32,000 bytes per chunk)
        chunk_seconds = 1.0
        chunk_samples = int(sample_rate * chunk_seconds)
        chunk_bytes = chunk_samples * 2
        num_chunks = int(duration_seconds / chunk_seconds)

        audio_chunks = []
        chunk_latencies = []

        print(f"[Stream] Ingesting {duration_seconds:.1f}s of genuine acoustic audio ({num_chunks} chunks)...")
        stream_start = time.perf_counter()

        for chunk_idx in range(num_chunks):
            chunk_t0 = time.perf_counter()
            raw_buf = ctypes.create_string_buffer(chunk_bytes)
            hdr = WAVEHDR()
            hdr.lpData = ctypes.cast(raw_buf, ctypes.c_char_p)
            hdr.dwBufferLength = chunk_bytes

            winmm.waveInPrepareHeader(hWaveIn, ctypes.byref(hdr), ctypes.sizeof(hdr))
            winmm.waveInAddBuffer(hWaveIn, ctypes.byref(hdr), ctypes.sizeof(hdr))
            winmm.waveInStart(hWaveIn)

            # Sleep slightly longer than chunk duration to allow hardware buffer fill
            time.sleep(chunk_seconds + 0.05)

            winmm.waveInStop(hWaveIn)
            winmm.waveInReset(hWaveIn)
            winmm.waveInUnprepareHeader(hWaveIn, ctypes.byref(hdr), ctypes.sizeof(hdr))

            chunk_t1 = time.perf_counter()
            chunk_lat_ms = (chunk_t1 - chunk_t0) * 1000.0
            chunk_latencies.append(round(chunk_lat_ms, 2))

            bytes_rec = hdr.dwBytesRecorded
            pcm_data = raw_buf.raw[:bytes_rec]
            audio_chunks.append(pcm_data)
            print(f"  Chunk {chunk_idx + 1}/{num_chunks}: {bytes_rec} bytes recorded ({chunk_lat_ms:.1f} ms)")

        stream_end = time.perf_counter()
        total_duration_ms = (stream_end - stream_start) * 1000.0

        all_pcm = b"".join(audio_chunks)
        results["total_bytes_recorded"] = len(all_pcm)
        results["total_samples_captured"] = len(all_pcm) // 2
        results["acquisition_duration_ms"] = round(total_duration_ms, 2)
        results["chunk_latencies_ms"] = chunk_latencies

        print(f"[PASS] Ingestion complete: {results['total_samples_captured']} samples ({len(all_pcm)} bytes) in {total_duration_ms:.1f} ms")

        # 5. Convert PCM16 to Float32 [-1.0, 1.0]
        waveform_int16 = np.frombuffer(all_pcm, dtype=np.int16)
        waveform_float32 = waveform_int16.astype(np.float32) / 32768.0

        # Compute waveform metrics
        min_amp = float(waveform_float32.min())
        max_amp = float(waveform_float32.max())
        mean_amp = float(waveform_float32.mean())
        rms = float(np.sqrt(np.mean(waveform_float32 ** 2)))
        peak_db = 20.0 * math.log10(max(rms, 1e-5))

        results["waveform_metrics"]["min_amplitude"] = round(min_amp, 5)
        results["waveform_metrics"]["max_amplitude"] = round(max_amp, 5)
        results["waveform_metrics"]["mean_amplitude"] = round(mean_amp, 5)
        results["waveform_metrics"]["rms_volume"] = round(rms, 5)
        results["waveform_metrics"]["peak_db_level"] = round(peak_db, 2)

        print(f"[Telemetry] RMS: {rms:.5f} | dB Level: {peak_db:.2f} dB | Amplitude Range: [{min_amp:.4f}, {max_amp:.4f}]")

        # 6. Generate 128x128 Mel-spectrogram via server_ml/preprocessor.py
        mel_tensor, prep_ms = preprocess_audio(
            source=waveform_float32,
            sample_rate=sample_rate,
            n_mels=128,
            target_time_steps=128,
        )

        tensor_np = mel_tensor.numpy()
        is_finite = bool(np.isfinite(tensor_np).all())

        results["mel_spectrogram_metrics"]["tensor_shape"] = list(tensor_np.shape)
        results["mel_spectrogram_metrics"]["num_elements"] = int(tensor_np.size)
        results["mel_spectrogram_metrics"]["min_db"] = round(float(tensor_np.min()), 2)
        results["mel_spectrogram_metrics"]["max_db"] = round(float(tensor_np.max()), 2)
        results["mel_spectrogram_metrics"]["mean_db"] = round(float(tensor_np.mean()), 2)
        results["mel_spectrogram_metrics"]["preprocessing_latency_ms"] = round(prep_ms, 2)
        results["mel_spectrogram_metrics"]["is_finite"] = is_finite

        print(f"[Mel-Spectrogram] Shape: {list(tensor_np.shape)} | Elements: {tensor_np.size}")
        print(f"[Mel-Spectrogram] Range: [{tensor_np.min():.2f} dB, {tensor_np.max():.2f} dB] | Latency: {prep_ms:.2f} ms")
        print(f"[Validation] Finite check: {'PASS' if is_finite else 'FAIL'}")

        # Strict Assertions
        assert list(tensor_np.shape) == [1, 1, 128, 128], f"Expected [1, 1, 128, 128], got {list(tensor_np.shape)}"
        assert is_finite, "Tensor contains non-finite values (NaN/Inf)"

    finally:
        winmm.waveInClose(hWaveIn)
        print("[Device] Hardware microphone closed.")

    # 7. Write telemetry JSON
    output_path = Path(__file__).resolve().parent / "hardware_microphone_benchmark.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2)
    print(f"[Export] Authoritative benchmark saved to {output_path}")

    return results


if __name__ == "__main__":
    benchmark_hardware_microphone()
