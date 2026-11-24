# build_team_handbook.py - Generates MERNOVA_Team_Preparation_Handbook.html
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pdf_styles import wrap_html

def generate_team_handbook_html():
    content = r"""
<div class="doc-header">
  <h1>MERNOVA // TEAM PREPARATION HANDBOOK</h1>
  <div class="subtitle">5-Day Training Sprint, 40-Term Technical Glossary, Cross-Training Matrix & Scoring Rubric</div>
  <div class="meta-grid">
    <div class="meta-item"><strong>Event</strong><span>MERNOVA Competition</span></div>
    <div class="meta-item"><strong>Team Size</strong><span>3 Presenters + Support Engineers</span></div>
    <div class="meta-item"><strong>Training Duration</strong><span>5-Day Intensive Sprint</span></div>
    <div class="meta-item"><strong>Evaluation Rubric</strong><span>100-Point Competition Standard</span></div>
  </div>
</div>

<div class="callout callout-info">
  <strong>Preparation Objective:</strong> Transform 3 engineers into a synchronized, unflappable presentation unit capable of delivering a flawless 7-minute pitch, operating a live hardware demo without technical hitches, and defending every engineering decision across 105 jury questions with scientific candor and zero hype.
</div>

<!-- ========================================================================= -->
<h2>1. 5-Day Intensive Team Preparation Sprint</h2>

<div class="card">
  <div class="card-header">
    <strong>Day-by-Day Training Syllabus</strong>
    <span class="badge badge-verified">5-Day Schedule</span>
  </div>
  <div class="card-body">
    <p><strong>DAY 1: Architecture Mastery & Fact Alignment</strong><br>
    • <em>Goal:</em> Every team member achieves 100% fluency in SentinelX technical numbers and boundaries.<br>
    • <em>Activities:</em> Group read-through of <code>SentinelX_Project_Master_Guide.pdf</code>. Memorize key telemetry numbers: 238 passing tests, 10-minute test metrics (4,399 frames, 229 inferences, 0.38 FPS, 7.33 FPS camera, 97.53% fluidity, 416 MB RSS).<br>
    • <em>Verification Gate:</em> Rapid-fire oral quiz on the 5-tier evidence classification.</p>

    <p><strong>DAY 2: Live Demo Operations & Timing Synchronization</strong><br>
    • <em>Goal:</em> Demo operator achieves flawless muscle memory for the 2:20 minute live demo.<br>
    • <em>Activities:</em> Practice cold startup sequence 5 times. Rehearse window arrangement, camera motion drill, and incident triage flow. Coordinate screen transitions with Presenter 3's spoken lines.<br>
    • <em>Verification Gate:</em> Complete 3 consecutive demo runs within exactly 2:15–2:25 without a single verbal pause or misclick.</p>

    <p><strong>DAY 3: Judges Q&A Defense Drills (Simulated Grilling)</strong><br>
    • <em>Goal:</em> Eliminate hesitation and defensive posturing when answering difficult technical questions.<br>
    • <em>Activities:</em> Presenters take turns sitting in the "hot seat" while peer teammates roleplay aggressive, skeptical judges using questions from <code>MERNOVA_Judges_QA_Handbook.pdf</code>.<br>
    • <em>Verification Gate:</em> Answer 25 random questions from Categories 1–15, strictly stating the correct Tier badge and avoiding over-promising.</p>

    <p><strong>DAY 4: Full Dress Rehearsals with Injected Faults</strong><br>
    • <em>Goal:</em> Master contingency protocols under high-stress conditions.<br>
    • <em>Activities:</em> Conduct 4 complete 7-minute timed dress rehearsals in full presentation attire. Teammate deliberately injects faults during the demo (unplugging camera, dropping network, toggling slow CPU clock). Presenter 3 executes rehearsed contingency spoken pivots seamlessly.<br>
    • <em>Verification Gate:</em> Full 7-minute presentation finishes between 6:45 and 6:58 despite an injected fault.</p>

    <p><strong>DAY 5: Final Polish, Physical Pack & Stage Readiness</strong><br>
    • <em>Goal:</em> Complete operational readiness and mental calm.<br>
    • <em>Activities:</em> Equipment packing checklist verification. Clean laptop reboot. Test HDMI projector mirroring and audio levels. Final team pep talk and strategy lock.<br>
    • <em>Verification Gate:</em> All 6 PDF guides loaded onto offline tablets/phones; demo laptop sealed in flight bag.</p>
  </div>
</div>

<!-- ========================================================================= -->
<h2>2. 40-Term Technical Glossary & Acronym Reference</h2>

<div class="table-container">
  <table>
    <thead>
      <tr>
        <th style="width: 25%;">Term / Acronym</th>
        <th style="width: 35%;">Plain English Definition</th>
        <th style="width: 40%;">Technical Implementation Detail in SentinelX</th>
      </tr>
    </thead>
    <tbody>
      <tr><td><strong>AVX2</strong></td><td>Advanced Vector Extensions 2. CPU instruction set for fast math.</td><td>x86 SIMD instruction set utilized by ONNX Runtime for accelerated float32 matrix operations.</td></tr>
      <tr><td><strong>Background Isolate</strong></td><td>An independent worker thread in Dart that doesn't freeze the screen.</td><td>A separate Dart thread executing native ONNX C-FFI sessions via <code>OnnxInferenceWorker</code>.</td></tr>
      <tr><td><strong>Bcrypt</strong></td><td>A secure password-hashing algorithm resistant to cracking.</td><td>Password hashing library with 12 salt rounds protecting credentials in MongoDB.</td></tr>
      <tr><td><strong>Bilinear Downsampling</strong></td><td>Resizing an image smoothly using neighboring pixel averages.</td><td>Algorithm resizing raw camera frames to 224x224 input tensors.</td></tr>
      <tr><td><strong>Camera Texture Bridge</strong></td><td>High-speed pipeline feeding camera frames to the GPU screen.</td><td>DirectX hardware texture registered via Flutter's external texture registry.</td></tr>
      <tr><td><strong>Circular Buffer</strong></td><td>A memory queue that overwrites oldest items when full.</td><td>16-frame sliding queue in <code>TemporalFrameBuffer</code> maintaining constant $O(1)$ memory.</td></tr>
      <tr><td><strong>Concurrency Guard</strong></td><td>A gate that prevents new work from overloading a busy worker.</td><td>A boolean flag (<code>_isInferenceInFlight</code>) that safely skips incoming frames while a forward pass executes.</td></tr>
      <tr><td><strong>Conditioned Approval</strong></td><td>Approved for testing and demonstration, but not commercial life-safety.</td><td>Verification status granted in Phase 4.3.5.1 with documented limitations.</td></tr>
      <tr><td><strong>DirectShow</strong></td><td>Microsoft Windows API for capturing video from webcams.</td><td>Native video capture architecture interfaced via <code>camera_windows</code>.</td></tr>
      <tr><td><strong>FFI (Foreign Function Interface)</strong></td><td>A way for high-level Dart code to call low-level C libraries.</td><td><code>dart:ffi</code> bindings communicating directly with <code>onnxruntime.dll</code>.</td></tr>
      <tr><td><strong>Float32 Tensor</strong></td><td>A multi-dimensional array of 32-bit floating point numbers.</td><td>The data format required by the ONNX model: <code>[1, 16, 3, 224, 224]</code> video tensor.</td></tr>
      <tr><td><strong>Focal Loss</strong></td><td>A training loss function that focuses on hard, rare examples.</td><td>Loss function addressing severe class imbalance between normal traffic and rare crimes.</td></tr>
      <tr><td><strong>GDPR Compliance</strong></td><td>European data privacy laws governing surveillance cameras.</td><td>SentinelX complies by processing video transiently in RAM and discarding normal frames.</td></tr>
      <tr><td><strong>Grad-CAM</strong></td><td>Visual heatmaps showing which pixels triggered an AI decision.</td><td>Planned Phase 4.4 feature for visual anomaly localization.</td></tr>
      <tr><td><strong>HMAC Protocol v2</strong></td><td>Cryptographic signature proving message authenticity.</td><td>Request-bound HMAC-SHA256 signature validating internal server-to-server calls.</td></tr>
      <tr><td><strong>Idempotency</strong></td><td>Ensuring an action performed multiple times has the same outcome.</td><td>Detection UUID deduplication preventing duplicate incident entries in MongoDB.</td></tr>
      <tr><td><strong>ImageNet Normalization</strong></td><td>Standardizing image pixels using known color distributions.</td><td>Formula subtracting $[0.485, 0.456, 0.406]$ and dividing by $[0.229, 0.224, 0.225]$.</td></tr>
      <tr><td><strong>Inference Latency</strong></td><td>The time required for an AI model to process an input.</td><td>Measured at ~1,350–1,500 milliseconds per forward pass on CPU AVX2.</td></tr>
      <tr><td><strong>Inference Throughput</strong></td><td>How many complete AI predictions occur per second.</td><td>Measured at 0.38 FPS under steady-state continuous hardware operation.</td></tr>
      <tr><td><strong>JWT (JSON Web Token)</strong></td><td>A digitally signed security token verifying user identity.</td><td>Token passed in HTTP Authorization headers for web and client sessions.</td></tr>
      <tr><td><strong>Kinetics-400</strong></td><td>A large public dataset of video actions used for AI pretraining.</td><td>Video action recognition benchmark used for initial feature backbone pretraining.</td></tr>
      <tr><td><strong>Log-Mel Spectrogram</strong></td><td>A visual representation of sound frequencies over time.</td><td>Audio tensor shape <code>[1, 1, 64, 64]</code> representing sound frequency power.</td></tr>
      <tr><td><strong>Manual Entry Demotion</strong></td><td>Treating client data as unverified to prevent spoofing.</td><td>Security middleware stripping high-severity flags from public client payloads.</td></tr>
      <tr><td><strong>MongoDB 7.0</strong></td><td>A scalable document database storing system data.</td><td>NoSQL persistence layer holding users, incident records, and audit logs.</td></tr>
      <tr><td><strong>Multi-Modal Fusion</strong></td><td>Combining different sensory inputs (video + audio) together.</td><td>Concatenating 512-dim visual features with 128-dim acoustic features into 640-dim space.</td></tr>
      <tr><td><strong>Nonce</strong></td><td>A unique random number used only once to prevent replay attacks.</td><td>Cryptographic string verified and cached in Protocol v2 HMAC middleware.</td></tr>
      <tr><td><strong>ONNX (Open Neural Network Exchange)</strong></td><td>An open format for sharing and running AI models across platforms.</td><td>Cross-platform runtime format running the 34M-parameter SentinelX model.</td></tr>
      <tr><td><strong>OrtSession</strong></td><td>An active loaded instance of an ONNX model in memory.</td><td>Native C struct pointer initialized in the background isolate in ~119 ms.</td></tr>
      <tr><td><strong>RBAC (Role-Based Access Control)</strong></td><td>Restricting features based on user permissions.</td><td>Access hierarchy enforcing <code>admin</code>, <code>operator</code>, and <code>analyst</code> permissions.</td></tr>
      <tr><td><strong>React 19</strong></td><td>A modern JavaScript library for building web user interfaces.</td><td>Frontend web framework powering the SentinelX operations dashboard.</td></tr>
      <tr><td><strong>Riverpod</strong></td><td>A reactive state management framework for Flutter.</td><td>Compile-time safe dependency injection and stream management in Flutter desktop.</td></tr>
      <tr><td><strong>RSS (Resident Set Size)</strong></td><td>The exact amount of physical RAM occupied by a process.</td><td>Memory metric tracked during endurance testing: starting 224 MB, final 416 MB.</td></tr>
      <tr><td><strong>SIMD (Single Instruction Multiple Data)</strong></td><td>CPU capability to perform math on multiple numbers simultaneously.</td><td>Instruction parallelism used by AVX2 to compute tensor dot products.</td></tr>
      <tr><td><strong>Softmax</strong></td><td>A mathematical function converting raw numbers into probabilities.</td><td>Normalization function mapping 4 model logits to percentage probabilities.</td></tr>
      <tr><td><strong>STFT (Short-Time Fourier Transform)</strong></td><td>Converting raw audio waveforms into frequency spectrograms.</td><td>Audio transformation algorithm planned for live microphone processing in Phase 4.4.</td></tr>
      <tr><td><strong>Synthetic Silence Baseline</strong></td><td>A simulated sound of quiet background noise ($-80\text{ dB}$).</td><td>Fallback audio tensor populating the model during video-only degraded mode.</td></tr>
      <tr><td><strong>Temporal Sequence</strong></td><td>A series of video frames arranged sequentially in time.</td><td>16 consecutive camera frames capturing motion dynamics and physical velocity.</td></tr>
      <tr><td><strong>Timing-Safe Comparison</strong></td><td>Comparing secret strings in constant time to prevent hacking.</td><td><code>crypto.timingSafeEqual</code> preventing timing attacks on HMAC signatures.</td></tr>
      <tr><td><strong>UI Fluidity</strong></td><td>How smoothly an app renders frames without freezing or dropping.</td><td>Measured at 97.53% across 13,355 frames during continuous background inference.</td></tr>
      <tr><td><strong>Vite</strong></td><td>A fast build tool and bundler for modern web applications.</td><td>Bundler compiling the React operations portal in 639 milliseconds.</td></tr>
    </tbody>
  </table>
</div>

<!-- ========================================================================= -->
<h2>3. Team Cross-Training & Role Redundancy Matrix</h2>

<div class="card">
  <div class="card-header">
    <strong>Presenter Primary & Backup Responsibilities</strong>
    <span class="badge badge-verified">Redundancy Plan</span>
  </div>
  <div class="card-body">
    <table>
      <thead>
        <tr>
          <th>Presenter</th>
          <th>Primary Role</th>
          <th>Slide Ownership</th>
          <th>Backup Coverage Responsibility</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td><strong>Presenter 1</strong></td>
          <td>Lead Storyteller / Problem & Impact Architect</td>
          <td>Slides 1, 2, 3 (0:00–1:30)</td>
          <td>Can deliver Presenter 2's Slides 4–5 if Presenter 2 loses voice or is absent.</td>
        </tr>
        <tr>
          <td><strong>Presenter 2</strong></td>
          <td>Systems Architect / Edge AI & Trust Boundary</td>
          <td>Slides 4, 5 (1:30–2:20)</td>
          <td>Can operate demo controls or deliver Slides 1–3 if Presenter 1 is absent.</td>
        </tr>
        <tr>
          <td><strong>Presenter 3</strong></td>
          <td>Lead Test Engineer & Live Demo Operator</td>
          <td>Slides 6–10 (2:20–7:00)</td>
          <td>Deepest code and benchmark knowledge; handles all empirical Q&A inquiries.</td>
        </tr>
      </tbody>
    </table>
  </div>
</div>

<!-- ========================================================================= -->
<h2>4. 100-Point Rehearsal Evaluation Rubric</h2>

<div class="table-container">
  <table>
    <thead>
      <tr>
        <th style="width: 25%;">Evaluation Dimension</th>
        <th style="width: 15%;">Points</th>
        <th style="width: 60%;">Scoring Criteria</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><strong>Timing & Pacing</strong></td>
        <td>15 Pts</td>
        <td>Total presentation finishes between 6:45 and 6:58. Presenter handovers are instantaneous (&lt; 2 seconds). Live demo fits within 2:15–2:25. No rushed closing lines.</td>
      </tr>
      <tr>
        <td><strong>Technical Depth & Accuracy</strong></td>
        <td>25 Pts</td>
        <td>All technical claims match verified source code and test results. Exact tensor shapes [1,16,3,224,224], AVX2 CPU execution, Protocol v2 HMAC, and 238 tests accurately stated.</td>
      </tr>
      <tr>
        <td><strong>Live Demo Execution</strong></td>
        <td>25 Pts</td>
        <td>Genuine physical webcam stream operating live. Dual-window layout clearly visible. Threat simulation triggers visible state transition. Sync to React portal demonstrated.</td>
      </tr>
      <tr>
        <td><strong>Judges Q&A Defense</strong></td>
        <td>20 Pts</td>
        <td>Team answers immediately with designated lead speaker. Every answer references evidence tier. Team admits limitations candidly without excuses or false claims.</td>
      </tr>
      <tr>
        <td><strong>Stage Presence & Delivery</strong></td>
        <td>15 Pts</td>
        <td>Professional attire, confident posture, direct eye contact with jury. Clear vocal projection. Zero fidgeting or distracting hand gestures. Clicker transitions seamless.</td>
      </tr>
    </tbody>
  </table>
</div>

<!-- ========================================================================= -->
<h2>5. Mock-Jury Interrogation Simulation Scenarios</h2>

<div class="callout callout-danger">
  <strong>Tough Judge Drill:</strong> Judges in competitive hackathons and engineering juries probe for weak spots. Prepare your team for these five challenging jury confrontation scenarios:
</div>

<div class="card">
  <div class="card-body">
    <p><strong>Scenario 1: The Skeptical AI Researcher</strong><br>
    <em>Judge:</em> "At 0.38 FPS, your model processes one frame sequence every 2.6 seconds. Isn't that far too slow to catch a fast-moving physical assault?"<br>
    <em>Winning Team Response (Presenter 2):</em> "That is a perceptive observation. In surveillance anomaly classification, violent altercations and stampedes span several seconds. However, our 0.38 FPS throughput is a consequence of running 34M parameters on CPU AVX2. Our sliding temporal buffer samples 16 frames continuously, meaning we detect macro-motion patterns accurately. In Phase 4.4, compiling DirectML GPU execution providers will accelerate throughput to &gt; 15 FPS."</p>

    <p><strong>Scenario 2: The Cynical Security Auditor</strong><br>
    <em>Judge:</em> "If a hacker gains physical access to a surveillance PC, can they forge fake emergency dispatches into your backend?"<br>
    <em>Winning Team Response (Presenter 2):</em> "Absolutely not. In our Phase 4.3.5.1 security trust boundary audit, we proved that desktop client binaries contain zero HMAC secrets. Any payload submitted by a client is strictly stripped of emergency flags and demoted by Express middleware to an unverified 'manual_entry' state, requiring human operator confirmation before dispatch."</p>

    <p><strong>Scenario 3: The Deployment Pragmatist</strong><br>
    <em>Judge:</em> "Why should a mall or airport invest in SentinelX instead of established giants like Milestone or Genetec?"<br>
    <em>Winning Team Response (Presenter 1):</em> "Traditional enterprise VMS platforms charge expensive proprietary licensing fees and lack native edge multi-modal threat classification. SentinelX is edge-native, open-architecture, costs a fraction of proprietary systems, and eliminates the $90,000/year cloud bandwidth overhead of cloud-first surveillance."</p>
  </div>
</div>
"""
    return wrap_html("MERNOVA // Team Preparation Handbook", content)

if __name__ == "__main__":
    html = generate_team_handbook_html()
    out_path = os.path.join(os.path.dirname(__file__), "MERNOVA_Team_Preparation_Handbook.html")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"Generated {out_path} ({len(html)} bytes)")
