// SentinelX Web - Police Tactical Dispatch View
import React, { useState, useEffect } from 'react';
import { useAuth } from '../context/AuthContext';
import { logsApi } from '../api/client';
import {
  Siren,
  Shield,
  MapPin,
  Clock,
  CheckCircle2,
  Radio,
  FileText,
  Volume2,
  Car,
  AlertCircle,
  Eye,
  RefreshCw,
} from 'lucide-react';

export const PoliceView = ({ onSelectIncident }) => {
  const { user, isPolice, isAdmin } = useAuth();
  const [incidents, setIncidents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedIncident, setSelectedIncident] = useState(null);
  const [policeNotes, setPoliceNotes] = useState('');
  const [updating, setUpdating] = useState(false);
  const [feedback, setFeedback] = useState(null);

  const fetchDispatchQueue = async () => {
    try {
      const res = await logsApi.getLogs({
        limit: 20,
        page: 1,
      });
      if (res.success && res.data) {
        // Prioritize incidents that are active or in dispatch (isolate drills from CAD queue)
        const realIncidents = (res.data || []).filter(inc => inc.detectionSource !== 'drill_simulation');
        const sorted = [...realIncidents].sort((a, b) => {
          const statusOrder = { unassigned: 0, assigned_police: 1, en_route: 2, on_scene: 3, resolved: 4 };
          return (statusOrder[a.dispatchStatus] || 0) - (statusOrder[b.dispatchStatus] || 0);
        });
        setIncidents(sorted);
        if (!selectedIncident && sorted.length > 0) {
          setSelectedIncident(sorted[0]);
          setPoliceNotes(sorted[0].policeNotes || '');
        }
      }
    } catch (err) {
      console.warn('Dispatch fetch error:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchDispatchQueue();
    const interval = setInterval(fetchDispatchQueue, 5000);
    return () => clearInterval(interval);
  }, []);

  const handleStatusChange = async (targetIncident, newStatus) => {
    if (!targetIncident?._id) return;
    setUpdating(true);
    setFeedback(null);
    try {
      const res = await logsApi.updateDispatch(targetIncident._id, {
        dispatchStatus: newStatus,
        assignedTo: targetIncident.assignedTo || user?.name || 'Unit 104 (Officer Vance)',
        policeNotes,
      });

      if (res.success && res.data) {
        setSelectedIncident(res.data);
        setIncidents((prev) =>
          prev.map((item) => (item._id === res.data._id ? res.data : item))
        );
        setFeedback(`Incident updated to ${newStatus.replace('_', ' ').toUpperCase()}`);
      }
    } catch (err) {
      setFeedback(`Error: ${err.message}`);
    } finally {
      setUpdating(false);
    }
  };

  const handleSelectIncident = (inc) => {
    setSelectedIncident(inc);
    setPoliceNotes(inc.policeNotes || '');
    setFeedback(null);
  };

  const activeCount = incidents.filter((i) => i.dispatchStatus !== 'resolved').length;

  return (
    <div className="p-6 space-y-6 max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <h1 className="text-2xl font-black font-display tracking-wider text-white">
              POLICE TACTICAL DISPATCH CONSOLE
            </h1>
            <span className="badge badge-police text-[10px]">UNIT 104 ACTIVE</span>
          </div>
          <p className="text-xs font-mono text-sentinel-muted">
            Real-time CAD (Computer-Aided Dispatch) Terminal for Law Enforcement Patrol Units.
          </p>
        </div>

        <div className="flex items-center gap-3">
          <div className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-sentinel-blue/10 border border-sentinel-blue/30 text-xs font-mono text-sentinel-blue">
            <Car className="w-4 h-4 text-sentinel-blue" />
            <span>DISPATCH QUEUE: {activeCount} ACTIVE</span>
          </div>
          <button
            onClick={fetchDispatchQueue}
            className="p-2 rounded-lg bg-sentinel-card hover:bg-sentinel-elevated text-sentinel-text border border-sentinel-border transition-colors"
            title="Refresh Queue"
          >
            <RefreshCw className="w-4 h-4" />
          </button>
        </div>
      </div>

      {feedback && (
        <div className="p-3 rounded-lg bg-sentinel-blue/10 border border-sentinel-blue/30 text-xs font-mono text-sentinel-blue flex items-center justify-between">
          <span>{feedback}</span>
          <button onClick={() => setFeedback(null)} className="text-sentinel-muted hover:text-white">
            ✕
          </button>
        </div>
      )}

      {/* Main Grid: Left List (Dispatch Calls) + Right Detail (Active Dispatch Management) */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Left 5 Cols: Incident Queue */}
        <div className="lg:col-span-5 sentinel-card p-4 space-y-3">
          <div className="flex items-center justify-between border-b border-sentinel-border pb-2 text-xs font-mono">
            <span className="text-sentinel-muted font-bold uppercase">LIVE EMERGENCY CALLS</span>
            <span className="text-[10px] text-sentinel-muted">{incidents.length} INGESTED</span>
          </div>

          {loading && incidents.length === 0 ? (
            <div className="space-y-3 py-4">
              {[1, 2, 3].map((n) => (
                <div key={n} className="h-16 w-full skeleton rounded-lg" />
              ))}
            </div>
          ) : incidents.length === 0 ? (
            <div className="py-12 text-center text-sentinel-muted font-mono text-xs">
              NO ACTIVE CALLS IN DISPATCH QUEUE.
            </div>
          ) : (
            <div className="space-y-2 max-h-[600px] overflow-y-auto pr-1">
              {incidents.map((inc) => {
                const isSelected = selectedIncident?._id === inc._id;
                const isResolved = inc.dispatchStatus === 'resolved';
                const isDistress =
                  inc.threatClass?.includes('HELP') || inc.severity === 'critical';

                return (
                  <div
                    key={inc._id}
                    onClick={() => handleSelectIncident(inc)}
                    className={`p-3 rounded-lg border cursor-pointer transition-all ${
                      isSelected
                        ? 'bg-sentinel-blue/15 border-sentinel-blue shadow-[0_0_15px_rgba(71,123,255,0.25)]'
                        : isDistress && !isResolved
                        ? 'bg-sentinel-critical/10 border-sentinel-critical/40 hover:border-sentinel-critical'
                        : 'bg-sentinel-bg/60 border-sentinel-border hover:border-sentinel-muted'
                    }`}
                  >
                    <div className="flex items-center justify-between mb-1">
                      <div className="flex items-center gap-2">
                        {isDistress ? (
                          <Volume2 className="w-3.5 h-3.5 text-sentinel-critical" />
                        ) : (
                          <Siren className="w-3.5 h-3.5 text-sentinel-blue" />
                        )}
                        <span className="text-xs font-bold font-mono text-white">
                          {inc.threatClass}
                        </span>
                      </div>
                      <span
                        className={`text-[9px] font-mono px-1.5 py-0.5 rounded uppercase font-bold ${
                          isResolved
                            ? 'bg-sentinel-success/20 text-sentinel-success border border-sentinel-success/30'
                            : inc.dispatchStatus === 'en_route'
                            ? 'bg-sentinel-warning/20 text-sentinel-warning border border-sentinel-warning/30'
                            : 'bg-sentinel-critical/20 text-sentinel-critical border border-sentinel-critical/30'
                        }`}
                      >
                        {inc.dispatchStatus?.replace('_', ' ')}
                      </span>
                    </div>

                    <div className="flex items-center justify-between text-[10px] font-mono text-sentinel-muted">
                      <span className="flex items-center gap-1">
                        <MapPin className="w-3 h-3 text-sentinel-cyan" />
                        {inc.location || 'Perimeter Sector Alpha'} ({inc.cameraId})
                      </span>
                      <span>
                        {new Date(inc.frameTimestamp || inc.createdAt).toLocaleTimeString()}
                      </span>
                    </div>

                    {inc.audioTranscript && (
                      <div className="mt-1.5 text-[10px] font-mono text-sentinel-warning truncate bg-sentinel-warning/10 px-1.5 py-0.5 rounded">
                        "{inc.audioTranscript}"
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* Right 7 Cols: Active Incident Tactical Action Station */}
        <div className="lg:col-span-7 sentinel-card p-6 border-sentinel-blue/40 space-y-5">
          {selectedIncident ? (
            <>
              {/* Incident Header */}
              <div className="flex items-start justify-between border-b border-sentinel-border pb-4">
                <div>
                  <div className="flex items-center gap-2">
                    <span className="badge badge-police text-[10px]">CALL SHEET</span>
                    <h2 className="text-lg font-bold font-display text-white">
                      {selectedIncident.threatClass}
                    </h2>
                  </div>
                  <p className="text-xs font-mono text-sentinel-muted flex items-center gap-3 mt-1">
                    <span className="flex items-center gap-1">
                      <MapPin className="w-3.5 h-3.5 text-sentinel-cyan" />
                      {selectedIncident.location || 'Perimeter Sector Alpha'}
                    </span>
                    <span>•</span>
                    <span className="flex items-center gap-1">
                      <Clock className="w-3.5 h-3.5 text-sentinel-muted" />
                      {new Date(
                        selectedIncident.frameTimestamp || selectedIncident.createdAt
                      ).toLocaleTimeString()}
                    </span>
                    <span>•</span>
                    <span className="text-sentinel-cyan font-semibold">
                      Cam: {selectedIncident.cameraId}
                    </span>
                  </p>
                </div>

                <button
                  onClick={() => onSelectIncident(selectedIncident)}
                  className="btn-primary text-xs py-1.5 px-3 flex items-center gap-1.5"
                >
                  <Eye className="w-3.5 h-3.5" />
                  <span>FULL FORENSICS</span>
                </button>
              </div>

              {/* Tactical Progression Stepper */}
              <div className="space-y-2">
                <label className="block text-[11px] font-mono text-sentinel-muted uppercase tracking-wider">
                  DISPATCH ESCALATION STEPPER:
                </label>
                <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
                  {[
                    { key: 'assigned_police', label: '1. ASSIGN UNIT' },
                    { key: 'en_route', label: '2. EN ROUTE' },
                    { key: 'on_scene', label: '3. ON SCENE' },
                    { key: 'resolved', label: '4. MARK SECURE' },
                  ].map((step) => {
                    const isCurrent = selectedIncident.dispatchStatus === step.key;
                    return (
                      <button
                        key={step.key}
                        type="button"
                        onClick={() => handleStatusChange(selectedIncident, step.key)}
                        disabled={updating || (!isPolice && !isAdmin)}
                        className={`p-2.5 rounded-lg border text-xs font-mono font-bold transition-all ${
                          isCurrent
                            ? 'bg-sentinel-blue text-white border-sentinel-blue shadow-[0_0_15px_rgba(71,123,255,0.4)]'
                            : 'bg-sentinel-bg text-sentinel-muted border-sentinel-border hover:border-sentinel-muted hover:text-white'
                        }`}
                      >
                        {step.label}
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Telemetry Overview Grid */}
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-3 p-3.5 rounded-lg bg-sentinel-bg border border-sentinel-border text-xs font-mono">
                <div>
                  <span className="text-sentinel-muted block text-[10px]">CONFIDENCE</span>
                  <span className="text-white font-bold">
                    {((selectedIncident.confidence || 0.95) * 100).toFixed(1)}%
                  </span>
                </div>
                <div>
                  <span className="text-sentinel-muted block text-[10px]">ASSIGNED PATROL</span>
                  <span className="text-sentinel-blue font-bold">
                    {selectedIncident.assignedTo || 'Unit 104 (Officer Vance)'}
                  </span>
                </div>
                <div>
                  <span className="text-sentinel-muted block text-[10px]">ACOUSTIC LEVEL</span>
                  <span className="text-sentinel-cyan font-bold">
                    {selectedIncident.audioDecibels || 89.2} dB
                  </span>
                </div>
              </div>

              {/* Acoustic Transcript Alert */}
              {selectedIncident.audioTranscript && (
                <div className="p-3 rounded-lg bg-sentinel-warning/10 border border-sentinel-warning/30 text-xs font-mono text-sentinel-warning flex items-start gap-2">
                  <Volume2 className="w-4 h-4 shrink-0 mt-0.5" />
                  <div>
                    <span className="font-bold block text-[10px] uppercase text-sentinel-warning">
                      ACOUSTIC DISTRESS PHRASE RECORDED:
                    </span>
                    <span>"{selectedIncident.audioTranscript}"</span>
                  </div>
                </div>
              )}

              {/* Police Tactical Notes Field */}
              <div className="space-y-2">
                <label className="block text-xs font-mono text-sentinel-text">
                  OFFICER LOG &amp; APPREHENSION NOTES
                </label>
                <textarea
                  rows={3}
                  value={policeNotes}
                  onChange={(e) => setPoliceNotes(e.target.value)}
                  placeholder="Record tactical assessment, suspect description, perimeter containment, or final disposition..."
                  className="w-full p-3 bg-sentinel-bg border border-sentinel-border focus:border-sentinel-blue rounded-lg text-xs font-mono text-white focus:outline-none"
                />
                <button
                  type="button"
                  onClick={() =>
                    handleStatusChange(selectedIncident, selectedIncident.dispatchStatus)
                  }
                  disabled={updating || (!isPolice && !isAdmin)}
                  className="btn-police py-2 px-4 text-xs font-mono"
                >
                  <span>SAVE NOTES TO CAD DISPATCH DATABASE</span>
                </button>
              </div>
            </>
          ) : (
            <div className="py-24 text-center text-sentinel-muted font-mono text-xs">
              SELECT AN INCIDENT FROM THE LEFT QUEUE TO COMMENCE TACTICAL RESPONSE.
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
