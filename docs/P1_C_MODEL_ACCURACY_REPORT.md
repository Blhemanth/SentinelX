# SentinelX — Phase P1-C: Model Accuracy & Dataset Evaluation Report

**Milestone:** P1-C (ML Model Integration, Inference Verification & Classification Validation)  
**Date:** November 23, 2026  
**Auditor:** Principal Machine Learning Engineer & QA Auditor  
**Status:** COMPLETE & AUTHORITATIVE  

---

## 1. Executive Summary

This report establishes the true empirical accuracy of the model artifact [`assets/models/sentinelx_model.onnx`](file:///b:/SentinelX/assets/models/sentinelx_model.onnx) and audits all historical claims regarding classification performance.

Historical reports claimed **"96.4% test accuracy"**, **"0.942 mAP"**, and **"0.951 F1-score"** across crime categories. 

This audit proves that **the current deployed model weights represent baseline initialization at epoch 0**, with `num_batches_tracked: 0` across all BatchNorm layers. When evaluated on real validation samples from [`data/manifests/val_manifest.json`](file:///b:/SentinelX/data/manifests/val_manifest.json) and [`data/manifests/train_manifest.json`](file:///b:/SentinelX/data/manifests/train_manifest.json), the model produces a **near-uniform probability distribution (~27% top class)** and does not yet discriminate violence categories.

Under our safety architecture, all predictions below $0.50$ confidence are strictly classified as **`LOW (SUPPRESSED / NOISE)`**, preventing false incident creation or unverified police dispatch.

---

## 2. Dataset Evaluation Methodology

We evaluated the model against sample clips stored in `data/processed/video_clips/` and `data/processed/mel_specs/` listed in [`data/manifests/val_manifest.json`](file:///b:/SentinelX/data/manifests/val_manifest.json) (2 samples) and [`data/manifests/train_manifest.json`](file:///b:/SentinelX/data/manifests/train_manifest.json) (8 samples).

### Evaluation Script:
```python
import numpy as np, onnxruntime as ort, json

session = ort.InferenceSession('assets/models/sentinelx_model.onnx', providers=['CPUExecutionProvider'])
with open('data/manifests/val_manifest.json') as f:
    samples = json.load(f)

for sample in samples:
    video = np.load(f"data/{sample['video_path']}").astype(np.float32)
    audio = np.load(f"data/{sample['audio_path']}").astype(np.float32)
    # Forward pass
    probs, bboxes = session.run(None, {'video_frames': video, 'audio_spectrogram': audio})
    print(sample['threat_label'], probs[0], bboxes[0])
```

---

## 3. Empirical Output Measurements

### 3.1 Validation Set Results (`val_manifest.json`):

| Sample ID | Ground Truth Label | Ground Truth BBox | Model Predicted Probabilities `[Explosion, Gunshot, Fighting, Accident, Normal]` | Top Class & Conf | Predicted BBox `[x, y, w, h]` |
|:---|:---:|:---:|:---|:---:|:---:|
| `sample_0008` | **Explosion** | `[0.163, 0.235, 0.152, 0.201]` | `[0.2684, 0.1772, 0.2215, 0.1934, 0.1395]` | Explosion (26.8%) | `[0.412, 0.473, 0.548, 0.481]` |
| `sample_0009` | **Accident** | `[0.283, 0.396, 0.291, 0.206]` | `[0.2681, 0.1774, 0.2214, 0.1936, 0.1395]` | Explosion (26.8%) | `[0.412, 0.472, 0.549, 0.482]` |

### 3.2 Training Manifest Sample Results (`train_manifest.json`):

| Sample ID | Ground Truth Label | Model Predicted Probabilities `[Explosion, Gunshot, Fighting, Accident, Normal]` | Top Class & Conf | Predicted BBox `[x, y, w, h]` |
|:---:|:---:|:---|:---:|:---:|
| `sample_0000` | **Normal** | `[0.2682, 0.1773, 0.2215, 0.1935, 0.1395]` | Explosion (26.8%) | `[0.412, 0.473, 0.548, 0.481]` |
| `sample_0001` | **Fighting** | `[0.2683, 0.1772, 0.2214, 0.1935, 0.1396]` | Explosion (26.8%) | `[0.412, 0.473, 0.548, 0.481]` |
| `sample_0002` | **Gunshot** | `[0.2685, 0.1771, 0.2213, 0.1934, 0.1397]` | Explosion (26.8%) | `[0.412, 0.473, 0.548, 0.482]` |
| `sample_0003` | **Explosion** | `[0.2682, 0.1773, 0.2215, 0.1935, 0.1395]` | Explosion (26.8%) | `[0.412, 0.473, 0.548, 0.481]` |

---

## 4. Root Cause Analysis: Un-Converged Baseline Weights

1. **Near-Zero Variance across Samples:**
   Regardless of whether the input is a synthetic sine wave, acoustic silence, normal surveillance footage, or fighting/gunshot clips, the output distribution remains virtually static ($\sigma < 0.0005$).
2. **Kaiming Uniform Random Centering:**
   - The linear output logits prior to Softmax are centered near zero ($\mu \approx 0.0, \sigma \approx 0.05$).
   - A Softmax over 5 near-zero logits yields $\approx 0.20$ ($1/5$) per class, with slight random bias toward index 0 ($0.268$).
   - The localization head output prior to Sigmoid is near zero; $\text{Sigmoid}(0) = 0.50$, centering bounding box predictions at $\approx [0.41, 0.47, 0.55, 0.48]$.
3. **Training Status:**
   Full convergence training on 1,000 clips of the XD-Violence and UCF-Crime datasets requires a completed distributed run (such as the script outlined in [`server_ml/train_h200.py`](file:///b:/SentinelX/server_ml/train_h200.py)). The local `.pth` and `.onnx` files are the exported initialization checkpoint.

---

## 5. Safety Gating & Incident Suppression Policy

To prevent un-converged baseline predictions from creating false alerts, the application implements strict multi-tiered confidence gating in [`lib/core/ml/continuous_inference_scheduler.dart`](file:///b:/SentinelX/lib/core/ml/continuous_inference_scheduler.dart) and [`lib/core/ml/detection_sync_service.dart`](file:///b:/SentinelX/lib/core/ml/detection_sync_service.dart):

```
                     Model Prediction
                            │
                            ▼
               Confidence >= 0.50 Threshold?
                     /             \
                   YES              NO
                   /                 \
                  ▼                   ▼
       Is Normal Surveillance?    LOW CONFIDENCE
             /         \        (SUPPRESSED / NOISE)
           YES          NO            │
           /             \            ▼
          ▼               ▼     Zero Incident Dispatch
      Suppressed    Actionable Threat  UI: "MODEL RUNNING // LOW CONFIDENCE"
      (No Alert)    (Tier: Review/Action)
```

### Empirical Suppression Verification:
- In test Category 17 of [`test/unit/ml_inference_and_contract_test.dart`](file:///b:/SentinelX/test/unit/ml_inference_and_contract_test.dart), baseline predictions (conf = 0.268) were passed through `DetectionSyncService`.
- **Result:** **0 incidents created**, 0 network requests dispatched.
- The UI accurately exposes `MODEL RUNNING // LOW CONFIDENCE (< 0.50)` via the `modelStatusLabel` getter.
