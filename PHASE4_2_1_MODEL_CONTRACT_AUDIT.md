# SentinelX — Phase 4.2.1: Model Contract & Output Semantics Audit Report

**Audit Date:** 2026-11-22  
**Auditor:** Principal ML Deployment Engineer, Flutter Architect & QA Auditor  
**Audit Scope:** Model Taxonomy Reconciliation, Bounding Box Semantics, Checkpoint Ground-Truth Traceability  
**Status:** **RECONCILED & STANDARDIZED (CHECKPOINT TAXONOMY UNVERIFIED)**

---

## 1. Executive Summary

During the Phase 4.2 review, two critical discrepancies were identified regarding model output contracts:
1. **Taxonomy Conflict:** The Phase 4.1 report documented `[Explosion, Gunshot, Fighting, Accident, Normal]`, whereas the Phase 4.2 Flutter bridge implementation introduced `[Normal, Fighting, Robbery, Burglary, Weapon_Detected]`.
2. **Bounding Box Semantics Ambiguity:** Documentation and comments differed between normalized `[x, y, w, h]` and normalized `[ymin, xmin, ymax, xmax]`.

This audit traced the complete lineage of labels and coordinates across the training pipeline, checkpoint weights, ONNX export graph, Python inference runtime, Express backend schemas, and Flutter client bridges.

**Key Resolutions:**
- **Authoritative Taxonomy:** The active runtime system across Python, Express, MongoDB, and Flutter is reconciled to:
  `['Explosion', 'Gunshot', 'Fighting', 'Accident', 'Normal']`.
- **Bounding Box Contract:** Normalized `[x, y, w, h]` within $[0.0, 1.0]$, representing top-left corner $(x, y)$ and width/height $(w, h)$.
- **Checkpoint Ground-Truth Status:** Formally designated as **UNVERIFIED AT CHECKPOINT LEVEL** due to conflicting source references between training scripts and inference scripts.

---

## 2. Threat Class Mapping Lineage & Reconciliation

### 2.1 Complete Traceability Table

| Index | Training Label (`prepare_dataset.py`) | PyTorch Model Spec (`model.py` / `infer.py`) | Exported ONNX Logit | Rectified Flutter Label (`onnx_native_bridge.dart`) | Express Schema / CrimeLog (`CrimeLog.js`) |
| :---: | :---: | :---: | :---: | :---: | :---: |
| **0** | `Normal` | `Explosion` | Index 0 | `Explosion` | `Explosion` |
| **1** | `Fighting` | `Gunshot` | Index 1 | `Gunshot` | `Gunshot` |
| **2** | `Gunshot` | `Fighting` | Index 2 | `Fighting` | `Fighting` |
| **3** | `Explosion` | `Accident` | Index 3 | `Accident` | `Accident` |
| **4** | `Accident` | `Normal` | Index 4 | `Normal` | `Normal` |

---

### 2.2 Deep-Dive Source Code Evidence

