# SentinelX — Phase 4.2.2: Platform Verification & Mobile Status Report

**Audit Date:** 2026-11-22  
**Auditor:** Principal Flutter Architect & ONNX Runtime Systems Engineer  
**Scope:** Cross-Platform Deployment Verification, Native Dynamic Libraries, Android ABI Incompatibilities, Hardware Availability  
**Status:** **WINDOWS X64 VERIFIED — ANDROID ARM64 PACKAGED (DEVICE EXECUTION UNVERIFIED)**

---

## 1. Executive Summary

Phase 4.2.2 establishes an objective, empirical record of platform readiness for native ONNX Runtime execution across Windows Desktop x64 and Android Mobile devices.

**Key Findings:**
- **Windows Desktop x64:** Fully operational and verified. In-process C-FFI inference executes cleanly on `CPUExecutionProvider` (Multi-Threaded AVX2) with an average latency of ~833 ms. DirectML claims are formally retracted.
- **Android Mobile:** Native library packaging is verified for `arm64-v8a` and `armeabi-v7a`. However, **runtime execution remains explicitly UNVERIFIED**. The only configured local emulator uses an `x86_64` system image, which is incompatible with the ARM-only binaries bundled in the published `onnxruntime: ^1.4.1` package. No physical ARM64 device is currently attached. In accordance with strict audit constraints, no unsupported third-party x86_64 binaries or unverified custom runtimes were introduced.

---

## 2. Platform Status Matrix

| Platform Target | Architecture | In-Process FFI Inference | Execution Provider | Packaging Status | Runtime Execution Status | Blockers / Notes |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **Windows Desktop** | `x86_64` | **VERIFIED** | `CPUExecutionProvider` | Complete (`onnxruntime.dll` bundled) | **100% OPERATIONAL** | Preloaded official DLL resolves Windows 11 System32 shadowing. |
| **Android Physical**| `arm64-v8a` | **UNVERIFIED** | `CPUExecutionProvider` / `NNAPI` | Complete (`.so` bundled in AAR) | **UNVERIFIED** | No physical ARM64 device attached via ADB. |
| **Android Physical**| `armeabi-v7a` | **UNVERIFIED** | `CPUExecutionProvider` | Complete (`.so` bundled in AAR) | **UNVERIFIED** | Legacy 32-bit ARM hardware not connected. |
| **Android Emulator**| `x86_64` | **UNSUPPORTED** | N/A | Missing native `.so` | **BLOCKED** | Dart plugin does NOT bundle x86_64 Android binaries. |
| **React Web Client**| Browser / JS | N/A (Cloud Ingestion) | Python ML Bridge | N/A | **OPERATIONAL** | Ingests via Express REST API to Python ML service. |

---

## 3. Windows Desktop x64 Verification

### 3.1 Dynamic Library Audit
- **Filesystem Path:** `B:\SentinelX\onnxruntime.dll`
- **File Size:** `22,668,600 bytes` (21.62 MB)
- **SHA-256 Checksum:** `bf0927ca8efb68ad67f6cad3851641dc78e21a687a3fd959ae262d3252e9fa0a`
- **Internal Product Version:** `1.32.0.20261112.6.fab30a4`
- **Resolved Execution Providers:** `['AzureExecutionProvider', 'CPUExecutionProvider']`

### 3.2 Performance & Execution Characteristics
- **Execution Mode:** Multi-threaded CPU execution with AVX2 instruction set vectorization.
- **DirectML Acceleration:** **Absent.** DirectML export symbols (`OrtSessionOptionsAppendExecutionProvider_DML`) are not present in this official dynamic library, nor are DirectML options exposed by the `package:onnxruntime` Dart bindings.
- **Empirical Execution Metrics (Passes 1..3):**
  - Pass 1 Latency: 838 ms
  - Pass 2 Latency: 808 ms
  - Pass 3 Latency: 854 ms
  - Average Latency: 833.3 ms
  - Throughput: ~1.20 FPS
- **Architectural Implication for Phase 4.3:** Because 833 ms exceeds the 16.6 ms frame budget of a 60 FPS UI by ~50x, all live video inference MUST execute inside dedicated background worker isolates (`compute` or `Isolate.spawn`).

---

## 4. Android Mobile Verification & Blocker Investigation

### 4.1 Native Shared Library Packaging
Inspection of the hosted pub cache for `package:onnxruntime` confirms the presence of precompiled Android shared libraries:

| Android ABI | Filesystem Path | Binary Size | SHA-256 Checksum | Binary Architecture |
| :--- | :--- | :---: | :---: | :--- |
| **`arm64-v8a`** | `.../jniLibs/arm64-v8a/libonnxruntime.so` | 14,203,224 bytes | `6c11aea56f6467c0474aed1d460484aa110dc4a4e25074ebc02c99792dd44be0` | ELF 64-bit LSB shared object, ARM aarch64 |
| **`armeabi-v7a`**| `.../jniLibs/armeabi-v7a/libonnxruntime.so` | 9,822,672 bytes | `2dd1b0f62c60748f4d9f2d09f11598c591e11eb3bd788efb1017d3fd194e3d02` | ELF 32-bit LSB shared object, ARM EABI5 |

These libraries are automatically packaged into the `lib/<abi>/libonnxruntime.so` folder of compiled Android application packages (APKs) by the Android Gradle plugin.

### 4.2 Hardware & Emulator Blocker Analysis
1. **Physical Device Audit:**  
   Executing `adb devices` returns:
   ```
   List of devices attached
   (empty)
   ```
   No physical ARM64 Android device is connected to the host development workstation.
2. **Local AVD Emulator Audit:**  
   Inspection of `C:\Users\heman\.android\avd\Pixel_10_Pro.avd\config.ini`:
   ```ini
   abi.type=x86_64
   image.sysdir.1=system-images\android-37.1\google_apis_ps16k\x86_64\
   ```
3. **The Root Cause:**  
   The published `onnxruntime` Flutter plugin includes binaries **only for physical ARM targets** (`arm64-v8a` and `armeabi-v7a`). It bundles **zero x86_64 or x86 binaries**. Attempting to instantiate an `OrtSession` on an `x86_64` AVD throws an immediate linking error:
   ```
   java.lang.UnsatisfiedLinkError: dlopen failed: library "libonnxruntime.so" not found
   ```
4. **Policy Compliance:**  
   In compliance with Phase 4.2.2 change restrictions:
   - No unofficial, third-party, or unverified x86_64 `.so` files were injected into the project.
   - No custom runtime wrappers were fabricated.
   - Android native inference is **strictly and transparently classified as UNVERIFIED on device**.

---

## 5. Prerequisite Checklist for Phase 4.3 Mobile Progression

Before live camera or microphone preprocessing can be validated on Android, the following hardware prerequisite must be satisfied:

1. **Hardware Requirement:** Connect a physical Android smartphone or tablet running `arm64-v8a` architecture (Android 10+ / API 29+).
2. **ADB Authentication:** Enable USB Debugging on the physical device and authorize the host development workstation (`adb devices` must report device `online`).
3. **On-Device Smoke Test:** Execute `flutter run -d <device_id>` and trigger the **NATIVE ONNX RUNTIME PROOF** benchmark from the Model Settings screen.
4. **Memory Verification:** Verify that the 20.38 MB INT8 model and dynamic tensor buffers load cleanly within the device's heap without triggering `OutOfMemoryError`.
