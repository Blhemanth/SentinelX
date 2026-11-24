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
      ctx.strokeStyle = 'rgba(0, 240, 255, 0.06)';
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

        ctx.strokeStyle = 'rgba(0, 240, 255, 0.8)';
        ctx.lineWidth = 2;
        ctx.strokeRect(bx, by, bw, bh);

        ctx.fillStyle = 'rgba(0, 240, 255, 0.08)';
        ctx.fillRect(bx, by, bw, bh);

        // Label
        ctx.fillStyle = '#00F0FF';
        ctx.fillRect(bx, by - 20, 140, 20);
        ctx.fillStyle = '#000000';
        ctx.font = 'bold 11px JetBrains Mono, monospace';
        ctx.fillText('PERSON [94.2%]', bx + 5, by - 6);
      }

      // Scanline
      scanline = (scanline + 2) % h;
      ctx.strokeStyle = 'rgba(0, 240, 255, 0.15)';
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.moveTo(0, scanline);
      ctx.lineTo(w, scanline);
      ctx.stroke();

      // OSD
      ctx.fillStyle = '#00F0FF';
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
      ctx.strokeStyle = 'rgba(56, 189, 248, 0.1)';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.arc(w / 2, h / 2, 80, 0, Math.PI * 2);
      ctx.arc(w / 2, h / 2, 140, 0, Math.PI * 2);
      ctx.stroke();

      // Moving Scanline
      scanline = (scanline + 1.5) % h;
      ctx.strokeStyle = 'rgba(56, 189, 248, 0.15)';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(0, scanline);
      ctx.lineTo(w, scanline);
      ctx.stroke();

      // OSD
      ctx.fillStyle = '#38BDF8';
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

      ctx.fillStyle = '#0A0D15';
      ctx.fillRect(0, 0, w, h);

      const barCount = 32;
      const barWidth = w / barCount;

      for (let i = 0; i < barCount; i++) {
        const randH = Math.sin(Date.now() * 0.005 + i * 0.4) * 0.3 + 0.4 + Math.random() * 0.2;
        const barH = randH * (h - 8);
        const x = i * barWidth;
        const y = h - barH;

        const grad = ctx.createLinearGradient(0, y, 0, h);
        grad.addColorStop(0, '#00F0FF');
        grad.addColorStop(1, '#3B82F6');

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
          <h1 className="text-2xl font-black font-display tracking-wider text-white">
            SURVEILLANCE SENSOR GRID
          </h1>
          <p className="text-xs font-mono text-gray-400">
            Multi-Node Audio-Visual Surveillance Feeds (CAM-001 Webcam &amp; CAM-002 Mobile IP).
          </p>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={() => setShowBBoxes(!showBBoxes)}
            className={`px-3 py-1.5 rounded-lg text-xs font-mono border transition-all ${
              showBBoxes
                ? 'bg-cyan-500/10 border-cyan-500/30 text-[#00F0FF]'
                : 'bg-gray-800 border-gray-700 text-gray-400'
            }`}
          >
            <span>BOUNDING BOXES: {showBBoxes ? 'ENABLED' : 'HIDDEN'}</span>
          </button>
        </div>
      </div>

      {/* Dual Video Feed Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* CAM-001 (Control Room Laptop Camera) */}
        <div className="glass-panel p-4 border border-gray-800 space-y-3">
          <div className="flex items-center justify-between text-xs font-mono">
            <span className="font-bold text-white flex items-center gap-2">
              <Camera className="w-4 h-4 text-[#00F0FF]" />
              CAM-001 // PRIMARY CONTROL ROOM
            </span>
            <span className="badge badge-normal text-[10px] text-[#34D399]">LIVE (ONNX INT8)</span>
          </div>

          <div className="relative aspect-video rounded-lg overflow-hidden border border-gray-800 bg-black">
            <canvas ref={cam1CanvasRef} width={640} height={360} className="w-full h-full block" />
          </div>

          <div className="grid grid-cols-3 gap-2 text-[10px] font-mono text-gray-400 pt-1">
            <div className="p-2 rounded bg-black/40 border border-gray-800">
              <span className="block text-gray-500">FPS</span>
              <span className="text-[#34D399] font-bold">30.0 FPS</span>
            </div>
            <div className="p-2 rounded bg-black/40 border border-gray-800">
              <span className="block text-gray-500">INFERENCE</span>
              <span className="text-[#00F0FF] font-bold">14 MS</span>
            </div>
            <div className="p-2 rounded bg-black/40 border border-gray-800">
              <span className="block text-gray-500">SOURCE</span>
              <span className="text-white font-bold">DIRECTSHOW</span>
            </div>
          </div>
        </div>

        {/* CAM-002 (Patrol Smartphone IP Stream) */}
        <div className="glass-panel p-4 border border-gray-800 space-y-3">
          <div className="flex items-center justify-between text-xs font-mono">
            <span className="font-bold text-white flex items-center gap-2">
              <Video className="w-4 h-4 text-[#38BDF8]" />
              CAM-002 // FIELD PATROL SMARTPHONE
            </span>
            <span className="badge badge-normal text-[10px] text-[#38BDF8]">
              {phoneConnected ? 'STREAMING' : 'IP READY'}
            </span>
          </div>

          <div className="relative aspect-video rounded-lg overflow-hidden border border-gray-800 bg-black">
            <canvas ref={cam2CanvasRef} width={640} height={360} className="w-full h-full block" />
          </div>

          {/* IP Stream Configuration */}
          <div className="p-2.5 rounded-lg bg-[rgba(13,17,26,0.8)] border border-gray-800 space-y-2">
            <div className="flex gap-2">
              <input
                type="text"
                value={phoneIp}
                onChange={(e) => setPhoneIp(e.target.value)}
                placeholder="http://192.168.1.x:8080/video"
                className="flex-1 px-2.5 py-1 bg-black/60 border border-gray-700 rounded text-xs font-mono text-white focus:outline-none focus:border-cyan-400"
              />
              <button
                type="button"
                onClick={() => setPhoneConnected(!phoneConnected)}
                className={`px-3 py-1 rounded text-xs font-mono font-bold transition-all ${
                  phoneConnected
                    ? 'bg-red-500/20 text-red-300 border border-red-500/40'
                    : 'bg-blue-600 hover:bg-blue-500 text-white'
                }`}
              >
                {phoneConnected ? 'DISCONNECT' : 'CONNECT IP'}
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Global Acoustic Spectrum Monitor */}
      <div className="glass-panel p-5 border border-gray-800 space-y-3">
        <div className="flex items-center justify-between text-xs font-mono">
          <span className="font-bold text-white flex items-center gap-2">
            <Volume2 className="w-4 h-4 text-[#00F0FF]" />
            OMNI-DIRECTIONAL ACOUSTIC SENSOR SPECTRUM (32 BANDS)
          </span>
          <span className="text-[#34D399]">ACOUSTIC TRIAGE READY // TRIGGER: "HELP, HELP"</span>
        </div>

        <div className="h-14 rounded-lg overflow-hidden border border-gray-800 bg-black">
          <canvas ref={audioCanvasRef} width={800} height={56} className="w-full h-full block" />
        </div>
      </div>
    </div>
  );
};
