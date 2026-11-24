import numpy as np
import onnxruntime as ort

model_path = r'b:\SentinelX\assets\models\sentinelx_model.onnx'
session = ort.InferenceSession(model_path, providers=['CPUExecutionProvider'])

# 1. Test with all zeros
v_zero = np.zeros((1, 16, 3, 224, 224), dtype=np.float32)
a_zero = np.zeros((1, 1, 128, 128), dtype=np.float32)

out_zero = session.run(None, {'video_frames': v_zero, 'audio_spectrogram': a_zero})
probs_zero, bbox_zero = out_zero[0], out_zero[1]

print('Zero input outputs:')
print('  Probs shape:', probs_zero.shape, 'Values:', probs_zero[0])
print('  Sum of probs:', np.sum(probs_zero[0]))
print('  BBox shape:', bbox_zero.shape, 'Values:', bbox_zero[0])

# 2. Test with acoustic silence (-80 dB) and normal video
a_silence = np.full((1, 1, 128, 128), -80.0, dtype=np.float32)
np.random.seed(42)
v_rand = np.random.randn(1, 16, 3, 224, 224).astype(np.float32)

out_silence = session.run(None, {'video_frames': v_rand, 'audio_spectrogram': a_silence})
probs_silence, bbox_silence = out_silence[0], out_silence[1]

print('\nSilence audio + random video outputs:')
print('  Probs shape:', probs_silence.shape, 'Values:', probs_silence[0])
print('  Sum of probs:', np.sum(probs_silence[0]))
print('  BBox shape:', bbox_silence.shape, 'Values:', bbox_silence[0])

# 3. Test with acoustic spike (+40 dB) and random video
a_spike = np.full((1, 1, 128, 128), 40.0, dtype=np.float32)
out_spike = session.run(None, {'video_frames': v_rand, 'audio_spectrogram': a_spike})
probs_spike, bbox_spike = out_spike[0], out_spike[1]

print('\nSpike audio + random video outputs:')
print('  Probs shape:', probs_spike.shape, 'Values:', probs_spike[0])
print('  Sum of probs:', np.sum(probs_spike[0]))
print('  BBox shape:', bbox_spike.shape, 'Values:', bbox_spike[0])
