#!/usr/bin/env python3
"""
SentinelX - Python ML PCM Formats Verification Script
Tests that server_ml/preprocessor.py decodes 8-bit, 16-bit, 24-bit, and 32-bit
uncompressed Linear PCM audio into normalized Mel-spectrogram tensors [1, 1, 128, 128].
"""

import json
import io
import os
import sys
from pathlib import Path

# Add repo root to sys.path
REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

import numpy as np
import scipy.io.wavfile as wav
from server_ml.preprocessor import preprocess_audio

def run_pcm_verification():
    results = {}
    sample_rate = 16000
    num_samples = 1600
    channels = 1

    for bits in [8, 16, 24, 32]:
        bytes_per_sample = bits // 8
        block_align = channels * bytes_per_sample
        byte_rate = sample_rate * block_align
        data_size = num_samples * block_align
        riff_size = 36 + data_size
        
        header = bytearray()
        header.extend(b'RIFF')
        header.extend(riff_size.to_bytes(4, 'little'))
        header.extend(b'WAVE')
        header.extend(b'fmt ')
        header.extend((16).to_bytes(4, 'little'))
        header.extend((1).to_bytes(2, 'little'))
        header.extend(channels.to_bytes(2, 'little'))
        header.extend(sample_rate.to_bytes(4, 'little'))
        header.extend(byte_rate.to_bytes(4, 'little'))
        header.extend(block_align.to_bytes(2, 'little'))
        header.extend(bits.to_bytes(2, 'little'))
        header.extend(b'data')
        header.extend(data_size.to_bytes(4, 'little'))
        
        if bits == 8:
            raw = np.full(num_samples, 128, dtype=np.uint8).tobytes()
        elif bits == 16:
            raw = np.zeros(num_samples, dtype=np.int16).tobytes()
        elif bits == 24:
            # Alternating positive/negative 24-bit samples
            sample_pos = bytes([0x00, 0x00, 0x20])
            sample_neg = bytes([0x00, 0x00, 0xE0])
            raw = (sample_pos + sample_neg) * (num_samples // 2)
        elif bits == 32:
            raw = np.zeros(num_samples, dtype=np.int32).tobytes()
            
        wav_bytes = bytes(header) + raw
        try:
            sr, audio_np = wav.read(io.BytesIO(wav_bytes))
            tensor, ms = preprocess_audio(wav_bytes)
            results[str(bits)] = {
                'success': True,
                'scipy_dtype': str(audio_np.dtype),
                'tensor_shape': list(tensor.shape),
                'elapsed_ms': round(ms, 2)
            }
        except Exception as e:
            results[str(bits)] = {
                'success': False,
                'error': str(e)
            }

    print(json.dumps(results))

if __name__ == '__main__':
    run_pcm_verification()
