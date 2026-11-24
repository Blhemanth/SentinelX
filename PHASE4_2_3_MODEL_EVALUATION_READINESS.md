# SentinelX — Phase 4.2.3: Model Evaluation Readiness & Validation Plan

**Audit Date:** 2026-11-22  
**Auditor:** Principal ML Validation Engineer & Independent QA Lead  
**Scope:** Checkpoint Verification Strategy, 4-Tier Validation Hierarchy, Independent Ground-Truth Protocol, Bounding Box Localization Limits  
**Status:** **EVALUATION FRAMEWORK ESTABLISHED (SEMANTIC CLASS ACCURACY CLASSIFIED AS UNVERIFIED)**

---

## 1. Executive Summary

Phase 4.2.1 and Phase 4.2.2 established that while the multimodal neural network (`SentinelXNet`) executes successfully in-process via ONNX Runtime FFI and preserves cross-stack software contracts, the **checkpoint's semantic class alignment remains UNVERIFIED AT CHECKPOINT LEVEL**. Furthermore, training dataset preparation scripts (`prepare_dataset.py`) utilized synthetic random noise and ungrounded bounding-box coordinates.

In compliance with strict audit directives:
- No weights have been altered or retrained.
- No class taxonomies have been invented.
- Software contract consistency is frozen to `['Explosion', 'Gunshot', 'Fighting', 'Accident', 'Normal']`.

This report establishes the **Definitive Model Evaluation Readiness Plan** to independently evaluate semantic correctness and detection accuracy once ground-truth surveillance data is ingested.

---

## 2. The Four-Tier Validation Hierarchy

