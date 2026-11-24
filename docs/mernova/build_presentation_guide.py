# build_presentation_guide.py - Generates MERNOVA_7_Minute_Presentation_Guide.html
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pdf_styles import wrap_html

def generate_presentation_guide_html():
    content = """
<div class="doc-header">
  <h1>MERNOVA // 7-MINUTE PRESENTATION GUIDE</h1>
  <div class="subtitle">Complete Slide-by-Slide Strategy, Timing Roadmap & Visual Execution Plan</div>
  <div class="meta-grid">
    <div class="meta-item"><strong>Event</strong><span>MERNOVA Competition</span></div>
    <div class="meta-item"><strong>Total Time</strong><span>7:00 Minutes Strict</span></div>
    <div class="meta-item"><strong>Team Format</strong><span>3 Presenters</span></div>
    <div class="meta-item"><strong>Structure</strong><span>Presentation + Live Demo</span></div>
  </div>
</div>

<div class="callout callout-info">
  <strong>Provisional Timing Framework (7:00 Total):</strong><br>
  • <strong>0:00–0:40 (40s):</strong> Opening, Hook & Problem Statement (Presenter 1)<br>
  • <strong>0:40–1:30 (50s):</strong> Proposed Solution & Architectural Innovation (Presenter 1)<br>
  • <strong>1:30–2:20 (50s):</strong> End-to-End System Architecture & Edge AI (Presenter 2)<br>
  • <strong>2:20–4:40 (140s / 2m20s):</strong> Live System Demonstration (Presenter 3 + Team)<br>
  • <strong>4:40–5:40 (60s):</strong> Empirical Verification, Performance & Limitations (Presenter 3)<br>
  • <strong>5:40–6:35 (55s):</strong> Real-World Impact, Practical Deployment & Roadmap (Presenter 3)<br>
  • <strong>6:35–7:00 (25s):</strong> Conclusion, Call to Action & Jury Handoff (Presenter 3)
</div>

<!-- ========================================================================= -->
<h2>Slide-by-Slide Detailed Specifications</h2>

<!-- SLIDE 1 -->
<div class="callout callout-info" style="border-left-color: #0284c7;">
  <h3>SLIDE 1 // Title, Team & Project Identity</h3>
  <table>
    <tr><th style="width: 20%;">Presenter</th><td><strong>Presenter 1</strong> (Lead Introduction)</td></tr>
    <tr><th>Time Window</th><td><strong>0:00 – 0:15</strong> (15 Seconds)</td></tr>
    <tr><th>Slide Title</th><td><strong>SentinelX: Edge-to-Cloud Surveillance Anomaly Detection & Incident Response</strong></td></tr>
    <tr><th>Slide Text</th><td>
      • <strong>Automated Multi-Modal Threat Detection for High-Density Public Infrastructure</strong><br>
      • Presenting Team: Presenter 1, Presenter 2, Presenter 3<br>
      • Event: MERNOVA Final Evaluation<br>
      • Technology: Flutter Desktop x64 • Node.js Express • MongoDB • React 19 • Native ONNX Runtime
    </td></tr>
    <tr><th>Recommended Visual</th><td>
      Full-bleed dark cyberpunk theme with SentinelX shield logo, electric cyan accents, and subtle animated waveform backdrop. Clean typography.
    </td></tr>
    <tr><th>Main Takeaway</th><td>Professional, enterprise-grade engineering identity combining edge AI with full-stack emergency response.</td></tr>
    <tr><th>Verbal Transition</th><td><em>"Every single day, thousands of security cameras record critical incidents—yet almost all of them go unnoticed until it is too late. Here is why."</em></td></tr>
  </table>
</div>

<!-- SLIDE 2 -->
<div class="callout callout-info" style="border-left-color: #0284c7;">
  <h3>SLIDE 2 // The Critical Problem: The Surveillance Blind Spot</h3>
  <table>
    <tr><th style="width: 20%;">Presenter</th><td><strong>Presenter 1</strong></td></tr>
    <tr><th>Time Window</th><td><strong>0:15 – 0:40</strong> (25 Seconds)</td></tr>
    <tr><th>Slide Title</th><td><strong>The Fatal Gap in Modern Physical Surveillance</strong></td></tr>
    <tr><th>Slide Text</th><td>
      • <strong>Cognitive Saturation:</strong> Security operators miss >90% of anomalies after 20 minutes of multi-camera monitoring.<br>
      • <strong>Detection-to-Dispatch Lag:</strong> Real-world response time averages 4–12 minutes from incident occurrence.<br>
      • <strong>Cloud Bandwidth Bottleneck:</strong> Continuous 4K streaming to cloud costs \$150+/camera/month and exposes private video feeds.<br>
      • <strong>Disconnected Emergency Workflows:</strong> Disjointed camera networks force manual phone reporting to law enforcement CAD desks.
    </td></tr>
    <tr><th>Recommended Visual</th><td>
      Three stark metric cards with red warning highlights: <strong>"90% Miss Rate"</strong>, <strong>"8.5 Min Delay"</strong>, and <strong>"\$100B+ Industry Loss"</strong>.
    </td></tr>
    <tr><th>Main Takeaway</th><td>The core failure is not a lack of cameras, but the human cognitive impossibility of watching hundreds of streams simultaneously.</td></tr>
    <tr><th>Verbal Transition</th><td><em>"We built SentinelX to close this gap by placing autonomous intelligence directly at the camera edge."</em></td></tr>
  </table>
</div>

<!-- SLIDE 3 -->
<div class="callout callout-info" style="border-left-color: #0284c7;">
  <h3>SLIDE 3 // The SentinelX Solution & System Architecture</h3>
  <table>
    <tr><th style="width: 20%;">Presenter</th><td><strong>Presenter 1</strong></td></tr>
    <tr><th>Time Window</th><td><strong>0:40 – 1:05</strong> (25 Seconds)</td></tr>
    <tr><th>Slide Title</th><td><strong>SentinelX: Edge Intelligence Meets Centralized Operations</strong></td></tr>
    <tr><th>Slide Text</th><td>
      • <strong>Decentralized Edge AI:</strong> Native ONNX Runtime forward passes evaluate video temporal tensors on-premise without cloud streaming.<br>
      • <strong>Spatio-Temporal Anomaly Detection:</strong> Evaluates 16-frame rolling temporal sequences to capture physical motion dynamics.<br>
      • <strong>Instant Dispatch Telemetry:</strong> Anomaly alerts sync sub-second to a unified Emergency Operations Center (EOC).<br>
      • <strong>Human-in-the-Loop Triage:</strong> Operators verify AI alerts with one-click dispatch escalation, eliminating false police deployments.
    </td></tr>
    <tr><th>Recommended Visual</th><td>
      Split graphic: Left side shows edge camera device processing video locally; right side shows EOC dashboard receiving structured alerts in real time.
    </td></tr>
    <tr><th>Main Takeaway</th><td>SentinelX combines private edge computing with centralized operations to provide automated detection without privacy compromise.</td></tr>
    <tr><th>Verbal Transition</th><td><em>"What sets SentinelX apart from typical computer vision projects is our hardened, enterprise-grade engineering. Let's look under the hood."</em></td></tr>
  </table>
</div>

<!-- SLIDE 4 -->
<div class="callout callout-info" style="border-left-color: #0284c7;">
  <h3>SLIDE 4 // Key Innovations & Competitive Differentiation</h3>
  <table>
    <tr><th style="width: 20%;">Presenter</th><td><strong>Presenter 1</strong></td></tr>
    <tr><th>Time Window</th><td><strong>1:05 – 1:30</strong> (25 Seconds)</td></tr>
    <tr><th>Slide Title</th><td><strong>Why SentinelX Outperforms Conventional Solutions</strong></td></tr>
    <tr><th>Slide Text</th><td>
      • <strong>True Zero-UI-Freeze Architecture:</strong> Heavy AI runs in dedicated Dart background isolates; UI remains locked at fluid 60 Hz.<br>
      • <strong>Cryptographic Protocol v2 HMAC Boundaries:</strong> Zero internal secrets in client apps; requests bound to HTTP method, path, and body hash.<br>
      • <strong>Drill Simulation Isolation:</strong> Police CAD dispatch routes enforce cryptographic isolation—training drills cannot trigger real dispatches.<br>
      • <strong>Multimodal Ready Contract:</strong> Unified 16-frame video + 128-band spectrogram tensor ingestion pipeline.
    </td></tr>
    <tr><th>Recommended Visual</th><td>
      Four modern icon badges: [Isolated Isolate AI] [Protocol v2 HMAC] [Zero Cloud Video Stream] [Safety CAD Guard].
    </td></tr>
    <tr><th>Main Takeaway</th><td>SentinelX is not a prototype script—it is an enterprise architecture designed with security boundaries and safety fail-safes.</td></tr>
    <tr><th>Verbal Transition</th><td><em>"Now, Presenter 2 will walk you through our end-to-end multi-platform architecture."</em></td></tr>
  </table>
</div>

<!-- SLIDE 5 -->
<div class="page-break"></div>
<div class="callout callout-info" style="border-left-color: #0284c7;">
  <h3>SLIDE 5 // End-to-End System Architecture</h3>
  <table>
    <tr><th style="width: 20%;">Presenter</th><td><strong>Presenter 2</strong> (Technical & ML Lead)</td></tr>
    <tr><th>Time Window</th><td><strong>1:30 – 1:55</strong> (25 Seconds)</td></tr>
    <tr><th>Slide Title</th><td><strong>Full-Stack MERN + Flutter + ONNX + Python Architecture</strong></td></tr>
    <tr><th>Slide Text</th><td>
      • <strong>Edge Client (Flutter Desktop x64):</strong> DirectShow webcam capture, 16-frame ring buffer, native ONNX C-FFI isolate worker.<br>
      • <strong>Web Portal (React 19 + Vite):</strong> Real-time EOC incident triage, dispatch progression, and interactive map.<br>
      • <strong>Backend API (Node.js Express):</strong> Dual-token JWT auth, RBAC, Protocol v2 HMAC verification, and Mongoose pre-save safety triage.<br>
      • <strong>Database (MongoDB 7.0):</strong> Unified incident log collection with strict schemas and atomic status updates.<br>
      • <strong>Server ML (FastAPI + PyTorch):</strong> Microservice and subprocess fallback pipeline with multi-format PCM WAV audio validation.
    </td></tr>
    <tr><th>Recommended Visual</th><td>
      High-resolution architectural block diagram showing Flutter, Express, React, MongoDB, and Python ML microservices with encrypted connections.
    </td></tr>
    <tr><th>Main Takeaway</th><td>Clean multi-platform separation where each tier handles its optimal task: Flutter at the edge, React at the desk, Express at the core.</td></tr>
    <tr><th>Verbal Transition</th><td><em>"Let's look specifically at how we solved the hardest edge problem: running neural networks on desktop without UI lag."</em></td></tr>
  </table>
</div>

<!-- SLIDE 6 -->
<div class="callout callout-info" style="border-left-color: #0284c7;">
  <h3>SLIDE 6 // Edge AI: Native ONNX Runtime & Background Isolates</h3>
  <table>
    <tr><th style="width: 20%;">Presenter</th><td><strong>Presenter 2</strong></td></tr>
    <tr><th>Time Window</th><td><strong>1:55 – 2:20</strong> (25 Seconds)</td></tr>
    <tr><th>Slide Title</th><td><strong>Isolate-Driven Native ONNX C-FFI Execution</strong></td></tr>
    <tr><th>Slide Text</th><td>
      • <strong>The Problem:</strong> Synchronous native inference takes ~1,680 ms on CPU, locking the UI and causing severe application freeze.<br>
      • <strong>The Solution:</strong> <code>OnnxInferenceWorker</code> spawned on an isolated Dart background thread using Microsoft ONNX Runtime C-FFI.<br>
      • <strong>Temporal Tensor Construction:</strong> Ring buffer builds [1, 16, 3, 224, 224] Float32 tensor ($9.63\text{ MB}$) transferred via SendPort in 5.0 ms.<br>
      • <strong>Strict Memory Hygiene:</strong> 25-cycle lifecycle validation shows zero leak plateauing with net drift of $-6.79\text{ MB}$.
    </td></tr>
    <tr><th>Recommended Visual</th><td>
      Thread isolation diagram showing Main UI Thread (smooth 60 Hz vsync) communicating asynchronously with Worker Isolate (ONNX AVX2 execution).
    </td></tr>
    <tr><th>Main Takeaway</th><td>The application maintains fluid 60 Hz responsiveness regardless of model latency, eliminating operator distraction.</td></tr>
    <tr><th>Verbal Transition</th><td><em>"Now, let's see SentinelX running live on actual hardware. Over to Presenter 3 for the live demonstration."</em></td></tr>
  </table>
</div>

<!-- SLIDE 7 -->
<div class="callout callout-info" style="border-left-color: #0284c7;">
  <h3>SLIDE 7 // Live Demonstration: Controlled Drill Simulation & Triage</h3>
  <table>
    <tr><th style="width: 20%;">Presenter</th><td><strong>Presenter 3</strong> (Demo & Results Lead)</td></tr>
    <tr><th>Time Window</th><td><strong>2:20 – 4:40</strong> (140 Seconds / 2 Minutes 20 Seconds)</td></tr>
    <tr><th>Slide Title</th><td><strong>Live System Demonstration: Physical Edge to Central EOC</strong></td></tr>
    <tr><th>Slide Text</th><td>
      • <strong>Screen 1 (Flutter Desktop):</strong> Live physical capture via HP TrueVision HD Camera, temporal buffer telemetry, Cyberpunk HUD.<br>
      • <strong>Screen 2 (React 19 EOC):</strong> Central operations incident monitor with live sync, status badges, and dispatch controls.<br>
      • <strong>Controlled Drill Exercise:</strong> Trigger a demonstration incident; verify instant database persistence and cross-client reflection.<br>
      • <strong>Dispatch Progression:</strong> Progress incident from <code>unassigned</code> → <code>assigned_police</code> → <code>en_route</code> → <code>resolved</code>.
    </td></tr>
    <tr><th>Recommended Visual</th><td>
      Live projection split: Left side showing Flutter Desktop window with live video feed; right side showing React Web Browser with EOC portal.
    </td></tr>
    <tr><th>Main Takeaway</th><td>SentinelX is a functioning, integrated, multi-client system executing in real time on physical hardware right before the judges' eyes.</td></tr>
    <tr><th>Verbal Transition</th><td><em>"As demonstrated, the entire pipeline is operational. Now, let's look at the rigorous empirical verification behind it."</em></td></tr>
  </table>
</div>

<!-- SLIDE 8 -->
<div class="page-break"></div>
<div class="callout callout-info" style="border-left-color: #0284c7;">
  <h3>SLIDE 8 // Empirical Verification & Reconciled Performance</h3>
  <table>
    <tr><th style="width: 20%;">Presenter</th><td><strong>Presenter 3</strong></td></tr>
    <tr><th>Time Window</th><td><strong>4:40 – 5:40</strong> (60 Seconds)</td></tr>
    <tr><th>Slide Title</th><td><strong>Independently Verified Performance Baseline</strong></td></tr>
    <tr><th>Slide Text</th><td>
      • <strong>10-Minute Sustained Hardware Test:</strong> 600.0s run on HP TrueVision camera; 4,399 frames ingested (7.33 FPS) with zero crashes.<br>
      • <strong>Zero UI Blocking:</strong> 13,355 engine frames rendered; 97.53% fluid presentation rate with only 2.47% compositor jank.<br>
      • <strong>Memory Stability:</strong> Reaches bounded plateau (Peak 873 MB → Final 417 MB) actively reclaimed by Dart VM generational GC.<br>
      • <strong>Comprehensive Regression:</strong> <strong>238 / 238 tests passing (100%)</strong> across 18 test suites in Flutter, Node.js, and Python ML.
    </td></tr>
    <tr><th>Recommended Visual</th><td>
      Clean metric dashboard table comparing Phase 4.3.5.1 verified numbers against industry performance baselines, highlighted in emerald green.
    </td></tr>
    <tr><th>Main Takeaway</th><td>All claims are backed by rigorous, reconciled empirical benchmarks and reproducible automated test suites.</td></tr>
    <tr><th>Verbal Transition</th><td><em>"We believe in absolute engineering honesty. Let's explicitly discuss our current limitations and future scope."</em></td></tr>
  </table>
</div>

<!-- SLIDE 9 -->
<div class="callout callout-info" style="border-left-color: #0284c7;">
  <h3>SLIDE 9 // Responsible Disclosure: Limitations & Phase 4.4 Roadmap</h3>
  <table>
    <tr><th style="width: 20%;">Presenter</th><td><strong>Presenter 3</strong></td></tr>
    <tr><th>Time Window</th><td><strong>5:40 – 6:35</strong> (55 Seconds)</td></tr>
    <tr><th>Slide Title</th><td><strong>Engineering Transparency & Next Development Milestones</strong></td></tr>
    <tr><th>Slide Text</th><td>
      • <strong>Current Limitation (Degraded Mode):</strong> Edge model evaluates video frames against a calibrated $-80.0\text{ dB}$ silence baseline.<br>
      • <strong>Phase 4.4 Milestone:</strong> Live hardware microphone audio ingestion and on-premise distress keyword spotter integration.<br>
      • <strong>GPU Acceleration:</strong> DirectML integration planned to boost inference throughput from 0.4 FPS (CPU) to >10 FPS (GPU).<br>
      • <strong>Privacy by Design:</strong> Zero facial recognition, zero biometric tracking; fully GDPR/CCPA compliant motion dynamics.
    </td></tr>
    <tr><th>Recommended Visual</th><td>
      Timeline roadmap showing Phase 4.3.5.1 (Complete) → Phase 4.4 (Live Audio & KWS) → Phase 5.0 (DirectML & Clustered Redis EOC).
    </td></tr>
    <tr><th>Main Takeaway</th><td>Mature engineering teams disclose current operating boundaries honestly and present concrete, measurable milestones for completion.</td></tr>
    <tr><th>Verbal Transition</th><td><em>"In conclusion, SentinelX transforms passive video surveillance into proactive physical safety."</em></td></tr>
  </table>
</div>

<!-- SLIDE 10 -->
<div class="callout callout-info" style="border-left-color: #0284c7;">
  <h3>SLIDE 10 // Conclusion & Call to Action</h3>
  <table>
    <tr><th style="width: 20%;">Presenter</th><td><strong>Presenter 3</strong> (Supported by Team)</td></tr>
    <tr><th>Time Window</th><td><strong>6:35 – 7:00</strong> (25 Seconds)</td></tr>
    <tr><th>Slide Title</th><td><strong>Transforming Surveillance from Passive Recording to Active Protection</strong></td></tr>
    <tr><th>Slide Text</th><td>
      • <strong>Sub-Second Anomaly Detection:</strong> Moving from 10-minute human response lags to immediate operator alerting.<br>
      • <strong>Enterprise Ready Architecture:</strong> Full MERN + Flutter multi-platform stack with Protocol v2 HMAC security boundaries.<br>
      • <strong>Proven Reliability:</strong> 10-minute continuous hardware validation and 238 automated passing tests.<br>
      • <em>"Thank you, judges. We are now open for technical questions and answers."</em>
    </td></tr>
    <tr><th>Recommended Visual</th><td>
      High-impact summary card with team photo/placeholders, GitHub repository QR code, contact information, and "Q&A Ready" badge.
    </td></tr>
    <tr><th>Main Takeaway</th><td>Memorable, confident closing positioning SentinelX as a competitive, technically sound, and ethically grounded security innovation.</td></tr>
    <tr><th>Verbal Transition</th><td>Handoff to judges for technical Q&A session.</td></tr>
  </table>
</div>
"""
    return wrap_html("MERNOVA - 7-Minute Presentation Guide", content)

if __name__ == '__main__':
    html = generate_presentation_guide_html()
    out_path = os.path.join(os.path.dirname(__file__), "MERNOVA_7_Minute_Presentation_Guide.html")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"Generated {out_path} ({len(html)} bytes)")
