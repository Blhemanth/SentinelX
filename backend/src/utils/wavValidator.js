/**
 * SentinelX - Strict WAV Audio Format & Structure Validator
 * 
 * Deeply validates WAV PCM audio payloads:
 * 1. Base64 encoding validity and character set
 * 2. Buffer length bounds (minimum 44 bytes, maximum 10 MB)
 * 3. RIFF/WAVE header chunk structure
 * 4. Declared RIFF file size vs actual buffer length
 * 5. Canonical 'fmt ' subchunk parsing:
 *    - Audio format tag (strictly 1 = linear PCM)
 *    - Channel count (1 = mono, 2 = stereo)
 *    - Sample rate (supported surveillance rates: 8000 Hz to 48000 Hz)
 *    - Bit depth (8, 16, 24, 32 bits per sample; 16-bit preferred)
 *    - Byte rate and block alignment mathematical consistency
 * 6. Canonical 'data' subchunk parsing:
 *    - Presence of 'data' chunk
 *    - Declared data length vs buffer bounds (truncation detection)
 *    - Audio duration calculation: duration = dataSize / byteRate
 *    - Maximum permitted duration limit (strictly <= 30.0 seconds)
 */

const MAX_AUDIO_BYTES = 10 * 1024 * 1024; // 10 MB
const MAX_AUDIO_DURATION_SECONDS = 30.0;  // 30 seconds
const SUPPORTED_SAMPLE_RATES = [8000, 11025, 12000, 16000, 22050, 24000, 32000, 44100, 48000];
const SUPPORTED_BIT_DEPTHS = [8, 16, 24, 32];

/**
 * Validate a decoded WAV audio Buffer.
 * @param {Buffer} buffer
 * @returns {{ valid: boolean, error?: string, metadata?: object }}
 */