A foundational flaw in earlier project documentation was conflating software execution with machine learning model accuracy. SentinelX formally separates validation into four distinct, non-fungible tiers:

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│ TIER 4: ACTUAL DETECTION ACCURACY                                                 │
│ Empirical precision, recall, F1, FPR, and ECE on unseen real-world test data.     │
│ [STATUS: UNVERIFIED — Requires independent real-world ground-truth test suite]    │
├───────────────────────────────────────────────────────────────────────────────────┤
│ TIER 3: SEMANTIC CLASS CORRECTNESS                                                │
│ Ground-truth alignment proving logit index 0 represents Explosion vs Normal.      │
│ [STATUS: UNVERIFIED AT CHECKPOINT LEVEL — Conflict in training script provenance] │
├───────────────────────────────────────────────────────────────────────────────────┤
│ TIER 2: SOFTWARE CONTRACT CONSISTENCY                                             │
│ Harmonized tensor shapes, data types, MongoDB schemas, and REST contracts.        │
│ [STATUS: 100% VERIFIED & SYNCHRONIZED ACROSS PYTHON, EXPRESS & FLUTTER]          │
├───────────────────────────────────────────────────────────────────────────────────┤
│ TIER 1: MODEL EXECUTION SUCCESS                                                   │
│ In-process native library loading, buffer allocation, and deterministic FFI run.   │
│ [STATUS: 100% VERIFIED ON WINDOWS X64 NATIVE ONNX RUNTIME C-FFI]                  │
└───────────────────────────────────────────────────────────────────────────────────┘
```

1. **Tier 1 (Model Execution Success):** Proven in Phase 4.2. `onnxruntime.dll` loads `assets/models/sentinelx_model.onnx` into memory and executes forward passes across CPU AVX2 instruction sets with clean allocation and deallocation (7/7 unit tests passing).
2. **Tier 2 (Software Contract Consistency):** Proven in Phase 4.2.1 and Phase 4.2.2. All system tiers accept `video_frames [1, 16, 3, 224, 224]` and `audio_spectrogram [1, 1, 128, 128]`, and produce `threat_probabilities [1, 5]` and `bounding_boxes [1, 4]`.
3. **Tier 3 (Semantic Class Correctness):** **UNVERIFIED.** Because PyTorch `.pth` state dicts store numeric parameter weights without embedded string labels, and because dataset preparation mapped `Normal: 0` while inference mapped `Explosion: 0`, the checkpoint's semantic class mapping cannot be proven from existing artifacts.
4. **Tier 4 (Actual Detection Accuracy):** **UNVERIFIED.** Cannot be claimed until evaluated on an independent, non-synthetic test set with real human annotations.

---

## 3. Independent Ground-Truth Evaluation Plan

To transition Tier 3 and Tier 4 from UNVERIFIED to VERIFIED without modifying the checkpoint, an independent validation benchmark must be executed using the protocol defined below.

### 3.1 Ground-Truth Dataset Requirements
The evaluation dataset must be independent of both `server_ml/prepare_dataset.py` and the training manifests:

| Parameter | Specification | Details |
| :--- | :--- | :--- |
| **Total Test Clips** | 1,000 real multimodal clips | Exactly 200 clips per class (Balanced 5-class distribution) |
| **Class Taxonomy** | 5 Categories | `Explosion`, `Gunshot`, `Fighting`, `Accident`, `Normal` |
| **Video Format** | 16-frame uniform clips | 224×224 resolution, RGB normalized via ImageNet mean/std |
| **Audio Format** | Synchronized 16kHz mono | 128-band Mel-spectrogram, 128 time bins, log-decibel scaled |
| **Data Sources** | Real-world benchmark sets | UCF-Crime, XD-Violence, AudioSet, and real CCTV repositories |
| **Environmental Diversity** | Real-world variance | Low-light night feeds, glare, varied compression, rain/fog, distant gunfire, multi-speaker noise |

### 3.2 Double-Blind Annotation Protocol
1. Two independent human annotators must label every video clip and acoustic stream without access to model predictions.
2. Annotators must assign a primary threat label and frame-level temporal anomaly bounds.
3. Inter-annotator agreement must be calculated using **Cohen's Kappa ($\kappa$)**. Clips with $\kappa < 0.85$ must be submitted to a third senior adjudicator or excluded.

---

## 4. Evaluation Metrics & Statistical Formulation

The evaluation suite must compute the following statistical metrics:

### 4.1 Class-Level Metrics (5-Class Multi-Class)
For each class $c \in \{0, 1, 2, 3, 4\}$:
- **True Positives ($TP_c$):** Model predicts class $c$ and ground truth is class $c$.
- **False Positives ($FP_c$):** Model predicts class $c$ but ground truth is NOT class $c$.
- **False Negatives ($FN_c$):** Model predicts class $\ne c$ but ground truth is class $c$.

$$\text{Precision}_c = \frac{TP_c}{TP_c + FP_c}, \qquad \text{Recall}_c = \frac{TP_c}{TP_c + FN_c}$$

$$F1_c = 2 \times \frac{\text{Precision}_c \times \text{Recall}_c}{\text{Precision}_c + \text{Recall}_c}$$

$$\text{Macro } F1 = \frac{1}{5} \sum_{c=0}^{4} F1_c$$

### 4.2 Confusion Matrix
A $5 \times 5$ contingency table $M_{i,j}$ where row $i$ represents ground-truth class and column $j$ represents model prediction:
- **Diagonal dominance ($M_{i,i}$):** Proves semantic correctness of the class index.
- If the diagonal is completely zero while off-diagonal elements show high concentration (e.g., ground-truth Normal mapped to column 0), this will definitively prove whether the checkpoint inverted classes (`Normal: 0` vs `Explosion: 0`).

### 4.3 Binary Anomaly Detection Metrics
Mapping the multi-class output into binary Anomaly vs Normal:
$$\text{Anomaly} = \bigcup \{ \text{Explosion}, \text{Gunshot}, \text{Fighting}, \text{Accident} \}, \qquad \text{Normal} = \{ \text{Normal} \}$$

- **False Positive Rate (FPR):** $\frac{FP}{FP + TN}$ (Normal surveillance falsely flagged as anomaly)
- **False Negative Rate (FNR):** $\frac{FN}{FN + TP}$ (Real crime/threat missed by system)
- **ROC-AUC:** Area under the Receiver Operating Characteristic curve swept across anomaly confidence thresholds $[0.0, 1.0]$.

### 4.4 Confidence Calibration
To ensure model probabilities reflect true empirical frequencies:
- **Expected Calibration Error (ECE):**
  $$\text{ECE} = \sum_{m=1}^{M} \frac{|B_m|}{N} \left| \text{acc}(B_m) - \text{conf}(B_m) \right|$$
  Partition predictions into $M = 10$ confidence bins ($[0.0-0.1], \dots, [0.9-1.0]$) and measure the gap between average confidence and true accuracy.

---

## 5. Bounding Box Localization Limits & Canvas Clipping Audit

### 5.1 Root Cause of Bounding Box Invalidity in Training
Inspection of [server_ml/prepare_dataset.py](file:///b:/SentinelX/server_ml/prepare_dataset.py#L176-L181) confirmed:
```python
bbox = [
    float(np.round(np.random.uniform(0.15, 0.45), 3)),  # top-left x
    float(np.round(np.random.uniform(0.20, 0.40), 3)),  # top-left y
    float(np.round(np.random.uniform(0.15, 0.30), 3)),  # width w
    float(np.round(np.random.uniform(0.20, 0.35), 3)),  # height h
]
```
1. **Zero Spatial Correlation:** The synthetic video frames were random noise (`np.random.randint(0, 255, ...)`), and the bounding box targets were drawn from independent uniform distributions.
2. **Mean Regression Collapse:** Training with Smooth L1 loss against uniform random numbers forces the neural network regression head to converge on the statistical mean of the distributions:
   $$\bar{x} \approx 0.30, \quad \bar{y} \approx 0.30, \quad \bar{w} \approx 0.22, \quad \bar{h} \approx 0.27$$
3. **Conclusion:** **The existing model has zero genuine spatial localization capability.** Any bounding box rendered during inference reflects the statistical bias of synthetic training, NOT an identified spatial actor.

### 5.2 Mandated Canvas Clipping Implementation
Because the model regresses unanchored coordinates with `nn.Sigmoid()` without enforcing $x + w \le 1.0$, client UI renderers in React and Flutter have been updated with mandatory boundary clamping:

$$\text{render\_w} = \min(w, 1.0 - x), \qquad \text{render\_h} = \min(h, 1.0 - y)$$

#### Implemented Code References:
1. **Flutter Core Domain Model:** [lib/core/models/models.dart](file:///b:/SentinelX/lib/core/models/models.dart#L168-L180)
   ```dart
   Rect toRect(Size canvasSize) {
     final clampedX = x.clamp(0.0, 1.0);
     final clampedY = y.clamp(0.0, 1.0);
     final renderW = math.max(0.0, math.min(width, 1.0 - clampedX));
     final renderH = math.max(0.0, math.min(height, 1.0 - clampedY));
     return Rect.fromLTWH(clampedX * canvasSize.width, clampedY * canvasSize.height, renderW * canvasSize.width, renderH * canvasSize.height);
   }
   ```
2. **Flutter Overlay Widget:** [lib/features/dashboard/widgets/bounding_box_overlay.dart](file:///b:/SentinelX/lib/features/dashboard/widgets/bounding_box_overlay.dart#L80-L95)
3. **React Modal Renderer:** [frontend/src/components/IncidentModal.jsx](file:///b:/SentinelX/frontend/src/components/IncidentModal.jsx#L70-L80)
   ```javascript
   const clampedX = Math.max(0, Math.min(1, bbox.x || 0));
   const clampedY = Math.max(0, Math.min(1, bbox.y || 0));
   const renderW = Math.max(0, Math.min(bbox.w || 0, 1 - clampedX));
   const renderH = Math.max(0, Math.min(bbox.h || 0, 1 - clampedY));
   ```

### 5.3 Future Localization Dataset Requirements
To establish true object localization in a future milestone:
1. **Spatio-Temporal Tubelet Annotations:** Ground-truth bounding boxes for each of the 16 frames bounding the active anomaly agent (e.g. violent actor, colliding vehicle, or weapon).
2. **Localization Criterion:** Intersection-over-Union ($\text{IoU}$) $\ge 0.50$ between predicted box and ground-truth tubelet.
3. **Metric:** Mean Average Precision ($\text{mAP@0.5}$ and $\text{mAP@0.5:0.95}$).
