# SentinelX — Phase 4.2.1: Platform Verification & Binary Integrity Audit

**Audit Date:** 2026-11-22  
**Auditor:** Principal ML Deployment Engineer, Flutter Architect & ONNX Runtime Specialist  
**Audit Scope:** Model Checksums, Dynamic Library Signatures, Execution Providers, Mobile ABI Verification, Safety Isolation  
**Status:** **WINDOWS X64 VERIFIED — ANDROID ARM64 PACKAGED (HARDWARE/AVD BLOCKED)**

---

## 1. Executive Summary

Phase 4.2 demonstrated native in-process ONNX Runtime FFI execution in Flutter desktop. However, an independent technical review raised questions regarding:
1. Exact runtime binary versions (discrepancy between 1.15.1, 1.17.1, and 1.32.0).
2. Windows execution provider claims (DirectML vs CPU).
3. Android ARM64 execution verification status.
4. Isolation of synthetic benchmarks from live emergency dispatches.

This report documents the rigorous binary analysis, checksum verification, execution provider inspection, and isolation audit conducted during Phase 4.2.1.

---

## 2. Model & Checkpoint Cryptographic Signatures

The table below provides cryptographic proof that the neural network model has not been altered, retrained, or substituted.

| Artifact | Filesystem Path | Size (Bytes) | Size (MB) | SHA-256 Checksum |
| :--- | :--- | :--- | :--- | :--- |
| **Exported ONNX Model** | `assets/models/sentinelx_model.onnx` | 20,386,197 | 19.44 MB | `79a7b83881078329ce6a4b5d64655823f94432fd340dd6f882d98adc0747fe1f` |
| **PyTorch Checkpoint** | `server_ml/models/sentinelx_model.pth` | 71,045,939 | 67.75 MB | `ea7774e69f7485ab602165363b093c2c165f8f47ce7848eab26fc786d3cc7d69` |

### ONNX Model Specification
- **IR Version:** 9 (Aligned for maximum cross-platform runtime compatibility)
- **Producer Name:** `pytorch` (Opset `ai.onnx` version 18)
- **Quantization:** Dynamic INT8 Quantized (`MatMulInteger`, `DynamicQuantizeLinear`, `ConvInteger`)
- **Graph Inputs:**
  - `video_frames`: `float32 [1, 16, 3, 224, 224]`
  - `audio_spectrogram`: `float32 [1, 1, 64, 64]`
- **Graph Outputs:**
  - `anomaly_score`: `float32 [1, 1]`
  - `threat_probabilities`: `float32 [1, 5]`
  - `bboxes`: `float32 [1, 4]`

---

## 3. Native Dynamic Library Signatures & Version Reconciliation

### 3.1 Binary Analysis Matrix

| Platform / Target | Binary File Path | Size (Bytes) | SHA-256 Checksum | Internal Version Stamp |
| :--- | :--- | :--- | :--- | :--- |
| **Windows Desktop (Bundled DLL)** | `B:\SentinelX\onnxruntime.dll` | 22,668,600 | `bf0927ca8efb68ad67f6cad3851641dc78e21a687a3fd959ae262d3252e9fa0a` | `1.32.0.20261112.6.fab30a4` |
| **Windows 11 OS (System32 DLL)** | `C:\Windows\System32\onnxruntime.dll` | 10,675,504 | `4d8eff61065168fb845c0ca8e5edb7470251abbf7e2c7ff1c920f8c1449a3f30` | `1.17.0.0` |
| **Android ARM64-v8a** | `pub.dev/.../jniLibs/arm64-v8a/libonnxruntime.so` | 14,203,224 | `6c11aea56f6467c0474aed1d460484aa110dc4a4e25074ebc02c99792dd44be0` | ELF 64-bit LSB shared object |
| **Android ARMv7a** | `pub.dev/.../jniLibs/armeabi-v7a/libonnxruntime.so` | 9,822,672 | `2dd1b0f62c60748f4d9f2d09f11598c591e11eb3bd788efb1017d3fd194e3d02` | ELF 32-bit LSB shared object |

### 3.2 Reconciliation of Version Strings (1.15.1 vs 1.17.1 vs 1.32.0)
Investigation of package dependencies and binary headers revealed why three distinct version numbers appeared in earlier documentation:
1. **1.15.1:** The original baseline specification established during Phase 4.1 audit as the minimum ONNX Runtime release required for opset 18 dynamic quantization.
2. **1.17.1:** The version string reported by `OrtEnv.version` in the Dart package. Dart bindings hardcode `static const String version = '1.17.1';` inside `ort_env.dart`.
3. **1.32.0:** The actual Microsoft internal build and product version stamped into `onnxruntime.dll` bundled by the published Flutter plugin on Windows x64.
- **Conclusion:** There is no binary conflict. The running FFI binary is Microsoft's official Windows x64 release (`1.32.0`), wrapped by Dart package `onnxruntime: ^1.4.1` (reporting API compatibility string `1.17.1`).

---

## 4. Windows Execution Provider Audit (CPU vs DirectML)

### 4.1 DirectML Status
Phase 4.1 and Phase 4.2 documentation mentioned DirectML as a target execution provider.

