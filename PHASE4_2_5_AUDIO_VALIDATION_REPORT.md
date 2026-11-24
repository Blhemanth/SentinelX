# SentinelX — Phase 4.2.5: Canonical Audio Validation & Buffer Sanitization Report

**Document Version:** 1.0.0  
**Date:** 2026-11-22  
**Author:** Principal Application Security Engineer & ML Systems Architect  
**Classification:** Technical Architecture & Security Specification  
**Scope:** Audio Validation Utility (`wavValidator.js`), Detection Controller (`detect.controller.js`), ML Ingestion Pipeline  

---

## 1. Executive Summary

In Phase 4.2.4, basic binary validation was introduced for audio uploads by checking for standard `RIFF` and `WAVE` magic bytes and imposing a 10 MB payload ceiling. While effective at rejecting non-audio files and payload floods, it did not inspect the inner chunk structure of WAV files.

An adversary could craft a malformed or adversarial WAV container—for example, declaring an IEEE Float format tag, an exorbitant sample rate (e.g. 192 kHz), corrupt subchunks, declared-vs-actual size mismatches, or an audio duration of several minutes—which could exhaust CPU memory during Librosa/Scipy spectrogram generation, induce pipeline crashes, or cause denial-of-service in the Python ML microservice.

**Phase 4.2.5 implements a production-grade, canonical RIFF/WAVE parser and validator** in `backend/src/utils/wavValidator.js`. The validator inspects the binary layout, enforces PCM standards, validates mathematical consistency across headers, checks for truncation, and strictly limits audio duration to $\le 30.0$ seconds.

---

## 2. Audio Format Specification & Security Constraints

The SentinelX audio ingestion pipeline accepts audio payloads accompanying surveillance video streams for acoustic anomaly detection and acoustic spectrogram feature extraction.

### 2.1 Prescribed Surveillance Audio Constraints

| Parameter | Allowed Values / Bounds | Technical Justification |
| :--- | :--- | :--- |
| **Container Format** | Canonical RIFF/WAVE container | Standard surveillance audio format compatible with Librosa, Scipy, and ffmpeg. |
| **Compression / Encoding** | Format Tag `1` (Uncompressed Linear PCM) | Rejects IEEE Float (tag 3), A-law (tag 6), $\mu$-law (tag 7), and extensible formats (tag 65534) which require specialized decoders. |
| **Channel Count** | `1` (Mono) or `2` (Stereo) | Acoustic ML inference downmixes stereo to mono; prevents arbitrary multi-channel memory bloat. |
| **Supported Sample Rates** | `8000`, `11025`, `12000`, `16000`, `22050`, `24000`, `32000`, `44100`, `48000` Hz | Standard surveillance audio sampling frequencies; rejects ultrasonic frequencies ($> 48\text{ kHz}$) that cause FFT dimension mismatch. |
| **Permitted Bit Depths** | `8`, `16`, `24`, `32` bits per sample | Standard integer PCM depths; rejects odd bit depths (e.g. 12-bit) that break byte alignment. |
| **Maximum Payload Size** | $10\text{ MB}$ ($10{,}485{,}760$ bytes) | Rejects oversized buffers with `HTTP 413 Payload Too Large`. |
| **Maximum Audio Duration** | $\le 30.0\text{ seconds}$ | Prevents multi-minute audio streams from causing denial-of-service during STFT computation. |

---

## 3. Structural Validation Pipeline (`wavValidator.js`)

The validator parses raw binary buffers sequentially according to the Microsoft RIFF/WAVE specification:

```
0                   1                   2                   3
0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                 "RIFF" (0x52494646)                           |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                 RIFF Chunk Size (Total File Size - 8)         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                 "WAVE" (0x57415645)                           |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                 "fmt " (0x666D7420)                           |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                 Subchunk1Size (16 for PCM)                    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|  AudioFormat  |  NumChannels  |          SampleRate           |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                           ByteRate                            |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|          BlockAlign           |        BitsPerSample          |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                 "data" (0x64617461)                           |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                 Subchunk2Size (NumSamples * NumChannels * ...) |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                 Raw PCM Audio Data                            |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### 3.1 Step-by-Step Validation Checks

#### Check 1: Minimum Buffer & RIFF Header Inspection
- Buffer must be at least 44 bytes (standard WAV header size).
- Bytes 0..3 must match ASCII `"RIFF"`.
- Bytes 8..11 must match ASCII `"WAVE"`.

#### Check 2: Declared RIFF Length Verification
- Bytes 4..7 read `declaredRiffSize` (32-bit unsigned little-endian).
- The validator enforces: $\text{buffer.length} \ge \text{declaredRiffSize} + 8$.
- If `declaredRiffSize + 8 > buffer.length`, the request is rejected with `HTTP 400 Bad Request` (`Truncated WAV file: declared RIFF size exceeds actual buffer length`).

#### Check 3: Multi-Chunk Traversal & Chunk Bounds Checking
- The validator iterates over subchunks starting at byte offset 12.
- For each subchunk, reads `chunkId` (4 bytes) and `chunkSize` (4 bytes).
- Enforces: $\text{offset} + 8 + \text{chunkSize} \le \text{buffer.length}$.
- Aligns next chunk offset to 2-byte boundary: $\text{offset} \mathrel{+}= 8 + \text{chunkSize} + (\text{chunkSize} \bmod 2)$.

#### Check 4: `fmt ` Subchunk Verification
- `chunkSize` must be $\ge 16$ bytes.
- `audioFormat` (bytes 20..21) must be strictly `1` (Linear PCM). Any other tag (such as `3` for IEEE Float, `6` for A-law, `7` for $\mu$-law) throws `HTTP 400 Bad Request` (`Unsupported audio encoding`).
- `numChannels` (bytes 22..23) must be `1` (mono) or `2` (stereo).
- `sampleRate` (bytes 24..27) must belong to the approved set $\{8000, 11025, 12000, 16000, 22050, 24000, 32000, 44100, 48000\}$.
- `bitsPerSample` (bytes 34..35) must be `8`, `16`, `24`, or `32`.

#### Check 5: Mathematical Consistency Verification
The validator checks that header fields satisfy the canonical RIFF PCM mathematical relationships:
$$\text{expectedBlockAlign} = \text{numChannels} \times \left(\frac{\text{bitsPerSample}}{8}\right)$$
$$\text{expectedByteRate} = \text{sampleRate} \times \text{expectedBlockAlign}$$
If $\text{blockAlign} \neq \text{expectedBlockAlign}$ or $\text{byteRate} \neq \text{expectedByteRate}$, the file is rejected as corrupted.

#### Check 6: `data` Subchunk & Truncation Detection
- The `data` subchunk must exist and declare $\text{dataChunkSize} > 0$.
- Available data bytes are verified: $\text{dataOffset} + \text{dataChunkSize} \le \text{buffer.length}$.
- If declared data size exceeds actual available bytes, the file is rejected (`Truncated WAV file: declared "data" chunk size exceeds available bytes`).

#### Check 7: Duration Bounds Enforcement
The exact duration is computed from validated PCM metadata:
$$\text{durationSec} = \frac{\text{dataChunkSize}}{\text{byteRate}}$$
If $\text{durationSec} > 30.0\text{ seconds}$, the validator throws `HTTP 400 Bad Request`:
`Audio duration of XX.XXs exceeds maximum permitted limit of 30 seconds.`

---

## 4. Integration in Ingestion Controller (`detect.controller.js`)

`backend/src/controllers/detect.controller.js` now delegates audio validation directly to `validateBase64WavAudio()`:

```javascript
// Validate Audio Payload if present
if (audioData) {
  try {
    const audioValidation = validateBase64WavAudio(audioData);
    audioMetrics = {
      sampleRate: audioValidation.sampleRate,
      channels: audioValidation.numChannels,
      bitsPerSample: audioValidation.bitsPerSample,
      durationSec: audioValidation.durationSec,
      byteLength: audioValidation.byteLength,
    };
  } catch (err) {
    if (err.statusCode === 413) {
      return res.status(413).json({ success: false, error: err.message });
    }
    return res.status(400).json({ success: false, error: err.message });
  }
}
```

---

## 5. Summary of Validation Defenses

| Adversarial Attack Vector | Validator Defense | HTTP Status | Error Message |
| :--- | :--- | :---: | :--- |
| **Payload Flood ($> 10\text{ MB}$)** | Buffer byte length check | `HTTP 413` | `Audio payload exceeds maximum permitted size of 10 MB` |
| **Non-Base64 Injection** | Strict Regex `/^[A-Za-z0-9+/=]+$/` | `HTTP 400` | `audioData contains invalid base64 encoding` |
| **Corrupted Subchunk ID** | Declared chunk offset bound check | `HTTP 400` | `Malformed WAV chunk: declared chunk size exceeds file buffer` |
| **Truncated RIFF Container** | Declared RIFF vs buffer check | `HTTP 400` | `Truncated WAV file: declared RIFF size exceeds actual buffer length` |
| **IEEE Float Exploit (Tag 3)** | Format tag enforcement (`== 1`) | `HTTP 400` | `Unsupported audio encoding: IEEE Float. Only uncompressed linear PCM supported` |
| **Extreme Sample Rate (96 kHz)**| Sample rate whitelist | `HTTP 400` | `Unsupported sample rate: 96000 Hz. Supported: 8000..48000 Hz` |
| **Invalid Bit Depth (12-bit)** | Bit depth whitelist & blockAlign math | `HTTP 400` | `Unsupported bit depth: 12 bits` |
| **Exorbitant Duration ($> 30\text{s}$)**| `dataSize / byteRate` bound check | `HTTP 400` | `Audio duration of XXs exceeds maximum permitted limit of 30 seconds` |
| **Truncated `data` Chunk** | Data offset + declared size check | `HTTP 400` | `Truncated WAV file: declared "data" chunk size exceeds available bytes` |

The SentinelX audio ingestion pipeline is now fortified against corrupted containers, parser exploits, memory exhaustion, and duration abuse.
