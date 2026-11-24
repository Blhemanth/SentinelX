// SentinelX Web - Anomaly Simulation & Live Expo Drill Center
import React, { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { logsApi } from '../api/client';
import {
  Zap,
  Volume2,
  ShieldAlert,
  Flame,
  Users,
  Swords,
  Send,
  CheckCircle2,
  AlertTriangle,
  Radio,
} from 'lucide-react';

export const DrillTriggerView = ({ onIncidentTriggered }) => {
  const { isAnalyst, isAdmin } = useAuth();
  const [loadingScenario, setLoadingScenario] = useState(null);
  const [resultMsg, setResultMsg] = useState(null);

  // Custom Form State
  const [customThreat, setCustomThreat] = useState('Weapon Detected');
  const [customCam, setCustomCam] = useState('CAM-001');
  const [customLocation, setCustomLocation] = useState('Sector 7 // Terminal West');
  const [customConfidence, setCustomConfidence] = useState(96);
  const [customDecibels, setCustomDecibels] = useState(88);
  const [customTranscript, setCustomTranscript] = useState('Critical Weapon Draw Detected');
  const [customLoading, setCustomLoading] = useState(false);

  const scenarios = [
    {
      id: 'distress',
      title: 'Acoustic Distress: HELP, HELP',
      severity: 'critical',
      icon: Volume2,
      color: 'border-red-500/40 bg-red-950/20 hover:border-red-500',
      iconColor: 'text-red-400',
      desc: 'Simulates the critical emergency distress keyword "HELP, HELP" with 89.2 dB audio burst.',
      payload: {
        threatClass: 'Acoustic Distress: HELP, HELP',
        cameraId: 'CAM-001',
        location: 'Primary Perimeter // Sector 4',
        audioTranscript: 'Critical Acoustic Distress Detected: "HELP! HELP! EMERGENCY AT SECTOR"',
        confidence: 0.988,
        decibels: 89.2,
      },
    },
    {
      id: 'weapon',
      title: 'Weapon Detected',
      severity: 'critical',
      icon: ShieldAlert,
      color: 'border-rose-500/40 bg-rose-950/20 hover:border-rose-500',
      iconColor: 'text-rose-400',
      desc: 'Simulates high-confidence firearm / weapon classification in surveillance frame.',
      payload: {
        threatClass: 'Weapon Detected',
        cameraId: 'CAM-001',
        location: 'Main Entry Concourse // Gate A',
        audioTranscript: 'Subdued Verbal Confrontation Detected',
        confidence: 0.974,
        decibels: 72.0,
      },
    },
    {
      id: 'explosion',
      title: 'Explosion / Fire Hazard',
      severity: 'critical',
      icon: Flame,
      color: 'border-amber-500/40 bg-amber-950/20 hover:border-amber-500',
      iconColor: 'text-amber-400',
      desc: 'Simulates sudden acoustic concussion (>100 dB) accompanied by thermal flash anomaly.',
      payload: {
        threatClass: 'Explosion',
        cameraId: 'CAM-002',
        location: 'Sub-Level Utility Corridor // B2',
        audioTranscript: 'Impulse Concussion Wave Detected: 104.5 dB',
        confidence: 0.992,
        decibels: 104.5,
      },
    },
    {
      id: 'fighting',
      title: 'Violent Fighting',
      severity: 'high',
      icon: Swords,
      color: 'border-purple-500/40 bg-purple-950/20 hover:border-purple-500',
      iconColor: 'text-purple-400',
      desc: 'Simulates physical altercation with rapid optical flow vector spikes.',
      payload: {
        threatClass: 'Fighting',
        cameraId: 'CAM-001',
        location: 'Public Plaza // Fountain Zone',
        audioTranscript: 'Raised Voices and Physical Impact Sounds',
        confidence: 0.915,
        decibels: 81.3,
      },
    },
    {
      id: 'panic',
      title: 'Crowd Panic / Stampede',
      severity: 'high',
      icon: Users,
      color: 'border-blue-500/40 bg-blue-950/20 hover:border-blue-500',
      iconColor: 'text-blue-400',
      desc: 'Simulates sudden crowd divergence and velocity dispersion indicating mass panic.',
      payload: {
        threatClass: 'Crowd Panic',
        cameraId: 'CAM-002',
        location: 'Transit Station // Exit Turnstiles',
        audioTranscript: 'Multi-Voice Screaming and Rapid Footsteps',
        confidence: 0.887,
        decibels: 79.8,
      },
    },
  ];

  const handleTriggerScenario = async (scenario) => {
    setLoadingScenario(scenario.id);
    setResultMsg(null);
    try {
      const res = await logsApi.triggerAnomaly(scenario.payload);
      if (res.success && res.data) {
        setResultMsg({
          type: 'success',
          text: `Success: Triggered "${scenario.title}" (Log ID: ${res.data._id?.slice(-6)}). Synced to MongoDB & Flutter!`,
        });
        if (onIncidentTriggered) onIncidentTriggered(res.data);
      }
    } catch (err) {
      setResultMsg({ type: 'error', text: `Drill trigger failed: ${err.message}` });
    } finally {
      setLoadingScenario(null);
    }
  };

  const handleCustomTrigger = async (e) => {
    e.preventDefault();
    setCustomLoading(true);
    setResultMsg(null);
    try {
      const payload = {
        threatClass: customThreat,
        cameraId: customCam,
        location: customLocation,
        confidence: customConfidence / 100,
        decibels: Number(customDecibels),
        audioTranscript: customTranscript,
      };

      const res = await logsApi.triggerAnomaly(payload);
      if (res.success && res.data) {
        setResultMsg({
          type: 'success',
          text: `Success: Custom drill logged to MongoDB (${res.data._id?.slice(-6)})! Flutter & React now synchronized.`,
        });
        if (onIncidentTriggered) onIncidentTriggered(res.data);
      }
    } catch (err) {
      setResultMsg({ type: 'error', text: `Custom trigger failed: ${err.message}` });
    } finally {
      setCustomLoading(false);
    }
  };

  return (
    <div className="p-6 space-y-6 max-w-7xl mx-auto">
      {/* Header */}
      <div>
        <div className="flex items-center gap-2">
          <h1 className="text-2xl font-black font-display tracking-wider text-white">
            ANOMALY SIMULATION &amp; EXPO DRILL CENTER
          </h1>
          <span className="badge badge-critical text-[10px]">LIVE INJECTOR</span>
        </div>
        <p className="text-xs font-mono text-gray-400">
          Inject real-time anomaly events into MongoDB to verify end-to-end synchronization between Express, React Web, and the Flutter Desktop client.
        </p>
      </div>

      {resultMsg && (
        <div
          className={`p-4 rounded-xl border text-xs font-mono flex items-center justify-between ${
            resultMsg.type === 'success'
              ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-300'
              : 'bg-red-500/10 border-red-500/30 text-red-300'
          }`}
        >
          <div className="flex items-center gap-2">
            <CheckCircle2 className="w-4 h-4 shrink-0 text-emerald-400" />
            <span>{resultMsg.text}</span>
          </div>
          <button onClick={() => setResultMsg(null)} className="text-gray-400 hover:text-white">
            ✕
          </button>
        </div>
      )}

      {/* 5 Instant Scenario Cards */}
      <div className="space-y-3">
        <label className="block text-xs font-mono text-gray-400 uppercase tracking-wider">
          ONE-CLICK EXPO DEMO DRILLS:
        </label>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {scenarios.map((sc) => {
            const Icon = sc.icon;
            const isLoading = loadingScenario === sc.id;

            return (
              <div
                key={sc.id}
                className={`glass-panel p-5 border rounded-xl transition-all space-y-3 flex flex-col justify-between ${sc.color}`}
              >
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <div className="flex items-center gap-2">
                      <Icon className={`w-5 h-5 ${sc.iconColor}`} />
                      <h3 className="text-sm font-bold font-mono text-white">{sc.title}</h3>
                    </div>
                    <span
                      className={`badge ${
                        sc.severity === 'critical' ? 'badge-critical' : 'badge-high'
                      } text-[9px]`}
                    >
                      {sc.severity.toUpperCase()}
                    </span>
                  </div>
                  <p className="text-[11px] font-mono text-gray-400">{sc.desc}</p>
                </div>

                <div className="pt-2 border-t border-gray-800/80 flex items-center justify-between">
                  <span className="text-[10px] font-mono text-gray-500">
                    Node: {sc.payload.cameraId}
                  </span>
                  <button
                    onClick={() => handleTriggerScenario(sc)}
                    disabled={isLoading || (!isAnalyst && !isAdmin)}
                    className="btn-critical text-xs py-1 px-3 flex items-center gap-1.5"
                  >
                    <Zap className="w-3.5 h-3.5" />
                    <span>{isLoading ? 'INJECTING...' : 'TRIGGER DRILL'}</span>
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Custom Anomaly Builder Card */}
      <div className="glass-panel p-6 border border-cyan-500/30 rounded-xl space-y-4">
        <div className="flex items-center justify-between border-b border-gray-800 pb-3">
          <div className="flex items-center gap-2">
            <h2 className="text-sm font-bold font-mono tracking-wider text-white uppercase">
              CUSTOM ANOMALY PAYLOAD BUILDER
            </h2>
            <span className="text-[10px] font-mono text-[#00F0FF]">ADVANCED INJECTOR</span>
          </div>
        </div>

        <form onSubmit={handleCustomTrigger} className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          <div>
            <label className="block text-[11px] font-mono text-gray-400 mb-1">THREAT CLASS</label>
            <select
              value={customThreat}
              onChange={(e) => setCustomThreat(e.target.value)}
              className="w-full px-3 py-2 bg-black/60 border border-gray-800 focus:border-[#00F0FF] rounded-lg text-xs font-mono text-white"
            >
              <option value="Weapon Detected">Weapon Detected</option>
              <option value="Acoustic Distress: HELP, HELP">Acoustic Distress: HELP, HELP</option>
              <option value="Explosion">Explosion</option>
              <option value="Fighting">Violent Fighting</option>
              <option value="Crowd Panic">Crowd Panic</option>
              <option value="Accident">Accident</option>
            </select>
          </div>

          <div>
            <label className="block text-[11px] font-mono text-gray-400 mb-1">CAMERA SENSOR</label>
            <select
              value={customCam}
              onChange={(e) => setCustomCam(e.target.value)}
              className="w-full px-3 py-2 bg-black/60 border border-gray-800 focus:border-[#00F0FF] rounded-lg text-xs font-mono text-white"
            >
              <option value="CAM-001">CAM-001 (Laptop Integrated Webcam)</option>
              <option value="CAM-002">CAM-002 (Patrol Smartphone IP Stream)</option>
            </select>
          </div>

          <div>
            <label className="block text-[11px] font-mono text-gray-400 mb-1">LOCATION TAG</label>
            <input
              type="text"
              value={customLocation}
              onChange={(e) => setCustomLocation(e.target.value)}
              className="w-full px-3 py-2 bg-black/60 border border-gray-800 focus:border-[#00F0FF] rounded-lg text-xs font-mono text-white"
            />
          </div>

          <div>
            <label className="block text-[11px] font-mono text-gray-400 mb-1">
              ML CONFIDENCE: {customConfidence}%
            </label>
            <input
              type="range"
              min="50"
              max="99"
              value={customConfidence}
              onChange={(e) => setCustomConfidence(Number(e.target.value))}
              className="w-full accent-cyan-400"
            />
          </div>

          <div>
            <label className="block text-[11px] font-mono text-gray-400 mb-1">
              ACOUSTIC LEVEL: {customDecibels} dB
            </label>
            <input
              type="range"
              min="40"
              max="120"
              value={customDecibels}
              onChange={(e) => setCustomDecibels(Number(e.target.value))}
              className="w-full accent-cyan-400"
            />
          </div>

          <div>
            <label className="block text-[11px] font-mono text-gray-400 mb-1">AUDIO TRANSCRIPT</label>
            <input
              type="text"
              value={customTranscript}
              onChange={(e) => setCustomTranscript(e.target.value)}
              placeholder="e.g. HELP! HELP! SUSPECT ON SCENE"
              className="w-full px-3 py-2 bg-black/60 border border-gray-800 focus:border-[#00F0FF] rounded-lg text-xs font-mono text-white"
            />
          </div>

          <div className="sm:col-span-2 lg:col-span-3 pt-2">
            <button
              type="submit"
              disabled={customLoading || (!isAnalyst && !isAdmin)}
              className="btn-primary py-2.5 px-6 text-xs font-mono flex items-center gap-2"
            >
              <Send className="w-4 h-4" />
              <span>{customLoading ? 'TRANSMITTING...' : 'INJECT CUSTOM ANOMALY INTO MONGODB'}</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
