# SentinelX — Phase 4.2.2: Final Model Contract & Graph Signature Audit

**Audit Date:** 2026-11-22  
**Auditor:** Principal ML Engineer, ONNX Runtime Specialist & Independent QA Auditor  
**Scope:** ONNX Graph Inspection, Tensor Signature Reconciliation, Checkpoint Provenance Audit, Bounding Box Semantics  
**Status:** **AUTHORITATIVE RESOLUTION (CHECKPOINT CLASS SEMANTICS CLASSIFIED AS UNVERIFIED)**

---

## 1. Executive Summary

Phase 4.2.2 was initiated to eliminate lingering contradictions across previous phase reports regarding:
1. **The Actual ONNX Graph Signature:** Resolving conflicting claims between Phase 4.1/4.2 and Phase 4.2.1.
2. **Checkpoint Class Mapping:** Investigating the divergence between training data manifests (`Normal: 0`) and runtime inference taxonomies (`Explosion: 0`).
3. **Bounding Box Semantics:** Rigorously validating the `[x, y, w, h]` coordinate convention, clipping behavior, and canvas overflow boundaries.

**Key Resolutions:**
- **ONNX Graph Signature:** The binary `assets/models/sentinelx_model.onnx` has **never changed** since commit `22d7acbb5da58663148ba8fbbd12cefc96308277`. It possesses exactly **2 inputs** (`video_frames: [batch, 16, 3, 224, 224]`, `audio_spectrogram: [batch, 1, 128, 128]`) and **2 outputs** (`threat_probabilities: [1, 5]`, `bounding_boxes: [1, 4]`). The Phase 4.2.1 references to `[1, 1, 64, 64]` and `anomaly_score` were report-level inaccuracies resulting from conflating intermediate CNN layer shapes with external graph signatures.
- **Checkpoint Ground Truth:** Formally designated as **`UNVERIFIED`**. Training manifests (`train_manifest.json`) and loss masking (`train_h200.py`) mapped `Normal: 0`, whereas runtime modules (`infer.py`, `model.py`, `CrimeLog.js`) map `Explosion: 0`. The `.pth` checkpoint contains 96 parameter tensors without string metadata. Production taxonomy `['Explosion', 'Gunshot', 'Fighting', 'Accident', 'Normal']` is maintained across all active services to preserve system stability.
- **Bounding Box Convention:** Top-left coordinate $(x, y)$ plus dimensions $(w, h)$, normalized in $[0.0, 1.0]$. Activation via `nn.Sigmoid()` guarantees non-negative coordinates, but does not enforce $x + w \le 1.0$ or $y + h \le 1.0$.

---

## 2. Definitive ONNX Graph Signature & Binary Inspection

Empirical inspection of `assets/models/sentinelx_model.onnx` using the ONNX C++ library and ONNX Runtime Python API (`ort.InferenceSession`) established the definitive graph specification.

### 2.1 Cryptographic & Model Header Verification

| Property | Measured Binary Value |
| :--- | :--- |
| **Filesystem Path** | `assets/models/sentinelx_model.onnx` |
| **Exact File Size** | `20,386,197 bytes` (19.44 MB) |
| **SHA-256 Checksum** | `79a7b83881078329ce6a4b5d64655823f94432fd340dd6f882d98adc0747fe1f` |
| **IR Version** | `9` |
| **Opset Import** | `ai.onnx v18` |
| **Producer Name / Version** | `onnx.quantize 0.1.0` |
| **Quantization Format** | Dynamic INT8 (`ConvInteger`, `MatMulInteger`, `DynamicQuantizeLinear`) |
| **Git Commit Provenance** | `22d7acbb5da58663148ba8fbbd12cefc96308277` (Nov 19, 2026) — Single commit; binary has never been replaced or retrained. |

---

### 2.2 Tensor Input & Output Signatures

#### A. Graph Inputs (Session Bindings)
| Input Name | Data Type | Dimensions (ONNX Graph) | Element Count (Batch = 1) | Buffer Size (Bytes) |
| :--- | :---: | :---: | :---: | :---: |
| **`video_frames`** | `Float32` (Type 1) | `['batch_size', 16, 3, 224, 224]` | $1 \times 16 \times 3 \times 224 \times 224 = 2,408,448$ | $9,633,792$ bytes |
| **`audio_spectrogram`** | `Float32` (Type 1) | `['batch_size', 1, 128, 128]` | $1 \times 1 \times 128 \times 128 = 16,384$ | $65,536$ bytes |