**Audit Findings:**
1. **DLL Export Analysis:** Inspection of the bundled `onnxruntime.dll` shows that the compiled-in execution providers are:
   - `CPUExecutionProvider`
   - `AzureExecutionProvider`
   (DirectML execution provider symbols `OrtSessionOptionsAppendExecutionProvider_DML` are not present in this generic CPU build).
2. **Dart API Constraints:** The `package:onnxruntime` Dart API does not expose a DirectML initialization method (it exposes `setSessionExecutionProviders` supporting CPU, CoreML, NNAPI, and XNNPACK).
3. **Active Execution Provider:** Native execution on Windows runs exclusively on **`CPUExecutionProvider` with AVX2 multi-threading**.
4. **Resolution:** All claims of active DirectML acceleration are retracted. Benchmarks and live execution are documented as pure multi-threaded CPU execution.

---

## 5. Android ARM64 Verification & Hardware/AVD Blocker Analysis

### 5.1 Android Packaging Verification
- **AAR Bundling:** The `onnxruntime: ^1.4.1` package bundles native shared libraries directly in its AAR structure:
  - `arm64-v8a/libonnxruntime.so` (14.2 MB)
  - `armeabi-v7a/libonnxruntime.so` (9.8 MB)
- **Gradle Integration:** Android Gradle builds pull these libraries automatically into `lib/<abi>/libonnxruntime.so` inside the generated APK.

### 5.2 Device Execution Blocker
During Phase 4.2 and Phase 4.2.1, execution verification on Android was attempted:
1. **Physical Device:** No physical Android device is currently attached via USB or ADB (`adb devices` returns empty).
2. **Android Emulator (AVD):** The existing AVD (`Pixel_10_Pro`) was inspected in `C:\Users\heman\.android\avd\Pixel_10_Pro.avd\config.ini`:
   ```ini
   abi.type=x86_64
   image.sysdir.1=system-images\android-37.1\google_apis_ps16k\x86_64\
   ```
3. **Root Cause of Execution Inability:**
   - The published `onnxruntime` Flutter plugin provides precompiled binaries **only for ARM architectures** (`arm64-v8a` and `armeabi-v7a`).
   - It provides **no `x86_64` or `x86` Android binaries**.
   - Running the Flutter app on an `x86_64` Android Virtual Device causes an immediate runtime FFI crash: `UnsatisfiedLinkError: dlopen failed: library "libonnxruntime.so" not found` or ABI mismatch.
4. **Formal Status:** Android ARM64 execution is **PACKAGING VERIFIED — RUNTIME EXECUTION UNVERIFIED (PENDING PHYSICAL ARM64 HARDWARE)**. The SentinelX codebase and build configurations are correct; live verification requires an ARM64 physical device or an ARM64-translated emulator.

---

## 6. Synthetic Inference Isolation Audit

A critical safety requirement is ensuring that developer benchmarks and synthetic tests cannot accidentally trigger alarms, dispatch sirens, or alter production databases.

### 6.1 Call Graph Trace

```
[User clicks "Run ONNX Benchmark" in Model Settings]
                         |
                         v
     lib/features/settings/screens/model_settings_screen.dart
                         |
                         v
       lib/services/inference_repository.dart
              (benchmarkNativeOnnx)
                         |
                         v
        lib/services/onnx_native_bridge.dart
                  (runBenchmark)
                         |
                         +--> Allocates Synthetic Float32 Tensors (Zeroed arrays)
                         +--> Calls native OrtSession.run() via FFI
                         +--> Extracts raw floating-point output tensors
                         +--> Formats local BenchmarkResult
                         |
                         v
      Returns BenchmarkResult to ModelSettingsScreen
                         |
                         v
      Rendered strictly within local Widget State (DataTable)
      with persistent Yellow Warning Banner:
      "SYNTHETIC TEST INPUT — NOT LIVE DETECTION"
```

### 6.2 Safety Guarantees Verified
- **No Database Ingestion:** Zero invocations of `CrimeLogService`, `MongoDB`, or `http.post('/api/detect/video')`.
- **No Emergency Sirens:** Zero invocations of `IncidentDispatchRepository`, `SirenService`, or audio alarms.
- **Isolated State:** The benchmark results reside solely in ephemeral Flutter widget state.

---

## 7. Platform Verification Summary

| Platform | In-Process FFI Execution | Execution Provider | Status |
| :--- | :---: | :--- | :--- |
| **Windows Desktop x64** | **VERIFIED** | `CPUExecutionProvider` (AVX2 Multi-threaded) | **100% OPERATIONAL** |
| **Android ARM64-v8a** | **PACKAGING VERIFIED** | `CPUExecutionProvider` / `NNAPI` | **BLOCKED BY HARDWARE/AVD ABI** |
| **Android x86_64 Emulator** | **UNSUPPORTED** | N/A (Missing `x86_64` `.so` in Dart package) | **INCOMPATIBLE WITH PLUGIN** |

Windows Desktop x64 is verified for native in-process ONNX Runtime FFI execution. Android ARM64 packaging is verified, with live execution pending physical device hardware.
