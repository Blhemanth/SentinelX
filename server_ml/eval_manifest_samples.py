import json
import numpy as np
import onnxruntime as ort

model_path = r'b:\SentinelX\assets\models\sentinelx_model.onnx'
session = ort.InferenceSession(model_path, providers=['CPUExecutionProvider'])

with open(r'b:\SentinelX\data\manifests\train_manifest.json') as f:
    manifest = json.load(f)

mean = np.array([0.485, 0.456, 0.406], dtype=np.float32).reshape(1, 3, 1, 1)
std = np.array([0.229, 0.224, 0.225], dtype=np.float32).reshape(1, 3, 1, 1)

print('Testing ONNX model on training manifest samples:')
for item in manifest[:8]:
    vid_path = r'b:\SentinelX\data\\' + item['video_path']
    aud_path = r'b:\SentinelX\data\\' + item['audio_path']
    
    vid_raw = np.load(vid_path).astype(np.float32) / 255.0
    vid_norm = (vid_raw - mean) / std
    vid_tensor = np.expand_dims(vid_norm, 0).astype(np.float32)
    
    aud_raw = np.load(aud_path).astype(np.float32)
    aud_tensor = np.expand_dims(aud_raw, 0).astype(np.float32)
    
    out = session.run(None, {'video_frames': vid_tensor, 'audio_spectrogram': aud_tensor})
    probs = out[0][0]
    bbox = out[1][0]
    
    top_idx = int(np.argmax(probs))
    print(f"Sample {item['sample_id']} | True: {item['threat_label']} (id={item['class_id']}) | Probs: {np.round(probs, 4)} | Argmax: {top_idx} | BBox: {np.round(bbox, 3)} | True BBox: {item['bbox']}")
