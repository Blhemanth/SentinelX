# build_master_guide.py - Generates SentinelX_Project_Master_Guide.html
import os
import sys

# Ensure local dir is on sys.path
sys.path.insert(0, os.path.dirname(__file__))
from pdf_styles import wrap_html

def generate_master_guide_html():
    content = """
<div class="doc-header">
  <h1>SENTINELX // PROJECT MASTER GUIDE</h1>
  <div class="subtitle">Comprehensive System Architecture, Algorithmic Foundations & Operational Reference</div>
  <div class="meta-grid">
    <div class="meta-item"><strong>Event</strong><span>MERNOVA Competition</span></div>
    <div class="meta-item"><strong>Platform Phase</strong><span>Phase 4.3.5.1 Verified</span></div>
    <div class="meta-item"><strong>Target Architecture</strong><span>MERN + Flutter + ONNX + Python</span></div>
    <div class="meta-item"><strong>Verification Status</strong><span>238/238 Tests Passing (100%)</span></div>
  </div>
</div>

<div class="section-toc">
  <strong>TABLE OF CONTENTS:</strong>
  <ol>
    <li>Executive Summary & Mission Overview</li>
    <li>Problem Statement, Industry Blind Spots & Motivation</li>
    <li>Proposed Solution & Architectural Innovations</li>
    <li>Full-Stack System Architecture & Technology Stack</li>
    <li>Edge ONNX Runtime Engine & Background Isolate Architecture</li>
    <li>Temporal Video Ingestion Pipeline & Tensor Mechanics</li>
    <li>Dual-Token Authentication, Session Whitelisting & RBAC</li>
    <li>Internal Service Cryptography & HMAC Trust Boundaries</li>
    <li>Incident Lifecycle & Cross-Client Real-Time Synchronization</li>
    <li>Empirical Benchmarks & Reconciled Hardware Performance</li>
    <li>Authoritative Feature Evidence Matrix (5-Tier Status)</li>
    <li>Current Limitations, Technical Debt & Roadmap to Phase 4.4</li>
    <li>Practical Deployments, Commercial Viability & Public Impact</li>
  </ol>
</div>

<!-- ========================================================================= -->
<h2>1. Executive Summary & Mission Overview</h2>

<p>
<strong>SentinelX</strong> is an edge-to-cloud automated threat detection, incident triage, and emergency dispatch synchronization platform. Designed for modern high-density public infrastructure—including transit terminals, commercial facilities, campuses, and municipal venues—SentinelX combines high-performance edge machine learning with enterprise emergency coordination workflows.
</p>

<div class="dual-container">
  <div class="perspective-card card-beginner">
    <h4>💡 In Plain English (Beginner Friendly)</h4>
    <p>
      Traditional security guards are overwhelmed by watching dozens of video monitors simultaneously, often missing dangerous events like fights or accidents until it is too late. SentinelX acts like an intelligent co-pilot for security operators. It directly reads the camera feed, uses artificial intelligence to instantly spot emergencies, highlights them on a dashboard, and automatically coordinates with emergency dispatchers—all while ensuring security operators make the final decisions.
    </p>
  </div>
  <div class="perspective-card card-technical">
    <h4>⚙️ Technical Engineering Architecture</h4>
    <p>
      SentinelX implements a decentralized hybrid surveillance topology. Native client nodes (Flutter Desktop x64) execute low-latency local inference via Microsoft ONNX Runtime C-FFI within an isolated background Dart isolate. Temporal video tensors [1, 16, 3, 224, 224] are evaluated against an embedded neural network (SentinelXNet), streaming authorized threat telemetry to a hardened Node.js Express backend and MongoDB cluster. The Emergency Operations Center (EOC) web client (React 19 + Vite) synchronizes incident progression in real time.
    </p>
  </div>
</div>

<!-- ========================================================================= -->
<h2>2. Problem Statement, Industry Blind Spots & Motivation</h2>

<p>
Surveillance infrastructure globally suffers from structural failure modes that compromise physical security:
</p>

<ul>
  <li><strong>Surveillance Fatigue & Human Error:</strong> Psychological studies demonstrate that human video monitors miss over 90% of critical anomaly events after just 20 minutes of continuous monitoring due to cognitive saturation.</li>
  <li><strong>Excessive Detection-to-Dispatch Latency:</strong> In conventional monitoring setups, an anomaly takes between 4 to 12 minutes to be visually noticed, manually verified, and telephonically reported to emergency responders.</li>
  <li><strong>Cloud Bandwidth Costs & Privacy Vulnerability:</strong> Continuous streaming of uncompressed 4K/1080p RTSP camera streams to centralized cloud servers requires massive network bandwidth (exceeding 15 Mbps per camera) and introduces severe regulatory and privacy risks under GDPR and CCPA.</li>
  <li><strong>Siloed Emergency Operations:</strong> Disconnected point solutions force security desks to transcribe coordinates and alerts manually into Computer Aided Dispatch (CAD) systems, increasing human latency.</li>
</ul>

<div class="callout callout-info">
  <strong>The SentinelX Objective:</strong> Eliminate video surveillance latency and operator cognitive overload by evaluating temporal video tensors directly at the edge, transmitting structured incident metadata only when threats exceed strict thresholds, and providing sub-second cross-client operational synchronization.
</div>

<!-- ========================================================================= -->
<div class="page-break"></div>
<h2>3. Proposed Solution & Architectural Innovations</h2>

<p>
SentinelX addresses these challenges through five foundational architectural innovations:
</p>

<ol>
  <li><strong>Decentralized Hybrid Edge-Cloud Inference:</strong> Raw video frames never leave the physical facility. Edge devices run local ONNX Runtime inference models natively on host CPU/GPU, transmitting lightweight JSON telemetry packets only upon verified threat detection.</li>
  <li><strong>Asynchronous Dart Isolate Threading:</strong> Deep learning forward passes take ~1.6s on host CPU. By delegating all native C-FFI tensor processing to a dedicated background Dart isolate (<code>OnnxInferenceWorker</code>), the main Flutter UI isolate runs completely unblocked, achieving 97.53% fluid frame presentation with zero UI freezing.</li>
  <li><strong>Bounded Temporal Rolling Buffer:</strong> Rather than processing individual isolated static frames (which cannot distinguish walking from running, or falling from sitting), SentinelX buffers a rolling sequence of exactly 16 frames in memory ($2.30\text{ MB}$ flat footprint), allowing the model to analyze spatio-temporal dynamics.</li>
  <li><strong>Cryptographic Protocol v2 HMAC Trust Boundaries:</strong> Public client requests are untrusted. Distributed Flutter applications possess zero backend secrets. Microservices authenticate using request-bound Protocol v2 HMAC-SHA256 tokens binding HTTP method, normalized path, SHA-256 body digest, nonce, and timestamp.</li>
  <li><strong>Safety-First Automated Triage & Drill Isolation:</strong> Security operator oversight is architecturally enforced. The system enforces strict severity precedence rules, strips untrusted client metadata, and cryptographically isolates drill simulations from ever triggering emergency law enforcement dispatch.</li>
</ol>

<!-- ========================================================================= -->
<h2>4. Full-Stack System Architecture & Technology Stack</h2>

<div class="diagram-box">
+----------------------------------------------------------------------------------------------------+
|                                      SENTINELX CLIENT TIER                                         |
|                                                                                                    |
|    +------------------------------------------+    +------------------------------------------+    |
|    |      Flutter Desktop Client (x64)        |    |       React 19 + Vite Web Client         |    |
|    |  - Real-time DirectShow Camera Stream    |    |  - Real-time Emergency Operations Center |    |
|    |  - Cyberpunk HUD & Bounding Box Overlay  |    |  - Incident Triage, Map & CAD Dispatch   |    |
|    |  - Native ONNX C-FFI Background Worker   |    |  - Role-Based Operational Controls       |    |
|    |  - Riverpod State Architecture           |    |  - Tailwind CSS Responsive Dashboard     |    |
|    +------------------------------------------+    +------------------------------------------+    |
+----------------------------------------------------------------------------------------------------+
                                                  │
                       REST API / JWT Auth (Port 5000)
                                                  ▼
+----------------------------------------------------------------------------------------------------+
|                                    NODE.JS / EXPRESS BACKEND                                       |
|                                                                                                    |
|  - Dual-Token Auth (15-min Access JWT, 7-day HttpOnly Refresh Token, DB Session Revocation)        |
|  - Role-Based Access Control: admin, police, analyst, user                                         |
|  - Rate Limiting (100 req/15min general, 20 req/15min auth) & Concurrency Guards                   |
|  - Protocol v2 HMAC Internal Service Authentication Middleware (Method/Path/BodyDigest/Nonce)      |
|  - Canonical 8/16/24/32-bit Linear PCM Audio Validation & Sanitization Engine                      |
|  - Authoritative Mongoose Pre-Save Severity & Emergency Eligibility Calculation                    |
|  - Subprocess & Microservice ML Bridge (Dual-Strategy Python Invocation)                          |
+----------------------------------------------------------------------------------------------------+
                           │                                                │
                 Mongoose / BSON                                 HTTP REST / Stdin Stream
                           ▼                                                ▼
+-----------------------------------+             +--------------------------------------------------+
|      MONGODB DATABASE (v7.0)      |             |              PYTHON ML MICROSERVICE              |
|                                   |             |                                                  |
| - Collections: users, sessions,   |             | - Architecture: SentinelXNet (PyTorch 2.x)       |
|   crimelogs, audits               |             | - Trained Checkpoint: sentinelx_model.pth        |
| - Strict Schema Invariants        |             | - Exported ONNX: sentinelx_model.onnx            |
| - Atomic CAD Dispatch Updates     |             | - FastAPI Microservice & Subprocess Fallback     |
| - Automated Expiration Indexes    |             | - 8/16/24/32-bit Linear PCM Audio Preprocessing  |
+-----------------------------------+             +--------------------------------------------------+
</div>

<!-- ========================================================================= -->
<div class="page-break"></div>
<h2>5. Edge ONNX Runtime Engine & Background Isolate Architecture</h2>

<div class="dual-container">
  <div class="perspective-card card-beginner">
    <h4>💡 In Plain English (Beginner Friendly)</h4>
    <p>
      Running AI directly inside a computer program is heavy work. If you run the AI on the same thread that draws the user interface, the buttons freeze, animations stutter, and the screen locks up for almost 2 seconds every time the AI thinks. SentinelX solves this by creating a dedicated "worker isolate"—a separate invisible process inside the program. The camera hands video frames to this worker, the worker processes the AI in the background, and the user interface stays completely smooth at 60 Hz.
    </p>
  </div>
  <div class="perspective-card card-technical">
    <h4>⚙️ Technical Engineering Architecture</h4>
    <p>
      In Dart's single-threaded event loop, calling <code>OrtSession.run()</code> synchronously blocks the root UI isolate for ~1,680 ms per forward pass. SentinelX implements <code>OnnxInferenceWorker</code> using <code>Isolate.spawn()</code>. The worker isolate loads native C dynamic libraries (<code>onnxruntime.dll</code> v1.32.0) via C-FFI. Input tensors [1, 16, 3, 224, 224] are transferred across an inter-isolate <code>SendPort</code> in 5.0 ms. The UI thread registers zero blocking, maintaining a 97.53% fluid compositor presentation rate.
    </p>
  </div>
</div>

<h3>Native Worker Isolate Concurrency Flow</h3>
<div class="diagram-box">
[ Main UI Isolate ]                                          [ Background OnnxInferenceWorker Isolate ]
         │                                                                   │
  Camera Ingestion Service                                                    │
  - DirectShow captures frame                                                │
  - Ingests into TemporalFrameBuffer                                          │
         │                                                                   │
  ContinuousInferenceScheduler                                                │
  - Checks: is worker currently busy?                                         │
  - NO: Builds Float32List tensor                                            │
  - Packs 9.63 MB video + silence audio                                       │
         │                                                                   │
         │─────── SendPort.send(InferenceRequest) [5.0 ms IPC] ──────────────>│
         │                                                                   │
  (UI Isolate remains 100% UNBLOCKED)                                         │ OrtSession.run() (C-FFI)
  - Flutter engine draws HUD at 60 Hz                                        │ - Multi-threaded CPU AVX2
  - User can click, pan, and triage logs                                     │ - Execution latency: ~1,650 ms
         │                                                                   │ - Produces logits & raw bboxes
         │                                                                   │
         │<────── SendPort.send(InferenceResponse) [0.1 ms] ─────────────────│
         │                                                                   │
  Inference Telemetry Stream updates HUD                                     │
  - Renders bounding box overlay                                              │
  - Emits prediction to DetectionSyncService                                 │
</div>

<!-- ========================================================================= -->
<h2>6. Temporal Video Ingestion Pipeline & Tensor Mechanics</h2>

<p>
Single-frame image recognition cannot capture motion signatures essential for anomaly classification (e.g., distinguishing between an aggressive brawl and a handshake, or an explosion flash versus stage lighting). SentinelX implements spatio-temporal video buffering:
</p>

<ul>
  <li><strong>Physical Camera Ingestion:</strong> Evaluated using the physical <code>HP TrueVision HD Camera</code> via the <code>camera_windows</code> plugin, streaming DirectShow/MediaFoundation frames at ~7.33 FPS.</li>
  <li><strong>High-Performance Skia Resizing:</strong> Raw JPEG bytes are decoded and scaled directly to $224 \times 224$ RGB pixels via Flutter's C++ Skia codec in $4.6\text{ ms}$, bypassing costly Dart heap object allocations.</li>
  <li><strong>16-Frame FIFO Ring Buffer:</strong> Managed by [TemporalFrameBuffer](file:///b:/SentinelX/lib/core/camera/temporal_frame_buffer.dart). The buffer capacity is strictly fixed at 16 frames ($2.30\text{ MB}$ memory ceiling). Earliest frames are padded during the initial 16-frame warm-up period.</li>
  <li><strong>Planar Float32 Normalization:</strong> Converts $16 \times 224 \times 224 \times 3$ uint8 bytes into a contiguous planar Float32List of exactly $2{,}408{,}448\text{ elements}$ ($9.63\text{ MB}$) normalized according to ImageNet standards:
    $$R_{\text{norm}} = \frac{r - 0.485}{0.229}, \quad G_{\text{norm}} = \frac{g - 0.456}{0.224}, \quad B_{\text{norm}} = \frac{b - 0.406}{0.225}$$
  </li>
  <li><strong>Acoustic Silence Baseline:</strong> To fulfill the multimodal input contract of SentinelXNet in Phase 4.3.5.1, the audio input tensor is populated with a synthetic calibrated silence baseline of [1, 1, 128, 128] at $-80.0\text{ dB}$, safely enforcing degraded video-only operation.</li>
</ul>

<!-- ========================================================================= -->
<div class="page-break"></div>
<h2>7. Dual-Token Authentication, Session Whitelisting & RBAC</h2>

<div class="dual-container">
  <div class="perspective-card card-beginner">
    <h4>💡 In Plain English (Beginner Friendly)</h4>
    <p>
      Just like a bank vault requires two separate keys, SentinelX protects user access with two tokens. When an operator logs in, they receive a short-lived "access pass" (lasts only 15 minutes) and a secure "vault key" (lasts 7 days). If an attacker steals the access pass, it becomes useless in minutes. If an operator logs out or is fired, the server immediately revokes their session in the database, blocking all future access instantly.
    </p>
  </div>
  <div class="perspective-card card-technical">
    <h4>⚙️ Technical Engineering Architecture</h4>
    <p>
      Authentication implements an enterprise dual-token JWT lifecycle. Short-lived Access Tokens ($15\text{ minutes}$, signed with HS256) are transmitted via the <code>Authorization: Bearer</code> header. Long-lived Refresh Tokens ($7\text{ days}$) are persisted in MongoDB with active session IDs. Refresh operations enforce strict token rotation: using a refresh token revokes it and issues a fresh pair. Logout immediately deletes the session record, providing instant server-side revocation.
    </p>
  </div>
</div>

<h3>Role-Based Access Control (RBAC) Permissions Matrix</h3>
<table>
  <thead>
    <tr>
      <th>Role</th>
      <th>View Incidents</th>
      <th>Create / Trigger</th>
      <th>CAD Dispatch</th>
      <th>Acknowledge</th>
      <th>Delete Incident</th>
      <th>User Management</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>admin</strong></td>
      <td><span class="badge badge-verified">YES</span></td>
      <td><span class="badge badge-verified">YES</span></td>
      <td><span class="badge badge-verified">YES</span></td>
      <td><span class="badge badge-verified">YES</span></td>
      <td><span class="badge badge-verified">YES</span></td>
      <td><span class="badge badge-verified">YES</span></td>
    </tr>
    <tr>
      <td><strong>police</strong></td>
      <td><span class="badge badge-verified">YES</span></td>
      <td><span class="badge badge-verified">YES</span></td>
      <td><span class="badge badge-verified">YES</span></td>
      <td><span class="badge badge-verified">YES</span></td>
      <td><span class="badge badge-danger">NO (403)</span></td>
      <td><span class="badge badge-danger">NO (403)</span></td>
    </tr>
    <tr>
      <td><strong>analyst</strong></td>
      <td><span class="badge badge-verified">YES</span></td>
      <td><span class="badge badge-verified">YES</span></td>
      <td><span class="badge badge-verified">YES</span></td>
      <td><span class="badge badge-verified">YES</span></td>
      <td><span class="badge badge-danger">NO (403)</span></td>
      <td><span class="badge badge-danger">NO (403)</span></td>
    </tr>
    <tr>
      <td><strong>user / viewer</strong></td>
      <td><span class="badge badge-verified">YES</span></td>
      <td><span class="badge badge-danger">NO (403)</span></td>
      <td><span class="badge badge-danger">NO (403)</span></td>
      <td><span class="badge badge-danger">NO (403)</span></td>
      <td><span class="badge badge-danger">NO (403)</span></td>
      <td><span class="badge badge-danger">NO (403)</span></td>
    </tr>
  </tbody>
</table>

<!-- ========================================================================= -->
<h2>8. Internal Service Cryptography & HMAC Trust Boundaries</h2>

<p>
One of the most critical security findings resolved in Phase 4.3.5.1 is the <strong>absolute isolation of client applications from internal cryptographic secrets</strong>:
</p>

<ul>
  <li><strong>No HMAC Secrets in Distributed Clients:</strong> An internal HMAC secret (<code>INTERNAL_SERVICE_KEY</code>) must NEVER be packaged inside Flutter Windows or Android binaries. Any client decompilation or memory dump would leak the secret.</li>
  <li><strong>Public Requests are Untrusted:</strong> All client requests submitted via <code>POST /api/logs</code> pass through strict server-side sanitization:
    <ol>
      <li><code>req.body.severity</code> is deleted and computed server-side via <code>CrimeLog.calculateSeverity()</code>.</li>
      <li><code>req.body.isEmergencyEligible</code> is stripped and forced to <code>false</code> for all client submissions.</li>
      <li>Client-declared <code>detectionSource: 'ml_real'</code> is demoted to <code>manual_entry</code> and <code>low_confidence_review</code>.</li>
    </ol>
  </li>
  <li><strong>Protocol v2 HMAC Request Binding:</strong> When trusted internal backend services (such as the Python ML microservice or server audio verifier) communicate with Express, requests are authenticated with Protocol v2 HMAC tokens:
    $$\text{Payload} = \texttt{METHOD} : \texttt{PATH} : \texttt{serviceId} : \texttt{timestamp} : \texttt{nonce} : \text{SHA256}(\texttt{Body})$$
    $$\text{Token} = \texttt{v2} . \langle\text{serviceId}\rangle . \langle\text{timestamp}\rangle . \langle\text{nonce}\rangle . \text{HMAC-SHA256}_{\text{key}}(\text{Payload})$$
  </li>
  <li><strong>Timing-Safe Comparison & Replay Cache:</strong> Signatures are evaluated using constant-time comparison (<code>crypto.timingSafeEqual</code>). Nonces are tracked in a sliding memory cache with a 60-second freshness window. Protocol v1 tokens are strictly rejected in production.</li>
</ul>

<!-- ========================================================================= -->
<div class="page-break"></div>
<h2>9. Incident Lifecycle & Cross-Client Real-Time Synchronization</h2>

<p>
Incidents in SentinelX progress through a controlled state machine enforcing human operator accountability:
</p>

<div class="diagram-box">
  [ Camera Stream Ingested ]
              │
              ▼
  [ ONNX Edge Inference ] ────(Below 0.50 Conf or Normal)───> [ Throttled / Suppressed ]
              │ (Confidence >= 0.50 & Anomaly)
              ▼
  [ Cooldown Throttle Guard ] ──(Duplicate threat within 5s)──> [ Throttled ]
              │
              ▼
  [ Incident Ingestion via API ]
  - Sanitized as 'manual_entry' (Flutter client) or 'ml_real' (Verified server backend)
  - Status: 'anomaly_detected' (or 'low_confidence_review')
  - Dispatch Status: 'unassigned'
              │
              ▼
  [ Operator Triage in EOC Web Dashboard ]
  - Operator reviews video clip, confidence score & bounding box
              │
              ├───────────────────────────────────┐
              ▼                                   ▼
      [ Acknowledge Incident ]           [ Reject / False Alarm ]
      - Sets isAcknowledged: true        - Marked resolved without dispatch
              │
              ▼
  [ CAD Dispatch State Progression ]
  - Step 1: PATCH /api/logs/:id/dispatch -> 'assigned_police'
  - Step 2: PATCH /api/logs/:id/dispatch -> 'en_route'
  - Step 3: PATCH /api/logs/:id/dispatch -> 'on_scene'
  - Step 4: PATCH /api/logs/:id/dispatch -> 'resolved'
              │
              ▼
  [ Real-Time Sync to Flutter Desktop ]
  - Status, notes, and badge color update on operator monitor
</div>

<!-- ========================================================================= -->
<h2>10. Empirical Benchmarks & Reconciled Hardware Performance</h2>

<p>
The following metrics represent the independently verified performance baseline established during the 10-minute continuous hardware test in Phase 4.3.5.1 on the physical <code>HP TrueVision HD Camera</code>:
</p>

<table>
  <thead>
    <tr>
      <th>Metric Category</th>
      <th>Empirical Value</th>
      <th>Limit / Benchmark Standard</th>
      <th>Engineering Status</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Sustained Test Duration</strong></td>
      <td>600.01 Seconds (10.0 continuous minutes)</td>
      <td>$\ge 600\text{ seconds}$</td>
      <td><span class="badge badge-verified">VERIFIED</span></td>
    </tr>
    <tr>
      <td><strong>Camera Frames Ingested</strong></td>
      <td>4,399 frames (7.33 FPS sustained)</td>
      <td>Target: 7–10 FPS</td>
      <td><span class="badge badge-verified">VERIFIED</span></td>
    </tr>
    <tr>
      <td><strong>Camera Frame Latency</strong></td>
      <td>31.4 ms (26.8 ms hardware + 4.6 ms Skia decode)</td>
      <td>$< 50\text{ ms}$</td>
      <td><span class="badge badge-verified">VERIFIED</span></td>
    </tr>
    <tr>
      <td><strong>Completed Forward Passes</strong></td>
      <td>229 forward passes completed</td>
      <td>Continuous execution</td>
      <td><span class="badge badge-verified">VERIFIED</span></td>
    </tr>
    <tr>
      <td><strong>Concurrency Skipped Cycles</strong></td>
      <td>4,168 frames safely dropped</td>
      <td>Non-blocking guard active</td>
      <td><span class="badge badge-verified">VERIFIED</span></td>
    </tr>
    <tr>
      <td><strong>Inference Throughput</strong></td>
      <td>0.38 FPS sustained (~1 pass every 2.6s on CPU AVX2)</td>
      <td>Edge anomaly sampling</td>
      <td><span class="badge badge-verified">VERIFIED</span></td>
    </tr>
    <tr>
      <td><strong>Inference Latency Profile</strong></td>
      <td>P50: 1,655 ms | P95: 7,558 ms | Max: 31,106 ms</td>
      <td>CPU AVX2 multi-threaded</td>
      <td><span class="badge badge-verified">VERIFIED</span></td>
    </tr>
    <tr>
      <td><strong>Native C-FFI Latency</strong></td>
      <td>P50: 1,637 ms | P95: 7,535 ms</td>
      <td>Microsoft ONNX Runtime v1.32.0</td>
      <td><span class="badge badge-verified">VERIFIED</span></td>
    </tr>
    <tr>
      <td><strong>Inter-Isolate Transfer Time</strong></td>
      <td>5.0 ms average across SendPort</td>
      <td>$< 10\text{ ms}$</td>
      <td><span class="badge badge-verified">VERIFIED</span></td>
    </tr>
    <tr>
      <td><strong>Rendered GUI Frame Count</strong></td>
      <td>13,355 frames (22.26 FPS aggregate engine)</td>
      <td>Compositor presentation</td>
      <td><span class="badge badge-verified">VERIFIED</span></td>
    </tr>
    <tr>
      <td><strong>Presentation Interval FPS</strong></td>
      <td>7.54 FPS (Dirty-mark presentation: 132.6 ms)</td>
      <td>Matches camera + telemetry</td>
      <td><span class="badge badge-verified">VERIFIED</span></td>
    </tr>
    <tr>
      <td><strong>Compositor Jank Rate (>16.6ms)</strong></td>
      <td>2.47% (330 jank frames out of 13,355)</td>
      <td>$< 5.0\%$ target</td>
      <td><span class="badge badge-verified">97.53% FLUID</span></td>
    </tr>
    <tr>
      <td><strong>Process Memory Stability</strong></td>
      <td>Initial: 224.3 MB | Peak: 873.0 MB | Final: 416.7 MB</td>
      <td>Stable plateau under GC</td>
      <td><span class="badge badge-verified">VERIFIED</span></td>
    </tr>
    <tr>
      <td><strong>25-Cycle Worker Isolate Drift</strong></td>
      <td>-6.79 MB net drift across 25 cycles</td>
      <td>Zero memory leak</td>
      <td><span class="badge badge-verified">VERIFIED</span></td>
    </tr>
  </tbody>
</table>

<!-- ========================================================================= -->
<div class="page-break"></div>
<h2>11. Authoritative Feature Evidence Matrix (5-Tier Status)</h2>

<p>
To ensure absolute integrity during competitive presentation and judicial evaluation, every core system capability is classified under our strict 5-tier evidence taxonomy:
</p>

<table>
  <thead>
    <tr>
      <th>Feature / Subsystem</th>
      <th>Evidence Classification</th>
      <th>Current Implementation State & Verified Capabilities</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Physical Webcam Ingestion</strong></td>
      <td><span class="badge badge-verified">1. Independently Verified</span></td>
      <td>DirectShow/MediaFoundation capture via <code>camera_windows</code>, Skia RGB $224 \times 224$ resizing, monotonic indexing.</td>
    </tr>
    <tr>
      <td><strong>Temporal Frame Buffer</strong></td>
      <td><span class="badge badge-verified">1. Independently Verified</span></td>
      <td>Strictly bounded 16-frame rolling ring buffer ($2.30\text{ MB}$), ImageNet planar Float32 normalization.</td>
    </tr>
    <tr>
      <td><strong>Dart Isolate Background Worker</strong></td>
      <td><span class="badge badge-verified">1. Independently Verified</span></td>
      <td>Offloaded native ONNX C-FFI inference in background isolate (<code>OnnxInferenceWorker</code>), zero UI thread blocking.</td>
    </tr>
    <tr>
      <td><strong>Worker Lifecycle & Stability</strong></td>
      <td><span class="badge badge-verified">1. Independently Verified</span></td>
      <td>25-cycle lifecycle stability ($-6.79\text{ MB}$ drift), 4 failure modes contained with graceful recovery.</td>
    </tr>
    <tr>
      <td><strong>Dual-Token Auth & RBAC</strong></td>
      <td><span class="badge badge-verified">1. Independently Verified</span></td>
      <td>15-min Access JWT, 7-day refresh token rotation, MongoDB session revocation whitelist, 4 distinct roles.</td>
    </tr>
    <tr>
      <td><strong>Protocol v2 Internal HMAC</strong></td>
      <td><span class="badge badge-verified">1. Independently Verified</span></td>
      <td>Request-bound HMAC-SHA256 (method, path, body SHA-256, nonce, timestamp), timing-safe equal, replay cache.</td>
    </tr>
    <tr>
      <td><strong>Public Ingestion Sanitization</strong></td>
      <td><span class="badge badge-verified">1. Independently Verified</span></td>
      <td>Stripping client severity, forcing <code>isEmergencyEligible = false</code>, demoting client sources to <code>manual_entry</code>.</td>
    </tr>
    <tr>
      <td><strong>Drill Police Dispatch Isolation</strong></td>
      <td><span class="badge badge-verified">1. Independently Verified</span></td>
      <td>Drill simulation records strictly blocked from law enforcement CAD dispatch (HTTP 400 rejection).</td>
    </tr>
    <tr>
      <td><strong>Multi-Format PCM Audio Decoding</strong></td>
      <td><span class="badge badge-verified">1. Independently Verified</span></td>
      <td>Validated decoding of 8-bit uint8, 16-bit int16, 24-bit packed int32, and 32-bit int32 linear PCM WAV files.</td>
    </tr>
    <tr>
      <td><strong>Continuous ONNX Forward Pass</strong></td>
      <td><span class="badge badge-conditional">2. Conditionally Verified</span></td>
      <td>Executes on host CPU AVX2. Currently operating in <strong>video-only degraded mode</strong> with $-80.0\text{ dB}$ silence baseline.</td>
    </tr>
    <tr>
      <td><strong>Local MongoDB Database</strong></td>
      <td><span class="badge badge-conditional">2. Conditionally Verified</span></td>
      <td>Local MongoDB 7.0 Community Edition verified (<code>mongodb://127.0.0.1:27017</code>). Cloud Atlas is unverified.</td>
    </tr>
    <tr>
      <td><strong>Tier 3/4 Model Accuracy</strong></td>
      <td><span class="badge badge-unvalidated">3. Unvalidated Accuracy</span></td>
      <td>Model weights execute and output probabilities, but precision/recall on ground-truth benchmark is unvalidated.</td>
    </tr>
    <tr>
      <td><strong>Bounding Box Spatial Localization</strong></td>
      <td><span class="badge badge-unvalidated">3. Unvalidated Accuracy</span></td>
      <td>Sigmoid outputs clamped to `[0, 1]` for canvas rendering, but spatial IoU overlap is empirically unvalidated.</td>
    </tr>
    <tr>
      <td><strong>Live Hardware Microphone Ingestion</strong></td>
      <td><span class="badge badge-planned">4. Planned (Phase 4.4)</span></td>
      <td>Scheduled for Phase 4.4 milestone to capture physical microphone audio and replace silence baseline.</td>
    </tr>
    <tr>
      <td><strong>On-Premise ASR Keyword Spotter</strong></td>
      <td><span class="badge badge-planned">4. Planned (Phase 4.4)</span></td>
      <td>Speech-to-text / acoustic distress detection (e.g. Whisper/Vosk) to authoritatively verify "HELP" distress.</td>
    </tr>
    <tr>
      <td><strong>DirectML GPU Hardware Acceleration</strong></td>
      <td><span class="badge badge-planned">4. Planned (Future)</span></td>
      <td>DirectML provider integration planned for Windows GPU acceleration; currently running on CPU AVX2.</td>
    </tr>
    <tr>
      <td><strong>Real Police 911 CAD Dispatch API</strong></td>
      <td><span class="badge badge-untested">5. Not Implemented</span></td>
      <td>Simulated within software domain only. SentinelX has no live connection to municipal 911/police systems.</td>
    </tr>
    <tr>
      <td><strong>Physical Android ARM64 Hardware</strong></td>
      <td><span class="badge badge-untested">5. Not Tested on Device</span></td>
      <td>Flutter Android code builds, but physical runtime verification has been conducted solely on Windows x64.</td>
    </tr>
  </tbody>
</table>

<!-- ========================================================================= -->
<h2>12. Current Limitations, Technical Debt & Roadmap to Phase 4.4</h2>

<ul>
  <li><strong>Limitation 1: Video-Only Degraded Baseline:</strong> The active model asset requires multimodal input: video tensor `[1, 16, 3, 224, 224]` and audio spectrogram `[1, 1, 128, 128]`. Because hardware microphone ingestion is scheduled for Phase 4.4, the audio input currently receives a synthetic $-80.0\text{ dB}$ silence spectrogram. The UI displays an amber DEGRADED MODE banner to maintain operator transparency.</li>
  <li><strong>Limitation 2: CPU Inference Throughput:</strong> Host CPU AVX2 execution averages $\approx 1.6 - 2.5\text{ seconds}$ per inference pass ($0.38 - 0.58\text{ FPS}$). While completely adequate for anomaly sampling every 2 seconds, it does not provide 30 FPS video evaluation. Upgrading to DirectML GPU acceleration will increase throughput to $>10\text{ FPS}$.</li>
  <li><strong>Limitation 3: Single-Instance Nonce Replay Cache:</strong> Replay attack protection relies on an in-memory sliding nonce cache. While optimal for single-node deployments, horizontal scaling across clustered Express instances requires an external Redis cache.</li>
</ul>

<!-- ========================================================================= -->
<h2>13. Practical Deployments, Commercial Viability & Public Impact</h2>

<p>
SentinelX addresses a global physical security market exceeding \$100 Billion:
</p>

<ul>
  <li><strong>Public Transit Hubs & Airports:</strong> Real-time detection of passenger falls, track intrusions, perimeter breaches, and unattended baggage without cloud streaming costs.</li>
  <li><strong>Educational & Corporate Campuses:</strong> Autonomous rapid detection of perimeter intrusions, violence, and nighttime facility access.</li>
  <li><strong>Industrial & Critical Infrastructure:</strong> Automated monitoring of safety exclusion zones, worker slip-and-fall events, and unauthorized access in hazardous areas.</li>
  <li><strong>Ethical & Privacy Considerations:</strong> SentinelX does NOT perform facial recognition, demographic profiling, or biometric identification. The model classifies objective physical motion dynamics, preserving personal privacy in compliance with global standards.</li>
</ul>
"""
    return wrap_html("SentinelX - Project Master Guide", content)

if __name__ == '__main__':
    html = generate_master_guide_html()
    out_path = os.path.join(os.path.dirname(__file__), "SentinelX_Project_Master_Guide.html")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"Generated {out_path} ({len(html)} bytes)")