function validateWavAudioBuffer(buffer) {
  if (!Buffer.isBuffer(buffer)) {
    return { valid: false, error: 'Input must be a valid Buffer.' };
  }

  // 1. Minimum buffer length check (canonical minimal WAV header is 44 bytes)
  if (buffer.length < 44) {
    return {
      valid: false,
      error: `Truncated WAV file: buffer length (${buffer.length} bytes) is smaller than canonical header size (44 bytes).`,
    };
  }

  // 2. Maximum payload size check
  if (buffer.length > MAX_AUDIO_BYTES) {
    return {
      valid: false,
      error: `Audio payload exceeds maximum permitted size of 10 MB (${(buffer.length / (1024 * 1024)).toFixed(2)} MB).`,
    };
  }

  // 3. RIFF chunk identifier
  const riffMagic = buffer.toString('ascii', 0, 4);
  if (riffMagic !== 'RIFF') {
    return {
      valid: false,
      error: `Invalid audio format: file must start with "RIFF" magic bytes (found: "${riffMagic}").`,
    };
  }

  // 4. Declared RIFF chunk size consistency
  const declaredRiffSize = buffer.readUInt32LE(4);
  const expectedFileSize = declaredRiffSize + 8;
  if (buffer.length < expectedFileSize) {
    return {
      valid: false,
      error: `Truncated WAV file: declared RIFF size (${expectedFileSize} bytes) exceeds actual buffer length (${buffer.length} bytes).`,
    };
  }
  if (buffer.length > expectedFileSize) {
    return {
      valid: false,
      error: `Malformed WAV file: buffer length (${buffer.length} bytes) exceeds declared RIFF container size (${expectedFileSize} bytes). Trailing unparsed data detected.`,
    };
  }

  // 5. WAVE format identifier
  const waveMagic = buffer.toString('ascii', 8, 12);
  if (waveMagic !== 'WAVE') {
    return {
      valid: false,
      error: `Invalid audio format: missing "WAVE" format identifier (found: "${waveMagic}").`,
    };
  }

  // 6. Chunk parsing loop
  let offset = 12;
  let fmtChunk = null;
  let dataChunk = null;

  while (offset < expectedFileSize) {
    if (offset + 8 > expectedFileSize) {
      return {
        valid: false,
        error: `Malformed WAV file: incomplete chunk header at offset ${offset} (available: ${expectedFileSize - offset} bytes, required: 8).`,
      };
    }

    const chunkId = buffer.toString('ascii', offset, offset + 4);
    const chunkSize = buffer.readUInt32LE(offset + 4);

    if (offset + 8 + chunkSize > expectedFileSize) {
      // Chunk declares more bytes than remaining buffer
      if (chunkId === 'data') {
        return {
          valid: false,
          error: `Truncated WAV file: declared "data" chunk size (${chunkSize} bytes) exceeds available bytes (${expectedFileSize - (offset + 8)}).`,
        };
      }
      return {
        valid: false,
        error: `Malformed WAV chunk "${chunkId}": declared chunk size (${chunkSize} bytes) exceeds file buffer.`,
      };
    }

    if (chunkId === 'fmt ') {
      if (fmtChunk) {
        return {
          valid: false,
          error: 'Malformed WAV file: duplicate "fmt " chunk detected.',
        };
      }

      if (chunkSize < 16) {
        return {
          valid: false,
          error: `Malformed WAV "fmt " chunk: size (${chunkSize} bytes) is smaller than PCM requirement (16 bytes).`,
        };
      }

      const audioFormat = buffer.readUInt16LE(offset + 8);
      const numChannels = buffer.readUInt16LE(offset + 10);
      const sampleRate = buffer.readUInt32LE(offset + 12);
      const byteRate = buffer.readUInt32LE(offset + 16);
      const blockAlign = buffer.readUInt16LE(offset + 20);
      const bitsPerSample = buffer.readUInt16LE(offset + 22);

      // Audio format tag: strictly 1 (Linear PCM)
      if (audioFormat !== 1) {
        const formatNames = { 3: 'IEEE Float', 6: 'A-law', 7: 'mu-law', 65534: 'Extensible' };
        const formatName = formatNames[audioFormat] || `tag 0x${audioFormat.toString(16)}`;
        return {
          valid: false,
          error: `Unsupported audio encoding: ${formatName}. Only uncompressed linear PCM (format tag 1) is supported.`,
        };
      }

      // Channel count: mono (1) or stereo (2)
      if (numChannels < 1 || numChannels > 2) {
        return {
          valid: false,
          error: `Unsupported channel count: ${numChannels}. Only mono (1) and stereo (2) are supported.`,
        };
      }

      // Sample rate
      if (!SUPPORTED_SAMPLE_RATES.includes(sampleRate)) {
        return {
          valid: false,
          error: `Unsupported sample rate: ${sampleRate} Hz. Supported: ${SUPPORTED_SAMPLE_RATES.join(', ')} Hz.`,
        };
      }

      // Bit depth
      if (!SUPPORTED_BIT_DEPTHS.includes(bitsPerSample)) {
        return {
          valid: false,
          error: `Unsupported bit depth: ${bitsPerSample} bits. Supported PCM bit depths: ${SUPPORTED_BIT_DEPTHS.join(', ')}.`,
        };
      }

      // Block align verification: blockAlign = numChannels * (bitsPerSample / 8)
      const expectedBlockAlign = numChannels * (bitsPerSample / 8);
      if (blockAlign !== expectedBlockAlign) {
        return {
          valid: false,
          error: `Malformed WAV header: blockAlign (${blockAlign}) does not match expected (${expectedBlockAlign}).`,
        };
      }

      // Byte rate verification: byteRate = sampleRate * blockAlign
      const expectedByteRate = sampleRate * blockAlign;
      if (byteRate !== expectedByteRate) {
        return {
          valid: false,
          error: `Malformed WAV header: byteRate (${byteRate}) does not match expected (${expectedByteRate}).`,
        };
      }

      fmtChunk = {
        audioFormat,
        numChannels,
        sampleRate,
        byteRate,
        blockAlign,
        bitsPerSample,
      };
    } else if (chunkId === 'data') {
      if (dataChunk) {
        return {
          valid: false,
          error: 'Malformed WAV file: duplicate "data" chunk detected.',
        };
      }

      if (!fmtChunk) {
        return {
          valid: false,
          error: 'Malformed WAV file: "data" chunk appeared before "fmt " chunk.',
        };
      }

      if (chunkSize === 0) {
        return {
          valid: false,
          error: 'Decoded audioData is empty (0 samples in "data" chunk).',
        };
      }

      dataChunk = {
        offset: offset + 8,
        size: chunkSize,
      };
    }

    // Advance to next chunk (padded to 2-byte boundary per RIFF specification)
    const padding = chunkSize % 2;
    if (offset + 8 + chunkSize + padding > expectedFileSize) {
      return {
        valid: false,
        error: `Malformed WAV file: missing padding byte for odd-sized chunk "${chunkId}".`,
      };
    }
    offset += 8 + chunkSize + padding;
  }

  if (!fmtChunk) {
    return { valid: false, error: 'Malformed WAV file: missing required "fmt " chunk.' };
  }

  if (!dataChunk) {
    return { valid: false, error: 'Malformed WAV file: missing required "data" chunk.' };
  }

  // Calculate duration
  const durationSeconds = dataChunk.size / fmtChunk.byteRate;
  if (durationSeconds > MAX_AUDIO_DURATION_SECONDS) {
    return {
      valid: false,
      error: `Audio duration of ${durationSeconds.toFixed(2)}s exceeds maximum permitted limit of ${MAX_AUDIO_DURATION_SECONDS} seconds.`,
    };
  }

  return {
    valid: true,
    metadata: {
      format: 'PCM',
      channels: fmtChunk.numChannels,
      sampleRate: fmtChunk.sampleRate,
      bitsPerSample: fmtChunk.bitsPerSample,
      dataBytes: dataChunk.size,
      durationSeconds: parseFloat(durationSeconds.toFixed(3)),
    },
  };
}

/**
 * Validate a base64-encoded WAV audio string.
 * @param {string} base64Str
 * @returns {{ valid: boolean, error?: string, buffer?: Buffer, metadata?: object }}
 */
function validateBase64WavAudio(base64Str) {
  if (typeof base64Str !== 'string') {
    return { valid: false, error: 'audioData must be a base64-encoded string.' };
  }

  const trimmed = base64Str.trim();
  if (trimmed === '') {
    return { valid: false, error: 'Decoded audioData is empty (0 bytes).' };
  }

  // Strict base64 character set validation
  const base64Regex = /^[A-Za-z0-9+/=]+$/;
  if (!base64Regex.test(trimmed.replace(/\s+/g, ''))) {
    return { valid: false, error: 'audioData contains invalid base64 encoding.' };
  }

  let buffer;
  try {
    buffer = Buffer.from(trimmed, 'base64');
  } catch {
    return { valid: false, error: 'audioData could not be decoded.' };
  }

  if (buffer.length === 0) {
    return { valid: false, error: 'Decoded audioData is empty (0 bytes).' };
  }

  const result = validateWavAudioBuffer(buffer);
  if (!result.valid) {
    return { valid: false, error: result.error };
  }

  return { valid: true, buffer, metadata: result.metadata };
}

module.exports = {
  validateWavAudioBuffer,
  validateBase64WavAudio,
  MAX_AUDIO_BYTES,
  MAX_AUDIO_DURATION_SECONDS,
  SUPPORTED_SAMPLE_RATES,
  SUPPORTED_BIT_DEPTHS,
};