#### B. Graph Outputs (Session Bindings)
| Output Name | Data Type | Dimensions | Producing Node | Activation Function |
| :--- | :---: | :---: | :---: | :---: |
| **`threat_probabilities`** | `Float32` (Type 1) | `[1, 5]` | `node_softmax_1` (Op: `Softmax`) | Softmax across 5 classes (sum $= 1.0$) |
| **`bounding_boxes`** | `Float32` (Type 1) | `[1, 4]` | `node_sigmoid` (Op: `Sigmoid`) | Sigmoid bounding each coordinate to $(0.0, 1.0)$ |

---

### 2.3 Cross-Layer Signature Comparison

The table below traces the signature across every layer of the SentinelX codebase:

| System Layer | Source File | Audio Input Shape | Video Input Shape | Output 1 | Output 2 | Output 3 |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: |
| **Actual ONNX Binary** | `assets/models/sentinelx_model.onnx` | `[1, 1, 128, 128]` | `[1, 16, 3, 224, 224]` | `threat_probabilities` `[1, 5]` | `bounding_boxes` `[1, 4]` | *None* |
| **PyTorch Architecture** | [model.py](file:///b:/SentinelX/server_ml/model.py#L225-L245) | `[B, 1, 128, 128]` | `[B, 16, 3, 224, 224]` | `logits` `[B, 5]` | `bbox` `[B, 4]` | *None* |
| **ONNX Export Script** | [export_onnx.py](file:///b:/SentinelX/server_ml/export_onnx.py#L45-L82) | `[1, 1, 128, 128]` | `[1, 16, 3, 224, 224]` | `threat_probabilities` `[1, 5]` | `bounding_boxes` `[1, 4]` | *None* |
| **Python Preprocessor** | [preprocessor.py](file:///b:/SentinelX/server_ml/preprocessor.py#L1-L15) | `[1, 1, 128, 128]` | `[1, 16, 3, 224, 224]` | N/A (Inputs only) | N/A (Inputs only) | N/A |
| **Python Inference API** | [infer.py](file:///b:/SentinelX/server_ml/infer.py#L90-L135) | `[1, 1, 128, 128]` | `[1, 16, 3, 224, 224]` | `logits` `[1, 5]` | `bbox` `[1, 4]` | *None* |
| **Flutter Native FFI** | [onnx_native_bridge.dart](file:///b:/SentinelX/lib/services/onnx_native_bridge.dart#L190-L215) | `[1, 1, 128, 128]` | `[1, 16, 3, 224, 224]` | `threat_probabilities` `[1, 5]` | `bounding_boxes` `[1, 4]` | *None* |
| **Flutter FFI Unit Test** | [onnx_native_execution_test.dart](file:///b:/SentinelX/test/unit/onnx_native_execution_test.dart#L50-L75) | `[1, 1, 128, 128]` | `[1, 16, 3, 224, 224]` | `threat_probabilities` `[1, 5]` | `bounding_boxes` `[1, 4]` | *None* |

### 2.4 Root Cause of the Phase 4.2.1 Inaccuracy
- **Why `[1, 1, 64, 64]` appeared:** In [model.py](file:///b:/SentinelX/server_ml/model.py#L120), the first 2D convolution in the audio backbone downsamples the `[B, 1, 128, 128]` input with `stride=2` to an internal feature map of `[B, 64, 64, 64]`. The Phase 4.2.1 auditor mistook this intermediate feature representation for the external model input shape.
- **Why `anomaly_score` appeared:** Early conceptual designs proposed an explicit scalar anomaly score head. However, [model.py](file:///b:/SentinelX/server_ml/model.py#L225) and [export_onnx.py](file:///b:/SentinelX/server_ml/export_onnx.py#L45) construct only two heads (`classifier` and `bbox_regressor`). In Python inference ([infer.py](file:///b:/SentinelX/server_ml/infer.py#L110)), the "anomaly score" is computed downstream from the classification probabilities (`confidence` of the non-Normal class), NOT by a dedicated neural network head.

---

## 3. Checkpoint Class Mapping & Provenance Investigation

### 3.1 Empirical Investigation of Training Artifacts
Inspection of the dataset preparation pipeline and training manifests revealed the following ground-truth evidence:

1. **Manifest File Inspection:**  
   In [data/manifests/train_manifest.json](file:///b:/SentinelX/data/manifests/train_manifest.json) and [data/manifests/val_manifest.json](file:///b:/SentinelX/data/manifests/val_manifest.json):
   ```json
   {"sample_id": "sample_0000", "threat_label": "Normal", "class_id": 0, "bbox": [0.0, 0.0, 0.0, 0.0]}
   {"sample_id": "sample_0008", "threat_label": "Explosion", "class_id": 3, "bbox": [0.163, 0.235, 0.152, 0.201]}
   ```
   Class frequency distribution in the generated manifests:
   - Index 0: `Normal`
   - Index 1: `Fighting`
   - Index 2: `Gunshot`
   - Index 3: `Explosion`
   - Index 4: `Accident`

2. **Dataset Preprocessor:**  
   In [prepare_dataset.py](file:///b:/SentinelX/server_ml/prepare_dataset.py#L27-L33):
   ```python
   THREAT_CLASSES = {"Normal": 0, "Fighting": 1, "Gunshot": 2, "Explosion": 3, "Accident": 4}
   ```

3. **Loss Function Construction:**  
   In [train_h200.py](file:///b:/SentinelX/server_ml/train_h200.py#L57-L61):
   ```python
   # Compute bbox loss only on anomaly samples (class != 0)
   anomaly_mask = target_labels > 0
   ```
   This confirms that the training script explicitly assumed class index `0` was `Normal`, applying bounding-box regression loss strictly when `target_labels > 0`.

4. **Inference Mapping Contradiction:**  
   In [infer.py](file:///b:/SentinelX/server_ml/infer.py#L23-L29), [model.py](file:///b:/SentinelX/server_ml/model.py#L8), and [CrimeLog.js](file:///b:/SentinelX/backend/src/models/CrimeLog.js#L38-L44):
   ```python
   THREAT_CLASSES = ["Explosion", "Gunshot", "Fighting", "Accident", "Normal"]
   ```
   Here, index 0 is mapped to `Explosion`, and index 4 is mapped to `Normal`.

5. **Checkpoint Provenance:**  
   - Checkpoint: `server_ml/models/sentinelx_model.pth` (71,045,939 bytes, SHA-256: `ea7774e69f7485ab602165363b093c2c165f8f47ce7848eab26fc786d3cc7d69`).
   - Binary format: PyTorch `OrderedDict` containing 96 parameter tensors.
   - Tensor metadata: No string labels, class names, or training configuration dictionaries are embedded within the file.
   - Checkpoint was committed in git commit `22d7acbb5da58663148ba8fbbd12cefc96308277` with message `"Added initial developed project files"`. No training log files (`training_history.json`) or epoch loss curves exist in the repository.

### 3.2 Formal Ground-Truth Classification
Because:
1. `prepare_dataset.py` generates training manifests with `Normal = 0`,
2. `train_h200.py` masks loss assuming `Normal = 0`,
3. But all operational runtime inference code (`infer.py`, `CrimeLog.js`, `onnx_native_bridge.dart`) maps index 0 to `Explosion` and index 4 to `Normal`,
4. And the checkpoint contains no embedded string labels to prove which dataset or mapping was active when its weights converged,

**The checkpoint's semantic class predictions are formally classified as `UNVERIFIED`.**  
In accordance with strict change restrictions, the production taxonomy `['Explosion', 'Gunshot', 'Fighting', 'Accident', 'Normal']` is maintained across Python, Express, MongoDB, and Flutter to guarantee contract consistency and prevent system runtime failures, but no claim of verified semantic accuracy can be made for checkpoint class predictions.

---

## 4. Bounding Box Output Semantics & Canvas Overflow Audit

### 4.1 Annotation Generation & Target Encoding
Inspection of [prepare_dataset.py](file:///b:/SentinelX/server_ml/prepare_dataset.py#L173-L181) reveals how ground-truth bounding box targets were constructed:
```python
if threat_label == "Normal":
    bbox = [0.0, 0.0, 0.0, 0.0]
else:
    bbox = [
        float(np.round(np.random.uniform(0.15, 0.45), 3)),  # top-left x
        float(np.round(np.random.uniform(0.20, 0.40), 3)),  # top-left y
        float(np.round(np.random.uniform(0.15, 0.30), 3)),  # width w
        float(np.round(np.random.uniform(0.20, 0.35), 3)),  # height h
    ]
```

### 4.2 Coordinate Convention Validation
- **Semantics:** Bounding boxes represent **top-left corner coordinates $(x, y)$ plus box dimensions $(w, h)$**.
- **Not Center Coordinates:** The bounding box is NOT center-based $(cx, cy, w, h)$ because $x$ and $y$ are constrained to $[0.15, 0.45]$, and Normal explicitly zeros all four values.
- **Not Corner Coordinates:** The bounding box is NOT Pascal VOC format $(x_1, y_1, x_2, y_2)$ because the third and fourth elements are independently sampled positive widths and heights ($w \in [0.15, 0.30]$, $h \in [0.20, 0.35]$).

### 4.3 Clipping & Canvas Overflow Boundary Analysis
1. **Model Output Activation:**  
   In [model.py](file:///b:/SentinelX/server_ml/model.py#L220), `self.bbox_regressor` ends with `nn.Sigmoid()`. This mathematical operation guarantees:
   $$\forall i \in \{0, 1, 2, 3\}: \quad 0.0 < \text{bbox}[i] < 1.0$$
2. **Python Inference Clipping:**  
   In [infer.py](file:///b:/SentinelX/server_ml/infer.py#L122):
   ```python
   bbox_coords = [round(float(np.clip(v, 0.0, 1.0)), 4) for v in bbox[0].cpu().numpy()]
   ```
   Each scalar coordinate is clipped to $[0.0, 1.0]$.
3. **CRITICAL ARCHITECTURAL FINDING (Canvas Overflow):**  
   While each scalar $x, y, w, h$ is independently bounded in $[0.0, 1.0]$, **there is no architectural or loss constraint enforcing $x + w \le 1.0$ or $y + h \le 1.0$**.
   - If the network predicts $x = 0.85$ and $w = 0.40$, the bottom-right corner $x + w = 1.25$ exceeds the normalized video frame canvas boundary.
   - The bounding box regressor does NOT employ spatial anchor boxes (YOLO/SSD) or generalized IoU loss; it is an unanchored regression layer trained via Smooth L1 loss.
   - **Conclusion:** Visual correctness cannot be claimed simply because raw numbers fall in $[0, 1]$. Canvas renderers (in React and Flutter) must perform explicit viewport boundary clipping:
     $$\text{render\_w} = \min(w, 1.0 - x), \quad \text{render\_h} = \min(h, 1.0 - y)$$

---

## 5. Summary of Audit Conclusions

| Item | Phase 4.2.1 Claim | Phase 4.2.2 Authoritative Resolution | Status |
| :--- | :--- | :--- | :---: |
| **Audio Input** | `[1, 1, 64, 64]` | **`[1, 1, 128, 128]`** (128-band Mel-spectrogram) | **RESOLVED** |
| **Video Input** | `[1, 16, 3, 224, 224]` | **`[1, 16, 3, 224, 224]`** (16 RGB frames) | **VERIFIED** |
| **Model Outputs** | `anomaly_score`, `threat_probs`, `bboxes` | **`threat_probabilities` `[1, 5]`, `bounding_boxes` `[1, 4]`** | **RESOLVED** |
| **Output Activations** | Softmax & Sigmoid | `node_softmax_1` (Softmax) & `node_sigmoid` (Sigmoid) | **VERIFIED** |
| **Class Mapping** | Harmonized across stack | **UNVERIFIED AT CHECKPOINT LEVEL** (Production taxonomy frozen) | **CLASSIFIED** |
| **Bbox Semantics** | `[x, y, w, h]` normalized | **Top-left $(x, y)$ + dimensions $(w, h)$**; Canvas overflow unconstrained | **VERIFIED** |
