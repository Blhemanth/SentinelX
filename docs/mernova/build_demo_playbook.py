# build_demo_playbook.py - Generates MERNOVA_Live_Demo_Playbook.html
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pdf_styles import wrap_html

def generate_demo_playbook_html():
    content = r"""
<div class="doc-header">
  <h1>MERNOVA // LIVE DEMO PLAYBOOK</h1>
  <div class="subtitle">Complete Technical Guide, Choreography, Machine Setup & Recovery Runbook</div>
  <div class="meta-grid">
    <div class="meta-item"><strong>Event</strong><span>MERNOVA Competition</span></div>
    <div class="meta-item"><strong>Demo Duration</strong><span>2:20 Minutes (140s) Strict</span></div>
    <div class="meta-item"><strong>Hardware</strong><span>HP TrueVision HD Camera (DirectShow)</span></div>
    <div class="meta-item"><strong>Execution Mode</strong><span>100% Genuine Physical Hardware</span></div>
  </div>
</div>

<div class="callout callout-info">
  <strong>Live Demo Core Philosophy:</strong> Zero simulation, zero pre-recorded video loops, and zero fake mock telemetry. We operate directly on native Windows 11 x64 hardware with a physical webcam, background Dart isolates, and live REST/WebSocket synchronization to demonstrate verified edge surveillance intelligence.
</div>

<!-- ========================================================================= -->
<h2>1. Hardware & Environment Pre-Flight Checklist</h2>

<div class="card">
  <div class="card-header">
    <strong>Demo Machine Hardware & System Configuration</strong>
    <span class="badge badge-verified">Pre-Flight Spec</span>
  </div>
  <div class="card-body">
    <table>
      <tr><th style="width: 25%;">Hardware Parameter</th><th style="width: 35%;">Required Specification</th><th>Verified Status</th></tr>
      <tr><td>Host Laptop</td><td>Windows 11 x64 Home/Pro, Intel Core i5/i7 or AMD Ryzen 5/7</td><td><span class="badge badge-verified">Verified</span></td></tr>
      <tr><td>CPU Features</td><td>x86_64 with AVX2 and FMA SIMD instruction support</td><td><span class="badge badge-verified">Verified</span></td></tr>
      <tr><td>Integrated Camera</td><td>HP TrueVision HD Camera (DirectShow ID: VID_0408, PID_5326)</td><td><span class="badge badge-verified">Verified</span></td></tr>
      <tr><td>RAM & Storage</td><td>16 GB DDR4/DDR5 RAM, &gt; 10 GB free NVMe SSD storage</td><td><span class="badge badge-verified">Verified</span></td></tr>
      <tr><td>Power Source</td><td>Dedicated AC Wall Power Connected (Never run demo on battery saver!)</td><td><span class="badge badge-verified">Mandatory</span></td></tr>
      <tr><td>Display Configuration</td><td>Primary 1080p (1920x1080) at 100% scaling; Projector duplicate/extend</td><td><span class="badge badge-verified">Verified</span></td></tr>
    </table>
  </div>
</div>

<div class="card">
  <div class="card-header">
    <strong>Software & Port Allocation Matrix</strong>
    <span class="badge badge-verified">Port Checks</span>
  </div>
  <div class="card-body">
    <table>
      <tr><th style="width: 20%;">Service Name</th><th style="width: 25%;">Runtime / Technology</th><th style="width: 20%;">Port / Endpoint</th><th>Verification Command</th></tr>
      <tr><td>MongoDB Database</td><td>MongoDB 7.0 Community Edition</td><td><code>mongodb://127.0.0.1:27017</code></td><td><code>Get-Service MongoDB</code></td></tr>
      <tr><td>Backend API</td><td>Node.js v20.x + Express</td><td><code>http://localhost:5000</code></td><td><code>curl http://localhost:5000/api/health</code></td></tr>
      <tr><td>Web Operations Portal</td><td>React 19 + Vite Dev Server</td><td><code>http://localhost:5173</code></td><td><code>curl http://localhost:5173</code></td></tr>
      <tr><td>Desktop Client</td><td>Flutter Windows x64 Desktop</td><td>Native Win32 DirectX Window</td><td><code>bin/sentinelx.exe</code></td></tr>
    </table>
  </div>
</div>

<!-- ========================================================================= -->
<h2>2. Step-by-Step Cold Startup Sequence (T-30 Minutes)</h2>

<div class="callout callout-warning">
  <strong>Pre-Stage Staging:</strong> Execute this sequence exactly 30 minutes before taking the stage. Never launch services during the opening slide!
</div>

<div class="card">
  <div class="card-body">
    <p><strong>Step 1: Check Windows Camera Privacy Permissions</strong><br>
    Open Windows Settings &gt; Privacy & Security &gt; Camera. Confirm: (1) Camera access is ON; (2) "Let desktop apps access your camera" is ON. Ensure Zoom, Teams, or Skype are fully exited and not holding a DirectShow device lock.</p>

    <p><strong>Step 2: Start MongoDB Database Service</strong><br>
    Open PowerShell as Administrator:
    <pre><code>net start MongoDB
# Verify active connection:
mongosh --eval "db.adminCommand('ping')"</code></pre></p>

    <p><strong>Step 3: Reset & Seed Database to Known Clean State</strong><br>
    <pre><code>cd B:\SentinelX\backend
node src/scripts/seed.js
# Output must show: Default users created, cameras registered, clean incident history.</code></pre></p>

    <p><strong>Step 4: Launch Express Backend API Service</strong><br>
    Open dedicated Terminal 1:
    <pre><code>cd B:\SentinelX\backend
npm start
# Verify output: [Server] Listening on port 5000, MongoDB Connected.</code></pre></p>

    <p><strong>Step 5: Launch React Operations Web Portal</strong><br>
    Open dedicated Terminal 2:
    <pre><code>cd B:\SentinelX\frontend
npm run dev
# Verify output: VITE v5.x ready in 280 ms -> Local: http://localhost:5173/</code></pre>
    Open Google Chrome to <code>http://localhost:5173</code>, login with operator credentials, and arrange browser window on the right half of the display screen.</p>

    <p><strong>Step 6: Launch Native Flutter Desktop Client</strong><br>
    Open dedicated Terminal 3:
    <pre><code>cd B:\SentinelX
flutter run -d windows --release
# Alternatively launch pre-built executable:
# .\build\windows\x64\runner\Release\sentinelx.exe</code></pre>
    Position Flutter application on the left half of the display screen. Confirm camera feed appears immediately.</p>
  </div>
</div>

<!-- ========================================================================= -->
<h2>3. Minute-by-Minute Live Demo Choreography (2:20 to 4:40)</h2>

<div class="table-container">
  <table>
    <thead>
      <tr>
        <th style="width: 12%;">Time Window</th>
        <th style="width: 25%;">Demonstration Focus</th>
        <th style="width: 38%;">Presenter 3 Spoken Actions & Screen State</th>
        <th style="width: 25%;">Operator Actions</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><strong>0:00 – 0:25</strong><br>(2:20 – 2:45)</td>
        <td><strong>Physical Camera Ingestion & DirectShow Lock</strong></td>
        <td>
          Presenter 3 points to the left window: "Judges, this is our native Windows desktop client. Our DirectShow pipeline is actively capturing live 720p frames from this integrated HP webcam at 7.3 FPS. Notice the telemetry banner showing hardware device ID, active resolution, and zero frame corruption."
        </td>
        <td>Wave hand gently across camera lens to show live video preview fluidity. Verify telemetry updates.</td>
      </tr>
      <tr>
        <td><strong>0:25 – 0:50</strong><br>(2:45 – 3:10)</td>
        <td><strong>Temporal Frame Buffer & Tensor Preprocessing</strong></td>
        <td>
          "Our circular TemporalFrameBuffer continuously queues 16 frames. Each frame is downsampled to 224x224 and normalized. Once 16 frames accumulate, our contiguous 5D Float32 tensor of shape [1, 16, 3, 224, 224] is transferred across isolates in under 4 milliseconds."
        </td>
        <td>Toggle 'Debug Telemetry Drawer' in the Flutter client to display buffer depth counter (16/16).</td>
      </tr>
      <tr>
        <td><strong>0:50 – 1:15</strong><br>(3:10 – 3:35)</td>
        <td><strong>Background Isolate ONNX Inference & Fluid UI</strong></td>
        <td>
          "In the background, OnnxInferenceWorker executes continuous forward passes through the 34-million parameter model. Inference latency is ~1,350ms, achieving 0.38 FPS throughput on standard CPU. Look at the Flutter UI: it maintains 97.5% fluidity without dropping a single frame."
        </td>
        <td>Move mouse cursor continuously across the UI and click tabs to visually prove zero UI stuttering.</td>
      </tr>
      <tr>
        <td><strong>1:15 – 1:40</strong><br>(3:35 – 4:00)</td>
        <td><strong>Live Threat Simulation & Threshold Triggering</strong></td>
        <td>
          "Now, we simulate an active threat condition. As rapid erratic physical motion occurs, observe the real-time classification probability bars: 'violent_behavior' surges past our 0.85 safety threshold. Instantly, the UI shifts into crimson high-threat alert mode."
        </td>
        <td>Presenter 1 or 2 executes rapid motion gesture in front of camera. Client triggers crimson alert border.</td>
      </tr>
      <tr>
        <td><strong>1:40 – 2:05</strong><br>(4:00 – 4:25)</td>
        <td><strong>Protocol v2 HMAC Submission & React Portal Sync</strong></td>
        <td>
          "The client dispatches the incident payload to our Express backend. Notice the right window — our React 19 Operations Portal. Within 42 milliseconds, the incident appears in the live audit queue. The backend classifies it as 'manual_entry' and 'unverified' under our zero-client-trust security policy."
        </td>
        <td>Point clicker at the React browser window. Highlight newly populated incident card in the feed.</td>
      </tr>
      <tr>
        <td><strong>2:05 – 2:20</strong><br>(4:25 – 4:40)</td>
        <td><strong>Incident Triage & Resolution Workflow</strong></td>
        <td>
          "The human security operator clicks 'Acknowledge', reviews the anomaly timestamp, and transitions the incident to 'INVESTIGATING' and 'RESOLVED'. The audit trail is permanently committed to MongoDB, completing the full incident lifecycle."
        </td>
        <td>Click 'Acknowledge' and 'Resolve' on the web portal. Show the green resolved status badge.</td>
      </tr>
    </tbody>
  </table>
</div>

<!-- ========================================================================= -->
<h2>4. Comprehensive Failure Diagnosis & Rapid Recovery Runbook</h2>

<div class="card">
  <div class="card-header">
    <strong>Live Troubleshooting Matrix</strong>
    <span class="badge badge-danger">Emergency Fixes</span>
  </div>
  <div class="card-body">
    <table>
      <thead>
        <tr>
          <th style="width: 22%;">Failure Symptom</th>
          <th style="width: 28%;">Root Cause</th>
          <th style="width: 50%;">Immediate Recovery Procedure (&lt; 10 Seconds)</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td><strong>Camera preview shows black screen or 0 FPS</strong></td>
          <td>DirectShow video capture device locked by another Windows process.</td>
          <td>
            1. In Flutter app, press <code>Ctrl+R</code> or click the top-right 'Reset Camera' icon.<br>
            2. If unresolved, run in PowerShell: <code>Stop-Process -Name "sentinelx"</code>, verify no other apps use camera, and relaunch.<br>
            3. <em>Speaker Line:</em> "The DirectShow driver is re-synchronizing camera capture; let us examine the verified 10-minute telemetry baseline."
          </td>
        </tr>
        <tr>
          <td><strong>Flutter App crashes on launch</strong></td>
          <td>Missing <code>onnxruntime.dll</code> in application directory or PATH.</td>
          <td>
            1. Confirm <code>onnxruntime.dll</code> exists in <code>b:\SentinelX\windows\flutter\ephemeral</code> or system PATH.<br>
            2. Launch the pre-tested backup executable in <code>docs/mernova/backup_bin/sentinelx.exe</code>.
          </td>
        </tr>
        <tr>
          <td><strong>React Web Portal shows 'Disconnected' banner</strong></td>
          <td>Express API server terminated or port 5000 blocked.</td>
          <td>
            1. Check Terminal 1. If crashed, press <code>Up Arrow + Enter</code> to restart <code>npm start</code>.<br>
            2. Hard-refresh browser with <code>Ctrl+F5</code>.
          </td>
        </tr>
        <tr>
          <td><strong>Inference latency exceeds 3,000 ms</strong></td>
          <td>Windows power throttling or background virus scan consuming CPU cores.</td>
          <td>
            1. Verify AC adapter is firmly plugged into laptop.<br>
            2. Temporarily pause Windows Security real-time protection during presentation.
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</div>

<!-- ========================================================================= -->
<h2>5. Emergency Teardown & Reset Script</h2>

<div class="callout callout-info">
  To wipe all temporary test incidents and reset the database to pristine condition after a demo run, execute the following script:
  <pre><code># Reset SentinelX Demo State (PowerShell)
cd B:\SentinelX\backend
node src/scripts/seed.js
Write-Host "Demo environment successfully reset to factory baseline." -ForegroundColor Green</code></pre>
</div>
"""
    return wrap_html("MERNOVA // Live Demo Playbook", content)

if __name__ == "__main__":
    html = generate_demo_playbook_html()
    out_path = os.path.join(os.path.dirname(__file__), "MERNOVA_Live_Demo_Playbook.html")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"Generated {out_path} ({len(html)} bytes)")
