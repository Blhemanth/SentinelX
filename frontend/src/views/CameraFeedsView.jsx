// SentinelX Web - Surveillance Feeds View
import React, { useState, useEffect, useRef } from 'react';
import {
  Camera,
  Video,
  Radio,
  Sliders,
  CheckCircle,
  AlertCircle,
  Volume2,
  Maximize2,
  RefreshCw,
  Play,
  Square,
  Activity,
} from 'lucide-react';

export const CameraFeedsView = () => {
  const [showBBoxes, setShowBBoxes] = useState(true);
  const [phoneIp, setPhoneIp] = useState('http://192.168.1.100:8080/video');
  const [phoneConnected, setPhoneConnected] = useState(false);
  const [audioLevel, setAudioLevel] = useState(42);

  const cam1CanvasRef = useRef(null);
  const cam2CanvasRef = useRef(null);
  const audioCanvasRef = useRef(null);

  // Live Canvas Render for CAM-001
  useEffect(() => {
    const canvas = cam1CanvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    let frameId;
    let scanline = 0;
    let targetX = 0.35;
    let dir = 0.002;

    const render = () => {
      const w = canvas.width;
      const h = canvas.height;

      // Dark background
      ctx.fillStyle = '#05080E';
      ctx.fillRect(0, 0, w, h);

      // Perspective Grid
      ctx.strokeStyle = 'rgba(0, 217, 217, 0.08)';
      ctx.lineWidth = 1;
      for (let x = 0; x < w; x += 32) {
        ctx.beginPath();
        ctx.moveTo(x, 0);
        ctx.lineTo(x, h);
        ctx.stroke();
      }
      for (let y = 0; y < h; y += 32) {
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(w, y);
        ctx.stroke();
      }

      // Moving Subject
      targetX += dir;
      if (targetX > 0.6 || targetX < 0.25) dir = -dir;

      // Draw bounding box if enabled
      if (showBBoxes) {
        const bx = targetX * w;
        const by = 0.3 * h;
        const bw = 0.22 * w;
        const bh = 0.45 * h;

        ctx.strokeStyle = 'rgba(0, 217, 217, 0.85)';
        ctx.lineWidth = 2;
        ctx.strokeRect(bx, by, bw, bh);

        ctx.fillStyle = 'rgba(0, 217, 217, 0.1)';
        ctx.fillRect(bx, by, bw, bh);

        // Label
        ctx.fillStyle = '#00D9D9';
        ctx.fillRect(bx, by - 20, 140, 20);
        ctx.fillStyle = '#000000';
        ctx.font = 'bold 11px JetBrains Mono, monospace';
        ctx.fillText('PERSON [94.2%]', bx + 5, by - 6);
      }

      // Scanline
      scanline = (scanline + 2) % h;
      ctx.strokeStyle = 'rgba(0, 217, 217, 0.2)';
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.moveTo(0, scanline);
      ctx.lineTo(w, scanline);
      ctx.stroke();

      // OSD
      ctx.fillStyle = '#00D9D9';
      ctx.font = '11px JetBrains Mono, monospace';
      ctx.fillText('CAM-001 [CONTROL ROOM LAPTOP] // 1080p 30FPS', 14, 24);
      ctx.fillText('INFERENCE: LOCAL ONNX DIRECTML // LATENCY: 14ms', 14, 40);

      frameId = requestAnimationFrame(render);
    };

    render();
    return () => cancelAnimationFrame(frameId);
  }, [showBBoxes]);

  // Live Canvas Render for CAM-002
  useEffect(() => {
    const canvas = cam2CanvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    let frameId;
    let scanline = 0;

    const render = () => {
      const w = canvas.width;
      const h = canvas.height;

      ctx.fillStyle = '#070A10';
      ctx.fillRect(0, 0, w, h);

      // Radar style circular reticle
      ctx.strokeStyle = 'rgba(71, 123, 255, 0.15)';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.arc(w / 2, h / 2, 80, 0, Math.PI * 2);
      ctx.arc(w / 2, h / 2, 140, 0, Math.PI * 2);
      ctx.stroke();

      // Moving Scanline
      scanline = (scanline + 1.5) % h;
      ctx.strokeStyle = 'rgba(71, 123, 255, 0.2)';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(0, scanline);
      ctx.lineTo(w, scanline);
      ctx.stroke();

      // OSD
      ctx.fillStyle = '#477BFF';
      ctx.font = '11px JetBrains Mono, monospace';
      ctx.fillText('CAM-002 [FIELD SMARTPHONE // RTSP IP STREAM]', 14, 24);
      ctx.fillText(
        phoneConnected ? 'STREAMING ACTIVE // 720p 30FPS' : 'IP READY // WAITING FOR CLIENT',
        14,
        40
      );

      frameId = requestAnimationFrame(render);
    };

    render();
    return () => cancelAnimationFrame(frameId);
  }, [phoneConnected]);

  // Audio spectrum visualizer animation
  useEffect(() => {
    const canvas = audioCanvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    let frameId;

    const render = () => {
      const w = canvas.width;
      const h = canvas.height;

      ctx.fillStyle = '#080C16';
      ctx.fillRect(0, 0, w, h);

      const barCount = 32;
      const barWidth = w / barCount;

      for (let i = 0; i < barCount; i++) {
        const randH = Math.sin(Date.now() * 0.005 + i * 0.4) * 0.3 + 0.4 + Math.random() * 0.2;
        const barH = randH * (h - 8);
        const x = i * barWidth;
        const y = h - barH;

        const grad = ctx.createLinearGradient(0, y, 0, h);
        grad.addColorStop(0, '#00D9D9');
        grad.addColorStop(1, '#477BFF');

        ctx.fillStyle = grad;
        ctx.fillRect(x + 2, y, barWidth - 4, barH);
      }

      frameId = requestAnimationFrame(render);
    };

    render();
    return () => cancelAnimationFrame(frameId);
  }, []);

  return (
    <div className="p-6 space-y-6 max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <h1 className="text-2xl font-black font-display tracking-wider text-white">
              SURVEILLANCE SENSOR GRID
            </h1>
            <span className="badge badge-normal text-[10px]">2 ACTIVE CHANNELS</span>
          </div>
          <p className="text-xs font-mono text-sentinel-muted">
            Multi-Node Audio-Visual Surveillance Feeds (CAM-001 Webcam &amp; CAM-002 Mobile IP).
          </p>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={() => setShowBBoxes(!showBBoxes)}
            className={`btn-secondary text-xs py-1.5 px-3 ${
              showBBoxes ? 'text-sentinel-cyan border-sentinel-cyan/40' : 'text-sentinel-muted'
            }`}
          >
            <span>BOUNDING BOXES: {showBBoxes ? 'ENABLED' : 'HIDDEN'}</span>
          </button>
        </div>
      </div>

      {/* Dual Video Feed Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* CAM-001 (Control Room Laptop Camera) */}
        <div className="sentinel-card p-4 space-y-3">
          <div className="flex items-center justify-between text-xs font-mono">
            <span className="font-bold text-white flex items-center gap-2">
              <Camera className="w-4 h-4 text-sentinel-cyan" />
              CAM-001 // PRIMARY CONTROL ROOM
            </span>
            <span className="badge badge-normal text-[10px] text-sentinel-success">LIVE (ONNX INT8)</span>
          </div>

          <div className="relative aspect-video rounded-lg overflow-hidden border border-sentinel-border bg-black shadow-inner">
            <canvas ref={cam1CanvasRef} width={640} height={360} className="w-full h-full block" />
          </div>

          <div className="grid grid-cols-3 gap-2 text-[10px] font-mono text-sentinel-muted pt-1">
            <div className="p-2 rounded bg-sentinel-bg border border-sentinel-border">
              <span className="block text-sentinel-muted">FPS</span>
              <span className="text-sentinel-success font-bold">30.0 FPS</span>
            </div>
            <div className="p-2 rounded bg-sentinel-bg border border-sentinel-border">
              <span className="block text-sentinel-muted">INFERENCE</span>
              <span className="text-sentinel-cyan font-bold">14 MS</span>
            </div>
            <div className="p-2 rounded bg-sentinel-bg border border-sentinel-border">
              <span className="block text-sentinel-muted">SOURCE</span>
              <span className="text-white font-bold">DIRECTSHOW</span>
            </div>
          </div>
        </div>

        {/* CAM-002 (Patrol Smartphone IP Stream) */}
        <div className="sentinel-card p-4 space-y-3">
          <div className="flex items-center justify-between text-xs font-mono">
            <span className="font-bold text-white flex items-center gap-2">
              <Video className="w-4 h-4 text-sentinel-blue" />
              CAM-002 // FIELD PATROL SMARTPHONE
            </span>
            <span className="badge badge-normal text-[10px] text-sentinel-blue">
              {phoneConnected ? 'STREAMING' : 'IP READY'}
            </span>
          </div>

          <div className="relative aspect-video rounded-lg overflow-hidden border border-sentinel-border bg-black shadow-inner">
            <canvas ref={cam2CanvasRef} width={640} height={360} className="w-full h-full block" />
          </div>

          {/* IP Stream Configuration */}
          <div className="p-2.5 rounded-lg bg-sentinel-bg border border-sentinel-border space-y-2">
            <div className="flex gap-2">
              <input
                type="text"
                value={phoneIp}
                onChange={(e) => setPhoneIp(e.target.value)}
                placeholder="http://192.168.1.x:8080/video"
                className="flex-1 px-2.5 py-1.5 bg-sentinel-card border border-sentinel-border rounded text-xs font-mono text-white focus:outline-none focus:border-sentinel-cyan"
              />
              <button
                type="button"
                onClick={() => setPhoneConnected(!phoneConnected)}
                className={`px-3 py-1.5 rounded text-xs font-mono font-bold transition-all ${
                  phoneConnected
                    ? 'bg-sentinel-critical/20 text-sentinel-critical border border-sentinel-critical/40'
                    : 'btn-police'
                }`}
              >
                {phoneConnected ? 'DISCONNECT' : 'CONNECT IP'}
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Global Acoustic Spectrum Monitor */}
      <div className="sentinel-card p-5 space-y-3">
        <div className="flex items-center justify-between text-xs font-mono">
          <span className="font-bold text-white flex items-center gap-2">
            <Volume2 className="w-4 h-4 text-sentinel-cyan" />
            OMNI-DIRECTIONAL ACOUSTIC SENSOR SPECTRUM (32 BANDS)
          </span>
          <span className="text-sentinel-success text-xs">ACOUSTIC TRIAGE READY // TRIGGER: "HELP, HELP"</span>
        </div>

        <div className="h-14 rounded-lg overflow-hidden border border-sentinel-border bg-[#080C16]">
          <canvas ref={audioCanvasRef} width={800} height={56} className="w-full h-full block" />
        </div>
      </div>
    </div>
  );
};
