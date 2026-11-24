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
          <p className="text-xs font-mono text-gray-400">
            Real-time CAD (Computer-Aided Dispatch) Terminal for Law Enforcement Patrol Units.
          </p>
        </div>

        <div className="flex items-center gap-3">
          <div className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-blue-500/10 border border-blue-500/30 text-xs font-mono text-blue-400">
            <Car className="w-4 h-4 text-blue-400" />
            <span>DISPATCH QUEUE: {activeCount} ACTIVE</span>
          </div>
          <button
            onClick={fetchDispatchQueue}
            className="p-2 rounded-lg bg-gray-800 hover:bg-gray-700 text-gray-300 border border-gray-700"
            title="Refresh Queue"
          >
            <RefreshCw className="w-4 h-4" />
          </button>
        </div>
      </div>

      {feedback && (
        <div className="p-3 rounded-lg bg-blue-500/10 border border-blue-500/30 text-xs font-mono text-blue-300 flex items-center justify-between">
          <span>{feedback}</span>
          <button onClick={() => setFeedback(null)} className="text-gray-400 hover:text-white">
            ✕
          </button>
        </div>
      )}

      {/* Main Grid: Left List (Dispatch Calls) + Right Detail (Active Dispatch Management) */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Left 5 Cols: Incident Queue */}
        <div className="lg:col-span-5 glass-panel p-4 border border-gray-800 space-y-3">
          <div className="flex items-center justify-between border-b border-gray-800 pb-2 text-xs font-mono">
            <span className="text-gray-400 font-bold uppercase">LIVE EMERGENCY CALLS</span>
            <span className="text-[10px] text-gray-500">{incidents.length} INGESTED</span>
          </div>

          {loading && incidents.length === 0 ? (
            <div className="py-12 text-center text-gray-500 font-mono text-xs">
              <div className="w-5 h-5 border-2 border-blue-400 border-t-transparent rounded-full animate-spin mx-auto mb-2"></div>
              POLLING DISPATCH FEED...
            </div>
          ) : incidents.length === 0 ? (
            <div className="py-12 text-center text-gray-500 font-mono text-xs">
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
                        ? 'bg-blue-950/40 border-blue-500 shadow-[0_0_15px_rgba(59,130,246,0.2)]'
                        : isDistress && !isResolved
                        ? 'bg-red-950/20 border-red-500/40 hover:border-red-400'
                        : 'bg-[rgba(13,17,26,0.6)] border-gray-800 hover:border-gray-700'
                    }`}
                  >
                    <div className="flex items-center justify-between mb-1">
                      <div className="flex items-center gap-2">
                        {isDistress ? (
                          <Volume2 className="w-3.5 h-3.5 text-red-400" />
                        ) : (
                          <Siren className="w-3.5 h-3.5 text-blue-400" />
                        )}
                        <span className="text-xs font-bold font-mono text-white">
                          {inc.threatClass}
                        </span>
                      </div>
                      <span
                        className={`text-[9px] font-mono px-1.5 py-0.5 rounded uppercase font-bold ${
                          isResolved
                            ? 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30'
                            : inc.dispatchStatus === 'en_route'
                            ? 'bg-amber-500/20 text-amber-400 border border-amber-500/30'
                            : 'bg-red-500/20 text-red-400 border border-red-500/30'
                        }`}
                      >
                        {inc.dispatchStatus?.replace('_', ' ')}
                      </span>
                    </div>

                    <div className="flex items-center justify-between text-[10px] font-mono text-gray-400">
                      <span className="flex items-center gap-1">
                        <MapPin className="w-3 h-3 text-[#00F0FF]" />
                        {inc.location || 'Perimeter Sector Alpha'} ({inc.cameraId})
                      </span>
                      <span>
                        {new Date(inc.frameTimestamp || inc.createdAt).toLocaleTimeString()}
                      </span>
                    </div>

                    {inc.audioTranscript && (
                      <div className="mt-1.5 text-[10px] font-mono text-amber-300 truncate bg-amber-500/10 px-1.5 py-0.5 rounded">
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
        <div className="lg:col-span-7 glass-panel p-6 border border-blue-500/30 space-y-5">
          {selectedIncident ? (
            <>
              {/* Incident Header */}
              <div className="flex items-start justify-between border-b border-gray-800 pb-4">
                <div>
                  <div className="flex items-center gap-2">
                    <span className="badge badge-police text-[10px]">CALL SHEET</span>
                    <h2 className="text-lg font-bold font-display text-white">
                      {selectedIncident.threatClass}
                    </h2>
                  </div>
                  <p className="text-xs font-mono text-gray-400 flex items-center gap-3 mt-1">
                    <span className="flex items-center gap-1">
                      <MapPin className="w-3.5 h-3.5 text-[#00F0FF]" />
                      {selectedIncident.location || 'Perimeter Sector Alpha'}
                    </span>
                    <span>•</span>
                    <span className="flex items-center gap-1">
                      <Clock className="w-3.5 h-3.5 text-gray-500" />
                      {new Date(
                        selectedIncident.frameTimestamp || selectedIncident.createdAt
                      ).toLocaleTimeString()}
                    </span>
                    <span>•</span>
                    <span className="text-[#00F0FF] font-semibold">
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
                <label className="block text-[11px] font-mono text-gray-400 uppercase tracking-wider">
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
                            ? 'bg-blue-600 text-white border-blue-400 shadow-[0_0_15px_rgba(59,130,246,0.4)]'
                            : 'bg-gray-800/60 text-gray-400 border-gray-700 hover:border-gray-500 hover:text-white'
                        }`}
                      >
                        {step.label}
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Telemetry Overview Grid */}
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-3 p-3.5 rounded-lg bg-[rgba(13,17,26,0.7)] border border-gray-800 text-xs font-mono">
                <div>
                  <span className="text-gray-500 block text-[10px]">CONFIDENCE</span>
                  <span className="text-white font-bold">
                    {((selectedIncident.confidence || 0.95) * 100).toFixed(1)}%
                  </span>
                </div>
                <div>
                  <span className="text-gray-500 block text-[10px]">ASSIGNED PATROL</span>
                  <span className="text-blue-300 font-bold">
                    {selectedIncident.assignedTo || 'Unit 104 (Officer Vance)'}
                  </span>
                </div>
                <div>
                  <span className="text-gray-500 block text-[10px]">ACOUSTIC LEVEL</span>
                  <span className="text-[#00F0FF] font-bold">
                    {selectedIncident.audioDecibels || 89.2} dB
                  </span>
                </div>
              </div>

              {/* Acoustic Transcript Alert */}
              {selectedIncident.audioTranscript && (
                <div className="p-3 rounded-lg bg-amber-500/10 border border-amber-500/30 text-xs font-mono text-amber-300 flex items-start gap-2">
                  <Volume2 className="w-4 h-4 shrink-0 mt-0.5" />
                  <div>
                    <span className="font-bold block text-[10px] uppercase text-amber-400">
                      ACOUSTIC DISTRESS PHRASE RECORDED:
                    </span>
                    <span>"{selectedIncident.audioTranscript}"</span>
                  </div>
                </div>
              )}

              {/* Police Tactical Notes Field */}
              <div className="space-y-2">
                <label className="block text-xs font-mono text-gray-300">
                  OFFICER LOG &amp; APPREHENSION NOTES
                </label>
                <textarea
                  rows={3}
                  value={policeNotes}
                  onChange={(e) => setPoliceNotes(e.target.value)}
                  placeholder="Record tactical assessment, suspect description, perimeter containment, or final disposition..."
                  className="w-full p-3 bg-black/60 border border-gray-800 focus:border-blue-400 rounded-lg text-xs font-mono text-white focus:outline-none"
                />
                <button
                  type="button"
                  onClick={() =>
                    handleStatusChange(selectedIncident, selectedIncident.dispatchStatus)
                  }
                  disabled={updating || (!isPolice && !isAdmin)}
                  className="btn-primary py-2 px-4 text-xs font-mono"
                >
                  <span>SAVE NOTES TO CAD DISPATCH DATABASE</span>
                </button>
              </div>
            </>
          ) : (
            <div className="py-24 text-center text-gray-500 font-mono text-xs">
              SELECT AN INCIDENT FROM THE LEFT QUEUE TO COMMENCE TACTICAL RESPONSE.
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
