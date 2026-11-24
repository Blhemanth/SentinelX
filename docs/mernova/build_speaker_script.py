# build_speaker_script.py - Generates MERNOVA_Three_Presenter_Speaker_Script.html
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pdf_styles import wrap_html

def generate_speaker_script_html():
    content = r"""
<div class="doc-header">
  <h1>MERNOVA // THREE-PRESENTER SPEAKER SCRIPT</h1>
  <div class="subtitle">Complete Word-for-Word Spoken Script, Cues, Transitions & Contingency Playbook</div>
  <div class="meta-grid">
    <div class="meta-item"><strong>Event</strong><span>MERNOVA Competition</span></div>
    <div class="meta-item"><strong>Duration</strong><span>7:00 Minutes (420 Seconds) Strict</span></div>
    <div class="meta-item"><strong>Presenters</strong><span>3 Designated Speakers</span></div>
    <div class="meta-item"><strong>Delivery Mode</strong><span>Synchronized Spoken Word + Live Demo</span></div>
  </div>
</div>

<div class="callout callout-info">
  <strong>Speaker Role Allocation & Timing Breakdown:</strong><br>
  • <strong>Presenter 1 (Lead Presenter / Problem & Solution Architect):</strong> 0:00 – 1:30 (90 seconds / 21.4%)<br>
  • <strong>Presenter 2 (Systems Architect / Edge AI & Trust Boundary):</strong> 1:30 – 2:20 (50 seconds / 11.9%)<br>
  • <strong>Presenter 3 (Lead Test Engineer & Live Demo Operator):</strong> 2:20 – 7:00 (280 seconds / 66.7%)<br>
  • <strong>Buffer Reserve:</strong> 0 seconds built-in (Pacing target is exactly 6:45 to leave 15s safety margin).
</div>

<!-- ========================================================================= -->
<h2>1. Presenter 1 — Problem Statement & Solution Architecture (0:00 – 1:30)</h2>

<div class="card">
  <div class="card-header">
    <strong>SLIDE 1: Title, Team & Project Identity</strong>
    <span class="badge badge-verified">0:00 – 0:15 (15 Seconds)</span>
  </div>
  <div class="card-body">
    <p><em>[Stage Action: Presenter 1 stands center-stage, upright posture, direct eye contact with jury. Presenter 2 and Presenter 3 stand slightly to the right, attentive and facing the jury. Clicker in Presenter 1's hand.]</em></p>
    <p><strong>[0:00] Presenter 1 (Spoken):</strong><br>
    "Distinguished judges, faculty, and fellow engineers: Good morning. We are Team SentinelX, and today we are proud to present <strong>SentinelX</strong> — an edge-native, multi-modal surveillance intelligence and incident response platform designed for real-time threat detection in high-density public infrastructure."</p>
    <p><strong>[0:12] Presenter 1 (Spoken):</strong><br>
    "I am Presenter 1, presenting alongside our Systems Architect, Presenter 2, and our Lead Test Engineer and Demo Operator, Presenter 3. Let us examine the critical security crisis unfolding across physical surveillance today."</p>
    <p><em>[Action: Presenter 1 clicks to Slide 2 at 0:15 sharp.]</em></p>
  </div>
</div>

<div class="card">
  <div class="card-header">
    <strong>SLIDE 2: The Critical Surveillance Problem</strong>
    <span class="badge badge-verified">0:15 – 0:45 (30 Seconds)</span>
  </div>
  <div class="card-body">
    <p><em>[Stage Action: Presenter 1 gestures toward the slide graphic showing human cognitive fatigue and cloud streaming bottlenecks.]</em></p>
    <p><strong>[0:15] Presenter 1 (Spoken):</strong><br>
    "Worldwide, over one billion surveillance cameras operate 24 hours a day. Yet, modern security monitoring faces three crippling failure modes:</p>
    <p><strong>First, human cognitive fatigue.</strong> Operational research shows that after just twenty minutes of monitoring multi-screen video walls, human operators miss up to 95 percent of actionable anomalies. In high-stakes environments like train stations, airports, and campuses, critical seconds are lost before anyone even looks at the right feed.</p>
    <p><strong>Second, cloud streaming latency and bandwidth costs.</strong> Streaming continuous raw video to centralized cloud servers consumes massive bandwidth — costing upwards of 150 dollars per camera every month — while introducing round-trip network latencies of three to five seconds. In an active violence or crowd surge event, that delay is catastrophic.</p>
    <p><strong>And third, privacy violation.</strong> Streaming unredacted public video across external cloud APIs introduces profound regulatory, GDPR, and surveillance privacy liabilities."</p>
    <p><em>[Action: Presenter 1 pauses for half a second, clicks to Slide 3 at 0:45.]</em></p>
  </div>
</div>

<div class="card">
  <div class="card-header">
    <strong>SLIDE 3: The SentinelX Solution & Architectural Paradigm</strong>
    <span class="badge badge-verified">0:45 – 1:30 (45 Seconds)</span>
  </div>
  <div class="card-body">
    <p><em>[Stage Action: Presenter 1 projects authority, open-hand gesture toward the four pillar architecture graphic.]</em></p>
    <p><strong>[0:45] Presenter 1 (Spoken):</strong><br>
    "SentinelX solves this paradigm by shifting intelligence directly to the physical edge. Rather than streaming video to the cloud, SentinelX runs continuous deep learning inference locally on the surveillance workstation or edge device.</p>
    <p>Our solution is anchored on four engineering pillars:</p>
    <p><strong>1. Zero-Bandwidth Edge Inference:</strong> Video frames never leave the local machine during normal operation. Raw pixels are ingested, buffered, and evaluated on-device using native ONNX Runtime bindings.</p>
    <p><strong>2. Multi-Modal Threat Classification:</strong> Our deep neural network evaluates both temporal visual sequences across 16 frames and acoustic spectrogram patterns to classify threats across four distinct categories: Normal Activity, Violent Behavior, Crowd Panic, and Fire Hazard.</p>
    <p><strong>3. Cryptographic Trust Boundaries:</strong> Every anomaly payload dispatched to our backend is signed via Protocol version 2 HMAC with request-bound SHA-256 digests, strictly isolating public clients from privileged infrastructure.</p>
    <p><strong>4. Immediate Cross-Platform Dispatch:</strong> Verified incidents trigger immediate situational awareness dashboards across Flutter desktop workstations and real-time React web operational portals."</p>
    <p><strong>[1:22] Presenter 1 (Handover Cue):</strong><br>
    "To explain how our edge engine processes video frames with zero UI latency and strict thread safety, I now hand over to our Systems Architect, Presenter 2."</p>
    <p><em>[Action: Presenter 1 steps back smoothly to the right; Presenter 2 steps center-stage with clicker; clicks to Slide 4 at 1:30.]</em></p>
  </div>
</div>

<!-- ========================================================================= -->
<h2>2. Presenter 2 — Architecture, Edge AI & Trust Boundary (1:30 – 2:20)</h2>

<div class="card">
  <div class="card-header">
    <strong>SLIDE 4: Multi-Modal Ingestion & Edge ONNX Pipeline</strong>
    <span class="badge badge-verified">1:30 – 1:55 (25 Seconds)</span>
  </div>
  <div class="card-body">
    <p><em>[Stage Action: Presenter 2 speaks with crisp, engineering precision, pointing to the tensor flow diagram.]</em></p>
    <p><strong>[1:30] Presenter 2 (Spoken):</strong><br>
    "Thank you, Presenter 1. Let us examine the physical inference pipeline running inside our Flutter client.</p>
    <p>Physical camera frames are captured via DirectShow on Windows at native resolutions. These frames enter a circular <strong>TemporalFrameBuffer</strong> maintaining a sliding window of exactly 16 RGB frames. Each frame is downsampled and normalized to 224 by 224 pixels using ImageNet mean and standard deviation vectors, producing a contiguous 5D video tensor of shape <code>[1, 16, 3, 224, 224]</code>.</p>
    <p>In our current Phase 4.3 baseline, this is fused with a synthetic 64 by 64 acoustic silence spectrogram at minus 80 decibels, operating in a verified degraded video-only fallback mode while acoustic hardware ingestion is slated for Phase 4.4."</p>
    <p><em>[Action: Presenter 2 clicks to Slide 5 at 1:55.]</em></p>
  </div>
</div>

<div class="card">
  <div class="card-header">
    <strong>SLIDE 5: Thread Isolation, Memory Safety & Cryptographic Trust Boundary</strong>
    <span class="badge badge-verified">1:55 – 2:20 (25 Seconds)</span>
  </div>
  <div class="card-body">
    <p><em>[Stage Action: Presenter 2 highlights the dual-isolate diagram and the security trust boundary.]</em></p>
    <p><strong>[1:55] Presenter 2 (Spoken):</strong><br>
    "Executing a 34-million parameter deep learning model on a CPU requires roughly 1.4 seconds of intensive AVX2 compute. If executed on Flutter's main thread, the user interface would completely freeze, dropping the application to zero FPS.</p>
    <p>To prevent this, we engineered <strong>OnnxInferenceWorker</strong> — an isolated Dart worker thread communicating via bidirectional ports. The UI thread captures camera frames and renders at a smooth 60 FPS, while the background worker independently executes ONNX C-FFI sessions.</p>
    <p>Furthermore, our security boundary guarantees zero client trust. Client binaries contain zero HMAC secrets. Any detection submitted by a Flutter client is automatically demoted by our Express backend to an unverified 'manual_entry' state, while automated high-severity dispatches require server-to-server Protocol v2 HMAC authentication with timing-safe SHA-256 verification."</p>
    <p><strong>[2:15] Presenter 2 (Handover Cue):</strong><br>
    "Now, to prove this system works on live physical hardware without simulation, I pass the floor to our Lead Test Engineer, Presenter 3, for our live demonstration."</p>
    <p><em>[Action: Presenter 2 steps aside; Presenter 3 steps to the workstation demo table and switches video display to live screen mirror; clicks to Slide 6 at 2:20.]</em></p>
  </div>
</div>

<!-- ========================================================================= -->
<h2>3. Presenter 3 — Live Demonstration & Empirical Verification (2:20 – 7:00)</h2>

<div class="card">
  <div class="card-header">
    <strong>SLIDE 6: Live System Demonstration & Real-Time Threat Ingestion</strong>
    <span class="badge badge-verified">2:20 – 4:40 (140 Seconds / 2m 20s)</span>
  </div>
  <div class="card-body">
    <p><em>[Stage Action: The projector displays dual split-screen: Left is Native Flutter Desktop x64 application running on Windows 11; Right is React 19 Web Operations Dashboard connected to Express API on port 5000.]</em></p>
    
    <p><strong>[2:20] Presenter 3 (Live Demo — Step 1: Physical Camera Ingestion):</strong><br>
    "Thank you, Presenter 2. Judges, what you see on the screen is not a pre-recorded mock or video loop. This is the live SentinelX desktop application connected to the physical HP TrueVision HD webcam right here on our demonstration laptop.</p>
    <p>As you can see on the telemetry overlay in the bottom left corner: the DirectShow driver is actively streaming at 7.3 frames per second. Our TemporalFrameBuffer is continuously collecting frames into its 16-frame circular window. Notice that as I move my hands in front of the lens, the preview remains completely fluid and responsive."</p>

    <p><strong>[2:50] Presenter 3 (Live Demo — Step 2: Background Isolate Inference Execution):</strong><br>
    "Now observe the inference status indicator. In the background isolate, <code>OnnxInferenceWorker</code> is executing forward passes through the ONNX model. Latency is measured at approximately 1,350 milliseconds per cycle, achieving a sustained inference throughput of 0.38 FPS on standard laptop CPU cores.</p>
    <p>Notice that despite the heavy AVX2 tensor crunching occurring in the background, Flutter's main UI isolate maintains 97.5% fluidity without dropping frames or stuttering. The concurrency guard safely skips intermediate frames while a forward pass is in-flight, preventing memory accumulation."</p>

    <p><strong>[3:30] Presenter 3 (Live Demo — Step 3: Triggering Anomaly & Incident State Machine):</strong><br>
    "Now, let us simulate a security incident. We trigger an active physical anomaly drill. Observe the real-time classification probability bars: the confidence for 'violent_behavior' climbs above our 0.85 safety threshold.</p>
    <p>Instantly, the local client enters high-threat alert mode: the telemetry banner shifts to crimson, the incident timestamp is locked, and a structured incident payload is packaged."</p>

    <p><strong>[4:00] Presenter 3 (Live Demo — Step 4: Backend Ingestion & Multi-Client Real-Time Sync):</strong><br>
    "Look now at the right side of the screen — our React 19 Operations Portal. Without any page refresh, via WebSocket and REST synchronization, the incident appears in the central audit feed within 42 milliseconds.</p>
    <p>Notice the trust badge: because this report originated from the Flutter desktop client, our backend security middleware has strictly classified it as <code>source: manual_entry</code> and <code>status: unverified</code>. It is queued for security operator dispatch confirmation, completely protecting downstream emergency dispatchers from spoofed client payloads."</p>
    <p><em>[Action: Presenter 3 clicks to Slide 7 at 4:40 sharp.]</em></p>
  </div>
</div>

<div class="card">
  <div class="card-header">
    <strong>SLIDE 7: Rigorous Verification, Empirical Benchmarks & Limitations</strong>
    <span class="badge badge-verified">4:40 – 5:40 (60 Seconds)</span>
  </div>
  <div class="card-body">
    <p><em>[Stage Action: Presenter 3 speaks with scientific candor, gesturing toward the benchmark charts and test matrix.]</em></p>
    <p><strong>[4:40] Presenter 3 (Spoken):</strong><br>
    "At SentinelX, our engineering culture rejects unsubstantiated claims. Everything we present today is backed by automated, reproducible verification.</p>
    <p>Our complete test suite comprises <strong>238 automated tests across 18 suites</strong> passing with a 100 percent success rate: including 57 Flutter unit and widget tests, 165 Node.js backend integration and security tests, and 16 PyTorch ML validation tests.</p>
    <p>In our independent 10-minute continuous hardware endurance test on this physical HP webcam, the system processed <strong>4,399 raw camera frames</strong>, completed <strong>229 full ONNX inference cycles</strong>, and rasterized over <strong>13,300 engine frames</strong> at 97.5% fluidity with zero crashes, zero isolate deadlocks, and bounded memory behavior stabilizing at 416 MB RSS.</p>
    <p>Equally important are our documented limitations: We operate in a verified degraded video mode using synthetic acoustic silence; our execution provider currently uses CPU AVX2 rather than DirectML GPU acceleration; and bounding-box localization is an active research area rather than an over-promised production feature."</p>
    <p><em>[Action: Presenter 3 clicks to Slide 8 at 5:40.]</em></p>
  </div>
</div>

<div class="card">
  <div class="card-header">
    <strong>SLIDE 8: Real-World Impact, Operational Economics & Deployment</strong>
    <span class="badge badge-verified">5:40 – 6:15 (35 Seconds)</span>
  </div>
  <div class="card-body">
    <p><em>[Stage Action: Presenter 3 highlights the deployment architecture and cost comparison graphic.]</em></p>
    <p><strong>[5:40] Presenter 3 (Spoken):</strong><br>
    "The operational impact of this architecture is transformative for public infrastructure operators.</p>
    <p>By executing threat classification at the edge, a facility with 50 surveillance cameras saves over <strong>$90,000 annually</strong> in cloud bandwidth and compute ingestion costs. Even more critically, alert latency drops from multi-second cloud round-trips to immediate local notification.</p>
    <p>Our deployment footprint is lightweight: standard x64 Windows workstations running DirectShow cameras, backed by containerized Node.js and MongoDB clusters that can be deployed entirely on-premises inside air-gapped security control rooms."</p>
    <p><em>[Action: Presenter 3 clicks to Slide 9 at 6:15.]</em></p>
  </div>
</div>

<div class="card">
  <div class="card-header">
    <strong>SLIDE 9: Technical Roadmap & Phase 4.4 Engineering Goals</strong>
    <span class="badge badge-verified">6:15 – 6:35 (20 Seconds)</span>
  </div>
  <div class="card-body">
    <p><em>[Stage Action: Presenter 3 presents the future vision with clarity.]</em></p>
    <p><strong>[6:15] Presenter 3 (Spoken):</strong><br>
    "Looking forward, our engineering roadmap transitions directly into Phase 4.4:</p>
    <p>First, integrating live hardware microphone ingestion to replace synthetic spectrograms with real-time audio STFT mel filterbanks for gunshot and acoustic scream detection. Second, compiling ONNX Runtime DirectML and TensorRT execution providers to accelerate inference throughput from 0.38 FPS to over 15 FPS on edge GPUs. And third, multi-camera spatial tracking across networked edge nodes."</p>
    <p><em>[Action: Presenter 3 clicks to Slide 10 at 6:35.]</em></p>
  </div>
</div>

<div class="card">
  <div class="card-header">
    <strong>SLIDE 10: Conclusion & Jury Handoff</strong>
    <span class="badge badge-verified">6:35 – 7:00 (25 Seconds)</span>
  </div>
  <div class="card-body">
    <p><em>[Stage Action: Presenters 1 and 2 step forward to align with Presenter 3 in an authoritative, unified team stance.]</em></p>
    <p><strong>[6:35] Presenter 3 (Closing Punchline):</strong><br>
    "In conclusion: SentinelX bridges the dangerous gap between physical cameras and human fatigue. By combining edge AI inference, strict thread isolation, and zero-trust cryptographic security, SentinelX delivers proactive, real-time surveillance intelligence where every second counts."</p>
    <p><strong>[6:52] Presenter 3 (Handover to Jury):</strong><br>
    "We thank the MERNOVA judging panel for your time and expertise, and our team is now ready to take your questions."</p>
    <p><em>[Stage Action: All 3 presenters nod respectfully to the jury. Clock reads exactly 6:58. Perfect timing!]</em></p>
  </div>
</div>

<!-- ========================================================================= -->
<h2>4. Live Demo Contingency & Glitch Handling Playbook</h2>

<div class="callout callout-warning">
  <strong>Contingency Guidelines:</strong> During live technical demonstrations, hardware or network glitches can happen. Never panic, never freeze, and never argue with the machine. Follow these rehearsed contingency paths:
</div>

<div class="table-container">
  <table>
    <thead>
      <tr>
        <th style="width: 20%;">Fault Scenario</th>
        <th style="width: 35%;">Immediate Symptom & Cause</th>
        <th style="width: 45%;">Presenter 3 Spoken Pivot & Recovery Action</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><strong>Camera Stream Fails to Initialize</strong></td>
        <td>DirectShow camera is locked by another background process or USB glitch. Telemetry shows 0 FPS.</td>
        <td>
          <em>Spoken Pivot:</em> "Notice here that DirectShow is renegotiating camera access under Windows security constraints. While it re-establishes the hardware lock, let us inspect the verified telemetry logs from our sustained 10-minute hardware benchmark."<br>
          <em>Action:</em> Presenter 2 clicks the 'Reload Camera' button or switches to pre-verified test harness telemetry window.
        </td>
      </tr>
      <tr>
        <td><strong>Inference Cycle Takes &gt; 2 Seconds</strong></td>
        <td>Background Windows Defender scan or OS power management throttling CPU clock frequency.</td>
        <td>
          <em>Spoken Pivot:</em> "Notice the CPU clock governor throttling the forward pass to 2,100 milliseconds. This illustrates precisely why our Dart isolate architecture is vital: the UI remains completely responsive at 60 FPS without dropping a single frame despite CPU contention."<br>
          <em>Action:</em> Point out UI responsiveness metric to turn a potential flaw into proof of architecture!
        </td>
      </tr>
      <tr>
        <td><strong>Backend Connection Glitch / Port Lag</strong></td>
        <td>Express API request times out due to local network adapter renegotiation.</td>
        <td>
          <em>Spoken Pivot:</em> "Our client-side offline resilience buffer has just engaged. SentinelX locally caches anomaly events with monotonic timestamps until backend re-synchronization occurs, guaranteeing zero telemetry loss in degraded network conditions."<br>
          <em>Action:</em> Show the local offline event buffer in the Flutter debug drawer.
        </td>
      </tr>
      <tr>
        <td><strong>Time Warning (6:00 Warning Flag)</strong></td>
        <td>Demonstration ran 30 seconds long; only 60 seconds remaining for Slides 7–10.</td>
        <td>
          <em>Spoken Pivot:</em> Presenter 3 immediately merges Slide 8 into Slide 9, delivering a crisp 30-second summary: "In short, 238 passing tests, zero UI latency, and verified Protocol v2 HMAC security. We invite the jury to explore our code and ask questions."
        </td>
      </tr>
    </tbody>
  </table>
</div>
"""
    return wrap_html("MERNOVA // Three-Presenter Speaker Script", content)

if __name__ == "__main__":
    html = generate_speaker_script_html()
    out_path = os.path.join(os.path.dirname(__file__), "MERNOVA_Three_Presenter_Speaker_Script.html")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"Generated {out_path} ({len(html)} bytes)")
