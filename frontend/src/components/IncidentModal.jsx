// SentinelX Web - Incident Details & CCTV Telemetry Modal
import React, { useState, useEffect, useRef } from 'react';
import { useAuth } from '../context/AuthContext';
import { logsApi } from '../api/client';
import {
  X,
  ShieldAlert,
  MapPin,
  Camera,
  Volume2,
  CheckCircle,
  Siren,
  Send,
} from 'lucide-react';

export const IncidentModal = ({ incident, onClose, onUpdated }) => {
  const { isPolice, isAnalyst, isAdmin } = useAuth();
  const [currentIncident, setCurrentIncident] = useState(incident);
  const [dispatchStatus, setDispatchStatus] = useState(incident?.dispatchStatus || 'unassigned');
  const [policeNotes, setPoliceNotes] = useState(incident?.policeNotes || '');
  const [assignedTo, setAssignedTo] = useState(incident?.assignedTo || 'Unit 104 (Officer Vance)');
  const [loadingAction, setLoadingAction] = useState(false);
  const [statusMsg, setStatusMsg] = useState(null);

  const canvasRef = useRef(null);
  const waveformRef = useRef(null);

  useEffect(() => {
    setCurrentIncident(incident);
    setDispatchStatus(incident?.dispatchStatus || 'unassigned');
    setPoliceNotes(incident?.policeNotes || '');
    setAssignedTo(incident?.assignedTo || 'Unit 104 (Officer Vance)');
  }, [incident]);

  // Simulated CCTV Render Loop with Bounding Box and Scanline
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    let animationFrameId;
    let scanlineY = 0;

    const render = () => {
      const w = canvas.width;
      const h = canvas.height;

      // Dark Surveillance Camera Backdrop
      ctx.fillStyle = '#060B12';
      ctx.fillRect(0, 0, w, h);

      // Grid Overlay
      ctx.strokeStyle = 'rgba(0, 217, 217, 0.08)';
      ctx.lineWidth = 1;
      for (let x = 0; x < w; x += 30) {
        ctx.beginPath();
        ctx.moveTo(x, 0);
        ctx.lineTo(x, h);
        ctx.stroke();
      }
      for (let y = 0; y < h; y += 30) {
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(w, y);
        ctx.stroke();
      }

      // Simulated Threat Target Bounding Box
      const bbox = currentIncident?.boundingBox || { x: 0.28, y: 0.22, w: 0.44, h: 0.54 };
      const clampedX = Math.max(0, Math.min(1, bbox.x || 0));
      const clampedY = Math.max(0, Math.min(1, bbox.y || 0));
      const renderW = Math.max(0, Math.min(bbox.w || 0, 1 - clampedX));
      const renderH = Math.max(0, Math.min(bbox.h || 0, 1 - clampedY));
      const bx = clampedX * w;
      const by = clampedY * h;
      const bw = renderW * w;
      const bh = renderH * h;

      const isCritical = currentIncident?.severity === 'critical';
      const boxColor = isCritical ? 'rgba(255, 82, 104, 0.9)' : 'rgba(0, 217, 217, 0.9)';
      const fillColor = isCritical ? 'rgba(255, 82, 104, 0.12)' : 'rgba(0, 217, 217, 0.08)';

      ctx.fillStyle = fillColor;
      ctx.fillRect(bx, by, bw, bh);

      ctx.strokeStyle = boxColor;
      ctx.lineWidth = 2;
      ctx.strokeRect(bx, by, bw, bh);

      // Target Corner Reticles
      const cornerLen = 14;
      ctx.lineWidth = 3;
      // Top-Left
      ctx.beginPath();
      ctx.moveTo(bx, by + cornerLen);
      ctx.lineTo(bx, by);
      ctx.lineTo(bx + cornerLen, by);
      ctx.stroke();
      // Top-Right
      ctx.beginPath();
      ctx.moveTo(bx + bw - cornerLen, by);
      ctx.lineTo(bx + bw, by);
      ctx.lineTo(bx + bw, by + cornerLen);
      ctx.stroke();
      // Bottom-Left
      ctx.beginPath();
      ctx.moveTo(bx, by + bh - cornerLen);
      ctx.lineTo(bx, by + bh);
      ctx.lineTo(bx + cornerLen, by + bh);
      ctx.stroke();
      // Bottom-Right
      ctx.beginPath();
      ctx.moveTo(bx + bw - cornerLen, by + bh);
      ctx.lineTo(bx + bw, by + bh);
      ctx.lineTo(bx + bw, by + bh - cornerLen);
      ctx.stroke();

      // Bounding Box Label
      ctx.fillStyle = boxColor;
      ctx.fillRect(bx, by - 22, 180, 22);
      ctx.fillStyle = '#000000';
      ctx.font = 'bold 11px JetBrains Mono, monospace';
      const confText = `${currentIncident?.threatClass || 'ANOMALY'} [${((currentIncident?.confidence || 0.95) * 100).toFixed(1)}%]`;
      ctx.fillText(confText, bx + 6, by - 7);

      // Moving Scanline
      scanlineY = (scanlineY + 1.5) % h;
      ctx.strokeStyle = 'rgba(0, 217, 217, 0.25)';
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.moveTo(0, scanlineY);
      ctx.lineTo(w, scanlineY);
      ctx.stroke();

      // Telemetry OSD
      ctx.fillStyle = '#00D9D9';
      ctx.font = '10px JetBrains Mono, monospace';
      ctx.fillText(`CCTV FEED: ${currentIncident?.cameraId || 'CAM-001'} // REC [LIVE]`, 12, 20);
      ctx.fillText(`LATENCY: ${currentIncident?.inferenceLatencyMs || 14}ms // INT8 ONNX`, 12, 34);

      ctx.fillStyle = '#FF5268';
      ctx.fillText(`STATUS: ${(currentIncident?.dispatchStatus || 'UNASSIGNED').toUpperCase()}`, w - 160, 20);

      animationFrameId = requestAnimationFrame(render);
    };

    render();
    return () => cancelAnimationFrame(animationFrameId);
  }, [currentIncident]);

  // Audio Spectral Waveform Renderer
  useEffect(() => {
    const canvas = waveformRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    const w = canvas.width;
    const h = canvas.height;

    ctx.fillStyle = '#080C16';
    ctx.fillRect(0, 0, w, h);

    const freqs = currentIncident?.audioFrequencies?.length
      ? currentIncident.audioFrequencies
      : [0.2, 0.4, 0.7, 0.9, 0.95, 0.85, 0.6, 0.4, 0.3, 0.5, 0.8, 0.92, 0.88, 0.65, 0.45, 0.3, 0.2];

    const barWidth = w / freqs.length;
    freqs.forEach((val, i) => {
      const barH = val * (h - 10);
      const x = i * barWidth;
      const y = h - barH;

      const grad = ctx.createLinearGradient(0, y, 0, h);
      grad.addColorStop(0, '#00D9D9');
      grad.addColorStop(1, '#477BFF');

      ctx.fillStyle = grad;
      ctx.fillRect(x + 2, y, barWidth - 4, barH);
    });
  }, [currentIncident]);

  const handleUpdateDispatch = async (newStatus) => {
    if (!currentIncident?._id) return;
    setLoadingAction(true);
    setStatusMsg(null);
    try {
      const res = await logsApi.updateDispatch(currentIncident._id, {
        dispatchStatus: newStatus || dispatchStatus,
        assignedTo,
        policeNotes,
      });
      if (res.success && res.data) {
        setCurrentIncident(res.data);
        setDispatchStatus(res.data.dispatchStatus);
        setStatusMsg(`Dispatch status updated to "${res.data.dispatchStatus.toUpperCase()}"`);
        if (onUpdated) onUpdated(res.data);
      }
    } catch (err) {
      setStatusMsg(`Error: ${err.message}`);
    } finally {
      setLoadingAction(false);
    }
  };

  const handleAcknowledge = async () => {
    if (!currentIncident?._id) return;
    setLoadingAction(true);
    try {
      const res = await logsApi.acknowledgeLog(currentIncident._id);
      if (res.success && res.data) {
        setCurrentIncident(res.data);
        setStatusMsg('Incident acknowledged successfully.');
        if (onUpdated) onUpdated(res.data);
      }
    } catch (err) {
      setStatusMsg(`Error: ${err.message}`);
    } finally {
      setLoadingAction(false);
    }
  };

  if (!incident) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md">
      <div className="w-full max-w-4xl max-h-[92vh] flex flex-col rounded-xl sentinel-card border-sentinel-cyan/30 shadow-[0_0_50px_rgba(0,0,0,0.9)] overflow-hidden">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-sentinel-border bg-sentinel-sidebar">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-lg bg-sentinel-critical/20 border border-sentinel-critical/30 text-sentinel-critical">
              <ShieldAlert className="w-5 h-5" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h2 className="text-base font-bold text-white font-display">
                  {currentIncident.threatClass}
                </h2>
                <span
                  className={`badge ${
                    currentIncident.severity === 'critical'
                      ? 'badge-critical'
                      : currentIncident.severity === 'high'
                      ? 'badge-high'
                      : 'badge-normal'
                  }`}
                >
                  {currentIncident.severity?.toUpperCase()}
                </span>
                {currentIncident.detectionStatus === 'low_confidence_review' && (
                  <span className="badge font-mono text-[10px] bg-sentinel-warning/20 text-sentinel-warning border border-sentinel-warning/40">
                    REVIEW NEEDED
                  </span>
                )}
                {(currentIncident.detectionStatus === 'subprocess_fallback' || currentIncident.detectionSource === 'subprocess_fallback') && (
                  <span className="badge font-mono text-[10px] bg-yellow-500/20 text-yellow-300 border border-yellow-500/40">
                    SUBPROCESS FALLBACK
                  </span>
                )}
                {(currentIncident.detectionStatus === 'legacy_unclassified' || currentIncident.detectionSource === 'legacy_unspecified') && (
                  <span className="badge font-mono text-[10px] bg-gray-700/50 text-gray-400 border border-gray-600/50">
                    LEGACY RECORD
                  </span>
                )}
                <span className="badge badge-normal font-mono text-[10px]">
                  ID: {currentIncident._id?.slice(-6) || 'LIVE'}
                </span>
              </div>
              <p className="text-xs font-mono text-sentinel-muted flex items-center gap-2 mt-0.5">
                <MapPin className="w-3.5 h-3.5 text-sentinel-cyan" />
                {currentIncident.location || 'Perimeter Sector Alpha'}
                <span>•</span>
                <Camera className="w-3.5 h-3.5 text-sentinel-blue" />
                {currentIncident.cameraId}
              </p>
            </div>
          </div>

          <button
            onClick={onClose}
            className="p-1.5 rounded-lg text-sentinel-muted hover:text-white hover:bg-sentinel-card transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Modal Body */}
        <div className="flex-1 overflow-y-auto p-6 space-y-6">
          {/* Status Message Banner */}
          {statusMsg && (
            <div className="p-3 rounded-lg bg-sentinel-cyan/10 border border-sentinel-cyan/30 text-xs font-mono text-sentinel-cyan flex items-center justify-between">
              <span>{statusMsg}</span>
              <button onClick={() => setStatusMsg(null)} className="text-sentinel-muted hover:text-white">
                ✕
              </button>
            </div>
          )}

          {/* Grid Layout: CCTV Player + Telemetry Details */}
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
            {/* Left 7 cols: CCTV Canvas */}
            <div className="lg:col-span-7 space-y-3">
              <div className="text-xs font-mono text-sentinel-muted flex items-center justify-between">
                <span>INCIDENT FRAME CAPTURE &amp; BOUNDING BOX</span>
                <span className="text-sentinel-success flex items-center gap-1 font-bold">
                  <span className="w-2 h-2 rounded-full bg-sentinel-success animate-ping" />
                  REPLAY ACTIVE
                </span>
              </div>
              <div className="relative rounded-lg overflow-hidden border border-sentinel-border aspect-video bg-black shadow-inner">
                <canvas ref={canvasRef} width={640} height={360} className="w-full h-full block" />
              </div>

              {/* Spectral Waveform */}
              <div className="p-3 rounded-lg bg-sentinel-bg border border-sentinel-border">
                <div className="flex items-center justify-between text-[11px] font-mono text-sentinel-muted mb-2">
                  <span className="flex items-center gap-1.5">
                    <Volume2 className="w-3.5 h-3.5 text-sentinel-cyan" />
                    SPECTRAL ACOUSTIC SIGNATURE ({currentIncident.audioDecibels || 89.2} dB)
                  </span>
                  <span className="text-sentinel-cyan">
                    {currentIncident.audioTranscript ? 'SPEECH DISTRESS DETECTED' : 'NORMAL AUDIO'}
                  </span>
                </div>
                <canvas ref={waveformRef} width={400} height={48} className="w-full h-12 block rounded" />
                {currentIncident.audioTranscript && (
                  <div className="mt-2 text-xs font-mono text-sentinel-warning bg-sentinel-warning/10 p-2 rounded border border-sentinel-warning/20">
                    "{currentIncident.audioTranscript}"
                  </div>
                )}
              </div>
            </div>

            {/* Right 5 cols: Telemetry & Actions */}
            <div className="lg:col-span-5 space-y-4">
              {/* Telemetry Key-Value Card */}
              <div className="p-4 rounded-lg bg-sentinel-bg border border-sentinel-border space-y-2.5 text-xs font-mono">
                <div className="text-[10px] tracking-widest text-sentinel-muted uppercase border-b border-sentinel-border pb-1">
                  FORENSIC TELEMETRY
                </div>
                <div className="flex justify-between">
                  <span className="text-sentinel-muted">ML Confidence:</span>
                  <span className="text-white font-bold">
                    {((currentIncident.confidence || 0.95) * 100).toFixed(2)}%
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-sentinel-muted">Timestamp:</span>
                  <span className="text-sentinel-text">
                    {currentIncident.frameTimestamp ? new Date(currentIncident.frameTimestamp).toLocaleString() : 'N/A'}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-sentinel-muted">Model Pipeline:</span>
                  <span className="text-sentinel-cyan font-bold">
                    {currentIncident.modelVersion || '1.0.0-ONNX-INT8'}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-sentinel-muted">Inference Latency:</span>
                  <span className="text-sentinel-success font-bold">
                    {currentIncident.inferenceLatencyMs || 14} ms
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-sentinel-muted">Detection Status:</span>
                  <span className={`font-bold ${
                    currentIncident.detectionStatus === 'low_confidence_review'
                      ? 'text-sentinel-warning'
                      : currentIncident.detectionStatus === 'subprocess_fallback'
                      ? 'text-yellow-400'
                      : currentIncident.detectionStatus === 'legacy_unclassified'
                      ? 'text-sentinel-muted'
                      : currentIncident.detectionStatus === 'anomaly_detected'
                      ? 'text-sentinel-critical'
                      : 'text-sentinel-success'
                  }`}>
                    {(currentIncident.detectionStatus || 'legacy_unclassified').replace(/_/g, ' ').toUpperCase()}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-sentinel-muted">Detection Source:</span>
                  <span className="text-sentinel-text">
                    {(currentIncident.detectionSource || 'ml_real').replace(/_/g, ' ').toUpperCase()}
                  </span>
                </div>
                <div className="flex justify-between items-center pt-1 border-t border-sentinel-border">
                  <span className="text-sentinel-muted">Triage Acknowledged:</span>
                  {currentIncident.isAcknowledged ? (
                    <span className="badge badge-normal text-[10px] text-sentinel-success flex items-center gap-1 font-bold">
                      <CheckCircle className="w-3 h-3" />
                      YES
                    </span>
                  ) : (
                    <button
                      onClick={handleAcknowledge}
                      disabled={loadingAction || (!isAnalyst && !isAdmin)}
                      className="px-2 py-0.5 rounded bg-sentinel-warning/20 border border-sentinel-warning/40 text-sentinel-warning text-[10px] hover:bg-sentinel-warning/30 font-bold"
                    >
                      ACKNOWLEDGE NOW
                    </button>
                  )}
                </div>
              </div>

              {/* Police Dispatch Console */}
              <div className="p-4 rounded-lg bg-sentinel-bg border border-sentinel-blue/40 space-y-3">
                <div className="flex items-center justify-between text-xs font-mono font-bold text-sentinel-blue">
                  <span className="flex items-center gap-1.5">
                    <Siren className="w-4 h-4 text-sentinel-blue animate-pulse" />
                    POLICE TACTICAL DISPATCH
                  </span>
                  <span className="text-[10px] text-sentinel-muted uppercase">
                    STATUS: {dispatchStatus.replace('_', ' ')}
                  </span>
                </div>

                {/* Dispatch Stepper Buttons */}
                <div className="grid grid-cols-2 gap-2 text-xs font-mono">
                  <button
                    onClick={() => handleUpdateDispatch('assigned_police')}
                    disabled={loadingAction || (!isPolice && !isAdmin)}
                    className={`p-2 rounded border text-left transition-colors ${
                      dispatchStatus === 'assigned_police'
                        ? 'bg-sentinel-blue/30 border-sentinel-blue text-sentinel-blue font-bold'
                        : 'bg-sentinel-card border-sentinel-border text-sentinel-muted hover:border-sentinel-muted'
                    }`}
                  >
                    1. ASSIGN POLICE
                  </button>
                  <button
                    onClick={() => handleUpdateDispatch('en_route')}
                    disabled={loadingAction || (!isPolice && !isAdmin)}
                    className={`p-2 rounded border text-left transition-colors ${
                      dispatchStatus === 'en_route'
                        ? 'bg-sentinel-warning/30 border-sentinel-warning text-sentinel-warning font-bold'
                        : 'bg-sentinel-card border-sentinel-border text-sentinel-muted hover:border-sentinel-muted'
                    }`}
                  >
                    2. EN ROUTE
                  </button>
                  <button
                    onClick={() => handleUpdateDispatch('on_scene')}
                    disabled={loadingAction || (!isPolice && !isAdmin)}
                    className={`p-2 rounded border text-left transition-colors ${
                      dispatchStatus === 'on_scene'
                        ? 'bg-purple-600/30 border-purple-400 text-purple-300 font-bold'
                        : 'bg-sentinel-card border-sentinel-border text-sentinel-muted hover:border-sentinel-muted'
                    }`}
                  >
                    3. ON SCENE
                  </button>
                  <button
                    onClick={() => handleUpdateDispatch('resolved')}
                    disabled={loadingAction || (!isPolice && !isAdmin)}
                    className={`p-2 rounded border text-left transition-colors ${
                      dispatchStatus === 'resolved'
                        ? 'bg-sentinel-success/30 border-sentinel-success text-sentinel-success font-bold'
                        : 'bg-sentinel-card border-sentinel-border text-sentinel-muted hover:border-sentinel-muted'
                    }`}
                  >
                    4. MARK SECURE
                  </button>
                </div>

                {/* Dispatch Form Inputs */}
                <div className="space-y-2 pt-2">
                  <div>
                    <label className="block text-[10px] font-mono text-sentinel-muted mb-1">
                      ASSIGNED POLICE UNIT
                    </label>
                    <input
                      type="text"
                      value={assignedTo}
                      onChange={(e) => setAssignedTo(e.target.value)}
                      placeholder="e.g. Unit 104 (Officer Vance)"
                      className="w-full px-2.5 py-1.5 bg-sentinel-card border border-sentinel-border rounded text-xs font-mono text-white focus:outline-none focus:border-sentinel-blue"
                    />
                  </div>

                  <div>
                    <label className="block text-[10px] font-mono text-sentinel-muted mb-1">
                      POLICE LOG NOTES
                    </label>
                    <textarea
                      rows={2}
                      value={policeNotes}
                      onChange={(e) => setPoliceNotes(e.target.value)}
                      placeholder="Enter tactical observations, suspect apprehension, or resolution notes..."
                      className="w-full px-2.5 py-1.5 bg-sentinel-card border border-sentinel-border rounded text-xs font-mono text-white focus:outline-none focus:border-sentinel-blue"
                    />
                  </div>

                  <button
                    onClick={() => handleUpdateDispatch(dispatchStatus)}
                    disabled={loadingAction || (!isPolice && !isAdmin)}
                    className="w-full btn-primary justify-center py-2 text-xs font-mono"
                  >
                    <Send className="w-3.5 h-3.5" />
                    <span>SAVE DISPATCH STATUS &amp; NOTES</span>
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="px-6 py-3 border-t border-sentinel-border bg-sentinel-sidebar flex items-center justify-between text-xs font-mono">
          <span className="text-sentinel-muted">SENTINELX MERN + FLUTTER REAL-TIME SYNC</span>
          <button
            onClick={onClose}
            className="btn-secondary text-xs py-1 px-4"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
};
