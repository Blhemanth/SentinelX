#!/usr/bin/env python3
"""
SentinelX - Phase 4.4.1.2 DSP Numerical Parity Evaluator
Compares every element of the 16,384-element Mel-spectrogram tensors between
server_ml/preprocessor.py (PyTorch torchaudio) and lib/core/audio/audio_preprocessor.dart.
Calculates MaxAE, MAE, RMSE, Relative Error, and Pass/Fail against numerical tolerance.
"""

import json
import math
from pathlib import Path
import numpy as np

REPO_ROOT = Path(__file__).resolve().parent.parent
PARITY_DIR = REPO_ROOT / "test" / "dsp_parity"

def evaluate_parity():
    print("=" * 80)
    print(" SENTINELX — PHASE 4.4.1.2 DSP NUMERICAL PARITY EVALUATION ")
    print("=" * 80)
    
    with open(PARITY_DIR / "manifest.json", "r", encoding="utf-8") as f:
        manifest = json.load(f)
        
    with open(PARITY_DIR / "dart_results.json", "r", encoding="utf-8") as f:
        dart_meta = json.load(f)
        
    test_cases = manifest["test_cases"]
    
    # Mathematical Tolerance:
    # 32-bit floating point precision through 1024-point FFT butterfly additions and log10
    # typically has roundoff of ~1e-4 to 1e-3 dB.
    TOLERANCE_MAX_AE_DB = 0.05 # 0.05 dB maximum acceptable discrepancy
    TOLERANCE_MAE_DB = 0.005   # 0.005 dB mean acceptable discrepancy
    
    comparison_results = {}
    
    print(f"{'Waveform':<18} | {'MaxAE (dB)':<12} | {'MAE (dB)':<12} | {'RMSE (dB)':<12} | {'Rel Err (%)':<12} | {'Status':<8}")
    print("-" * 84)
    
    all_passed = True
    
    for name in test_cases:
        py_file = PARITY_DIR / f"{name}_py_tensor.bin"
        dart_file = PARITY_DIR / f"{name}_dart_tensor.bin"
        
        py_data = np.fromfile(py_file, dtype=np.float32)
        dart_data = np.fromfile(dart_file, dtype=np.float32)
        
        assert len(py_data) == 16384, f"PyTorch tensor length is {len(py_data)}, expected 16384"
        assert len(dart_data) == 16384, f"Dart tensor length is {len(dart_data)}, expected 16384"
        
        # Absolute Error
        abs_error = np.abs(py_data - dart_data)
        max_ae = float(np.max(abs_error))
        mae = float(np.mean(abs_error))
        rmse = float(np.sqrt(np.mean(abs_error ** 2)))
        
        # Relative Error where signal is meaningful (avoid dividing by zero)
        denom = np.maximum(np.abs(py_data), 1e-5)
        rel_error = np.mean(abs_error / denom) * 100.0
        max_rel_error = np.max(abs_error / denom) * 100.0
        
        passed = (max_ae <= TOLERANCE_MAX_AE_DB) and (mae <= TOLERANCE_MAE_DB)
        if not passed:
            all_passed = False
            
        status_str = "PASS" if passed else "FAIL"
        
        print(f"{name:<18} | {max_ae:<12.6f} | {mae:<12.6f} | {rmse:<12.6f} | {rel_error:<12.6f} | {status_str:<8}")
        
        comparison_results[name] = {
            "num_elements": len(py_data),
            "max_absolute_error_db": round(float(max_ae), 7),
            "mean_absolute_error_db": round(float(mae), 7),
            "root_mean_square_error_db": round(float(rmse), 7),
            "mean_relative_error_pct": round(float(rel_error), 5),
            "max_relative_error_pct": round(float(max_rel_error), 5),
            "tolerance_max_ae_db": float(TOLERANCE_MAX_AE_DB),
            "tolerance_mae_db": float(TOLERANCE_MAE_DB),
            "py_min_db": round(float(np.min(py_data)), 2),
            "py_max_db": round(float(np.max(py_data)), 2),
            "dart_min_db": round(float(np.min(dart_data)), 2),
            "dart_max_db": round(float(np.max(dart_data)), 2),
            "time_frames_actual_stft": int(dart_meta[name]["time_frames_generated"]),
            "time_frames_padded": int(128 - dart_meta[name]["time_frames_generated"]),
            "status": status_str,
        }
        
    print("-" * 84)
    print(f"Overall Numerical Parity Result: {'PASS (ALL 6 WAVEFORMS CONGRUENT)' if all_passed else 'FAIL'}\n")
    
    with open(PARITY_DIR / "parity_metrics.json", "w", encoding="utf-8") as f:
        json.dump(comparison_results, f, indent=2)
        
    print(f"[Results] Detailed comparison saved to {PARITY_DIR / 'parity_metrics.json'}")
    return comparison_results

if __name__ == "__main__":
    evaluate_parity()