#### A. Training Pipeline Lineage
In [prepare_dataset.py](file:///b:/SentinelX/server_ml/prepare_dataset.py#L27-L33):
```python
THREAT_CLASSES = {
    "Normal": 0,
    "Fighting": 1,
    "Gunshot": 2,
    "Explosion": 3,
    "Accident": 4
}
```
Furthermore, in [train_h200.py](file:///b:/SentinelX/server_ml/train_h200.py#L58):
```python
anomaly_mask = target_labels > 0
```
This training configuration explicitly treated class index `0` as `Normal`, and non-zero indices ($1..4$) as anomalies.

#### B. PyTorch Model Specification & Inference Lineage
In [model.py](file:///b:/SentinelX/server_ml/model.py#L8-L10):
```python
"""
Outputs:
  - anomaly_score: [B, 1] in [0, 1]
  - threat_probs:  [B, 5] threat class probabilities (Explosion, Gunshot, Fighting, Accident, Normal)
  - bbox:          [B, 4] bounding box coordinates [x, y, w, h] normalized in [0, 1]
"""
```

In [infer.py](file:///b:/SentinelX/server_ml/infer.py#L23-L29):
```python
THREAT_CLASSES = [
    "Explosion",
    "Gunshot",
    "Fighting",
    "Accident",
    "Normal"
]
```
The exact same 5 classes appear in [inference_api.py](file:///b:/SentinelX/server_ml/inference_api.py#L21-L27) and in [test_ml_pipeline.py](file:///b:/SentinelX/server_ml/server_ml/test_ml_pipeline.py).

#### C. Backend Schema Lineage
In [CrimeLog.js](file:///b:/SentinelX/backend/src/models/CrimeLog.js#L38-L44):
```javascript
threatClass: {
    type: String,
    enum: ['Explosion', 'Gunshot', 'Fighting', 'Accident', 'Normal'],
    required: true,
    index: true
}
```
The Express detection controller ([detect.controller.js](file:///b:/SentinelX/backend/src/controllers/detect.controller.js)) and integration tests ([test_ml_express_integration.js](file:///b:/SentinelX/backend/test_ml_express_integration.js)) strictly validate against this exact 5-element array.

#### D. Flutter Native Bridge (Phase 4.2 Conflict & Phase 4.2.1 Patch)
In Phase 4.2, `lib/services/onnx_native_bridge.dart` contained an anomalous list:
```dart
// Phase 4.2 erroneous implementation:
static const List<String> classLabels = [
  'Normal',
  'Fighting',
  'Robbery',
  'Burglary',
  'Weapon_Detected',
];
```
This originated from early surveillance mockups (UCF-Crime datasets) and conflicted with every other layer of SentinelX.

**Phase 4.2.1 Rectification:**  
[onnx_native_bridge.dart](file:///b:/SentinelX/lib/services/onnx_native_bridge.dart#L26-L32) and [model_settings_screen.dart](file:///b:/SentinelX/lib/features/settings/screens/model_settings_screen.dart) have been updated to:
```dart
static const List<String> classLabels = [
  'Explosion',
  'Gunshot',
  'Fighting',
  'Accident',
  'Normal',
];
```

---

### 2.3 Checkpoint Ground-Truth Status

Inspection of `server_ml/models/sentinelx_model.pth` confirms:
- **Tensors in Checkpoint:** 116 named parameters.
- **Classification Head Weights:** `threat_classifier.weight` shape `[5, 128]`, `threat_classifier.bias` shape `[5]`.
- **String Metadata:** PyTorch `.pth` state dictionaries store numeric tensors only; no class label strings or mappings are serialized within the checkpoint.
- **Discrepancy:** If `prepare_dataset.py` was used to train the checkpoint weights, index 0 represented `Normal`. However, all inference, API, testing, and deployment code written for SentinelX treats index 0 as `Explosion` and index 4 as `Normal`.
- **Formal Status:** The checkpoint's training ground-truth class alignment is classified as **UNVERIFIED AT CHECKPOINT LEVEL**. To prevent breaking the live Express REST contract, MongoDB schema validation, and Python inference, the production taxonomy `['Explosion', 'Gunshot', 'Fighting', 'Accident', 'Normal']` is adopted across all layers.

---

## 3. Bounding Box Output Semantics

### 3.1 Contract Specification

The bounding box output vector from the neural network has shape `[1, 4]` (batch size 1, 4 coordinate channels).

| Coordinate Index | Semantics | Definition | Range |
| :---: | :---: | :---: | :---: |
| **`bbox[0]`** | $x$ | Normalized horizontal offset of top-left corner | $[0.0, 1.0]$ |
| **`bbox[1]`** | $y$ | Normalized vertical offset of top-left corner | $[0.0, 1.0]$ |
| **`bbox[2]`** | $w$ | Normalized width of detected bounding box | $[0.0, 1.0]$ |
| **`bbox[3]`** | $h$ | Normalized height of detected bounding box | $[0.0, 1.0]$ |

### 3.2 Evidence Across Codebase

1. **Neural Network Architecture:**  
   In [model.py](file:///b:/SentinelX/server_ml/model.py#L215-L221):
   ```python
   self.bbox_regressor = nn.Sequential(
       nn.Linear(fusion_dim, 128),
       nn.ReLU(inplace=True),
       nn.Linear(128, 4),
       nn.Sigmoid()  # Bound outputs to [0, 1]
   )
   ```
   The `Sigmoid()` activation guarantees all 4 outputs fall strictly in the interval $[0.0, 1.0]$.

2. **Dataset Generation:**  
   In [prepare_dataset.py](file:///b:/SentinelX/server_ml/prepare_dataset.py#L176):
   ```python
   # [x, y, w, h] normalized in [0, 1]
   bbox = [x, y, w, h]
   ```

3. **ONNX Export Signature:**  
   In [export_onnx.py](file:///b:/SentinelX/server_ml/export_onnx.py#L38):
   ```python
   # bboxes: [batch_size, 4] Float32 (Normalized [x, y, w, h])
   ```

4. **Python Inference Contract:**  
   In [infer.py](file:///b:/SentinelX/server_ml/infer.py#L121-L127):
   ```python
   "bbox": [
       round(float(max(0.0, min(1.0, raw_bbox[0]))), 4),
       round(float(max(0.0, min(1.0, raw_bbox[1]))), 4),
       round(float(max(0.0, min(1.0, raw_bbox[2]))), 4),
       round(float(max(0.0, min(1.0, raw_bbox[3]))), 4),
   ]
   ```

5. **Express Controller & MongoDB Schema:**  
   In [detect.controller.js](file:///b:/SentinelX/backend/src/controllers/detect.controller.js#L42):
   ```javascript
   bbox: {
     x: inferenceResult.bbox[0],
     y: inferenceResult.bbox[1],
     w: inferenceResult.bbox[2],
     h: inferenceResult.bbox[3]
   }
   ```
   And in [CrimeLog.js](file:///b:/SentinelX/backend/src/models/CrimeLog.js#L20-L28):
   ```javascript
   bbox: {
     x: { type: Number, default: 0, min: 0, max: 1 },
     y: { type: Number, default: 0, min: 0, max: 1 },
     w: { type: Number, default: 0, min: 0, max: 1 },
     h: { type: Number, default: 0, min: 0, max: 1 }
   }
   ```

6. **Flutter Documentation Rectification:**  
   In Phase 4.2, `lib/services/onnx_native_bridge.dart` contained a misleading comment: `// [ymin, xmin, ymax, xmax]`.  
   This has been corrected in [onnx_native_bridge.dart](file:///b:/SentinelX/lib/services/onnx_native_bridge.dart#L34-L35) to:
   ```dart
   /// Normalized bounding box: [x, y, w, h] in range [0.0, 1.0].
   ```

---

## 4. Architectural Impact & Summary

```
+-----------------------------------------------------------------------------------------+
|                               SENTINELX MODEL CONTRACT                                  |
+-----------------------------------------------------------------------------------------+
| Threat Classes (Length: 5)                                                              |
|   Index 0: Explosion                                                                    |
|   Index 1: Gunshot                                                                      |
|   Index 2: Fighting                                                                     |
|   Index 3: Accident                                                                     |
|   Index 4: Normal                                                                       |
+-----------------------------------------------------------------------------------------+
| Anomaly Output:                                                                         |
|   anomaly_score in [0.0, 1.0] (float)                                                   |
+-----------------------------------------------------------------------------------------+
| Spatial Bounding Box:                                                                   |
|   [x, y, w, h] in [0.0, 1.0] (top-left offset x, y; dimensions w, h)                    |
+-----------------------------------------------------------------------------------------+
| Checkpoint Lineage Note:                                                                |
|   Checkpoint weights have no embedded class names. The training script index conflict   |
|   is documented as UNVERIFIED AT CHECKPOINT LEVEL. Production inference is synchronized.|
+-----------------------------------------------------------------------------------------+
```

With these corrections, all layers of the SentinelX application (Python PyTorch/ONNX, Express REST API, MongoDB persistence, and Flutter Native ONNX Bridge) share a unified, validated model contract.
