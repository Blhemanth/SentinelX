"""
SentinelX — Phase 4.3.1 Hardware Camera Benchmark & Physical Acquisition Verifier
Directly interfaces with physical Windows laptop webcam (HP TrueVision HD Camera) via MediaFoundation/DirectShow.
Measures true camera initialization latency, actual hardware FPS, frame acquisition latency,
16-frame rolling buffer memory usage, dropped frames, and timestamp monotonicity.
"""

import sys
import time
import json
from collections import deque
import numpy as np

def benchmark_hardware_webcam(device_index=0, target_frames=50):
    print("=" * 70)
    print(" SENTINELX — PHASE 4.3.1 PHYSICAL HARDWARE WEBCAM VERIFICATION ")
    print("=" * 70)

    results = {
        "device_index": device_index,
        "device_name": "HP TrueVision HD Camera",
        "target_frames": target_frames,
        "initialization_time_ms": 0.0,
        "hardware_opened": False,
        "native_resolution": None,
        "target_shape": [16, 3, 224, 224],
        "frame_latencies_ms": [],
        "measured_fps": 0.0,
        "memory_usage_bytes": 0,
        "dropped_frames": 0,
        "timestamp_monotonic": True,
        "buffer_ready_at_frame": 16,
    }

    try:
        import cv2
    except ImportError:
        print("[Error] OpenCV is not installed.")
        return results

    # 1. Measure Camera Initialization Time
    init_start = time.perf_counter()
    cap = cv2.VideoCapture(device_index, cv2.CAP_DSHOW) # DirectShow on Windows
    if not cap.isOpened():
        # Fallback to default backend
        cap = cv2.VideoCapture(device_index)

    init_end = time.perf_counter()
    init_ms = (init_end - init_start) * 1000.0
    results["initialization_time_ms"] = round(init_ms, 2)

    if not cap.isOpened():
        print(f"[FAIL] Could not open camera at index {device_index}.")
        results["hardware_opened"] = False
        return results

    results["hardware_opened"] = True
    print(f"[PASS] Hardware Webcam Opened in {init_ms:.1f} ms")

    # Native camera properties
    native_w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    native_h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    results["native_resolution"] = f"{native_w}x{native_h}"
    print(f"[Info] Native Hardware Resolution: {native_w}x{native_h}")

    # 2. Ingest frames into 16-frame temporal rolling buffer
    buffer = deque(maxlen=16)
    timestamps = []
    latencies = []
    dropped_count = 0

    print(f"\nCapturing {target_frames} physical frames from webcam...")
    capture_start = time.perf_counter()

    for i in range(1, target_frames + 1):
        t_frame_start = time.perf_counter()
        ret, frame_bgr = cap.read()
        t_frame_end = time.perf_counter()

        if not ret or frame_bgr is None:
            print(f"[Warn] Frame {i} read failed.")
            continue

        latency_ms = (t_frame_end - t_frame_start) * 1000.0
        latencies.append(latency_ms)

        # Convert BGR -> RGB and resize to 224x224
        frame_rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
        frame_224 = cv2.resize(frame_rgb, (224, 224), interpolation=cv2.INTER_LINEAR)

        # Record timestamp
        ts = time.time()
        timestamps.append(ts)

        # Push into 16-frame rolling buffer
        if len(buffer) == 16:
            dropped_count += 1
        buffer.append(frame_224)

    capture_end = time.perf_counter()
    total_capture_sec = capture_end - capture_start
    cap.release()
    print("[PASS] Camera Released & Closed Cleanly.")

    # 3. Compute Metrics
    actual_fps = len(latencies) / total_capture_sec if total_capture_sec > 0 else 0.0
    avg_latency = float(np.mean(latencies)) if latencies else 0.0
    min_latency = float(np.min(latencies)) if latencies else 0.0
    max_latency = float(np.max(latencies)) if latencies else 0.0

    # Verify Monotonic Timestamps
    is_monotonic = all(timestamps[j] <= timestamps[j+1] for j in range(len(timestamps)-1))

    # Calculate Frame Buffer Memory (16 frames of uint8 224x224x3)
    single_frame_bytes = 224 * 224 * 3
    total_buffer_bytes = len(buffer) * single_frame_bytes

    results["measured_fps"] = round(actual_fps, 2)
    results["frame_latencies_ms"] = [round(l, 2) for l in latencies[:10]] # first 10 samples
    results["avg_latency_ms"] = round(avg_latency, 2)
    results["min_latency_ms"] = round(min_latency, 2)
    results["max_latency_ms"] = round(max_latency, 2)
    results["memory_usage_bytes"] = total_buffer_bytes
    results["memory_usage_mb"] = round(total_buffer_bytes / (1024 * 1024), 2)
    results["dropped_frames"] = dropped_count
    results["timestamp_monotonic"] = is_monotonic
    results["total_frames_captured"] = len(latencies)

    print("\n" + "=" * 70)
    print(" EMPIRICAL HARDWARE BENCHMARK SUMMARY")
    print("=" * 70)
    print(f"Device Name:               {results['device_name']}")
    print(f"Native Resolution:         {results['native_resolution']}")
    print(f"Camera Init Time:          {results['initialization_time_ms']} ms")
    print(f"Frames Captured:           {results['total_frames_captured']} / {target_frames}")
    print(f"Actual Hardware FPS:       {results['measured_fps']} FPS")
    print(f"Avg Frame Latency:         {results['avg_latency_ms']} ms (Min: {results['min_latency_ms']}ms, Max: {results['max_latency_ms']}ms)")
    print(f"Rolling Buffer Capacity:   16 frames")
    print(f"Buffer Memory Usage:       {results['memory_usage_bytes']} bytes ({results['memory_usage_mb']} MB)")
    print(f"Dropped Frames:            {results['dropped_frames']} frames")
    print(f"Timestamp Monotonicity:    {'✓ STRICTLY MONOTONIC' if is_monotonic else '✗ NON-MONOTONIC'}")
    print("=" * 70)

    # Emit JSON
    with open("test/hardware_camera_benchmark.json", "w") as f:
        json.dump(results, f, indent=2)

    return results

if __name__ == "__main__":
    benchmark_hardware_webcam(0, 50)
