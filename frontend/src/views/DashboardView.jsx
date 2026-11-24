// SentinelX Web - Dashboard & Overview View
import React, { useState, useEffect } from 'react';
import { logsApi } from '../api/client';
import {
  ShieldAlert,
  Siren,
  CheckCircle,
  RefreshCw,
  Camera,
  Eye,
  Radio,
  Volume2,
  TrendingUp,
  Activity,
  Zap,
} from 'lucide-react';

export const DashboardView = ({ onSelectIncident, onOpenDrillModal }) => {
  const [stats, setStats] = useState(null);
  const [recentLogs, setRecentLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [autoRefresh, setAutoRefresh] = useState(true);

  const fetchDashboardData = async () => {
    try {
      const [statsRes, logsRes] = await Promise.all([
        logsApi.getStats().catch(() => null),
        logsApi.getLogs({ limit: 10, page: 1 }),
      ]);

      if (statsRes?.success) {
        setStats(statsRes.data);
      }
      if (logsRes?.success && logsRes.data) {
        setRecentLogs(logsRes.data);
      }
    } catch (err) {
      console.warn('Dashboard fetch error:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchDashboardData();
    let interval;
    if (autoRefresh) {
      interval = setInterval(fetchDashboardData, 4000); // 4-sec live polling
    }
    return () => clearInterval(interval);
  }, [autoRefresh]);

  // Check for active acoustic distress or verified critical threats
  // Strictly excludes fallbacks, low-confidence reviews, and unverified legacy/unknown sources
  const activeEmergencies = recentLogs.filter((log) => {
    if (log.dispatchStatus === 'resolved') return false;

    // Exclude fallbacks, low-confidence, and unverified legacy records
    if (
      log.detectionStatus === 'subprocess_fallback' ||
      log.detectionSource === 'subprocess_fallback' ||
      log.detectionStatus === 'low_confidence_review' ||
      log.detectionStatus === 'legacy_unclassified' ||
      log.detectionSource === 'legacy_unspecified'
    ) {
      return false;
    }

    // Acoustic SOS voice distress trigger ("HELP, HELP")
    if (log.detectionSource === 'acoustic_sos' || log.threatClass?.includes('HELP')) {
      return true;
    }

    // Operator Drill Simulations (must be visibly tagged as simulation)
    if (log.detectionSource === 'drill_simulation') {
      return log.severity === 'critical' || (typeof log.confidence === 'number' && log.confidence >= 0.85);
    }

    // Genuine verified ML anomaly (requires critical severity + confidence >= 0.85)
    if (log.detectionSource === 'ml_real' && log.detectionStatus === 'anomaly_detected') {
      return log.severity === 'critical' && (typeof log.confidence === 'number' && log.confidence >= 0.85);
    }

    return false;
  });

  const totalIncidents = stats?.total || recentLogs.length;
  const criticalCount = stats?.bySeverity?.critical || activeEmergencies.length;
  const dispatchedCount =
    (stats?.byDispatch?.en_route || 0) + (stats?.byDispatch?.on_scene || 0);
  const resolvedCount = stats?.byDispatch?.resolved || 0;

  return (
    <div className="p-6 space-y-6 max-w-7xl mx-auto">
      {/* Top Banner: Active Distress Signal */}
      {activeEmergencies.length > 0 && (
        <div className="p-4 rounded-xl border border-sentinel-critical/60 bg-gradient-to-r from-red-950/80 via-red-900/40 to-sentinel-bg backdrop-blur-md shadow-[0_0_30px_rgba(255,82,104,0.25)] animate-pulse">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div className="flex items-center gap-3">
              <div className="p-2.5 rounded-lg bg-sentinel-critical/20 border border-sentinel-critical/50 text-sentinel-critical">
                <Siren className="w-6 h-6 animate-bounce" />
              </div>
              <div>
                <div className="flex items-center gap-2">
                  <span className="text-sm font-extrabold font-display tracking-wider text-red-200">
                    {activeEmergencies[0].detectionSource === 'drill_simulation'
                      ? `TRAINING DRILL SIMULATION (${activeEmergencies.length} ACTIVE)`
                      : `CRITICAL URBAN DISTRESS DETECTED (${activeEmergencies.length} ACTIVE)`}
                  </span>
                  <span
                    className={`badge ${
                      activeEmergencies[0].detectionSource === 'drill_simulation'
                        ? 'bg-purple-500/20 text-purple-300 border border-purple-500/40'
                        : 'badge-critical'
                    } text-[10px]`}
                  >
                    {activeEmergencies[0].detectionSource === 'drill_simulation' ? 'SIMULATION DRILL' : 'PRIORITY 1'}
                  </span>
                </div>
                <p className="text-xs font-mono text-red-300/80 mt-0.5">
                  Latest: {activeEmergencies[0].threatClass} at{' '}
                  {activeEmergencies[0].location || 'Perimeter Sector Alpha'} (
                  {activeEmergencies[0].cameraId})
                </p>
              </div>
            </div>

            <div className="flex items-center gap-2">
              <button
                onClick={() => onSelectIncident(activeEmergencies[0])}
                className="btn-critical text-xs py-1.5 px-3 flex items-center gap-1.5"
              >
                <Eye className="w-4 h-4" />
                <span>TRIAGE INCIDENT</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Header Bar */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <h1 className="text-2xl font-black font-display tracking-wider text-white">
              OPERATIONAL OVERVIEW
            </h1>
            <span className="badge badge-normal text-[10px]">REAL-TIME HUD</span>
          </div>
          <p className="text-xs font-mono text-sentinel-muted">
            Continuous Urban Anomaly Monitoring &amp; Law Enforcement Dispatch Console
          </p>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={() => setAutoRefresh(!autoRefresh)}
            className={`btn-secondary text-xs py-1.5 px-3 flex items-center gap-2 ${
              autoRefresh
                ? 'border-sentinel-success/40 text-sentinel-success bg-sentinel-success/10'
                : 'text-sentinel-muted'
            }`}
          >
            <RefreshCw className={`w-3.5 h-3.5 ${autoRefresh ? 'animate-spin' : ''}`} />
            <span>AUTO-SYNC: {autoRefresh ? 'ON (4s)' : 'OFF'}</span>
          </button>

          <button
            onClick={fetchDashboardData}
            className="p-2 rounded-lg bg-sentinel-card hover:bg-sentinel-elevated text-sentinel-text border border-sentinel-border transition-colors"
            title="Manual Refresh"
          >
            <RefreshCw className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* KPI Metric Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Total Ingested Logs */}
        <div className="sentinel-card p-5 border-sentinel-border hover:border-sentinel-cyan/40 transition-all">
          <div className="flex items-center justify-between text-sentinel-muted mb-2">
            <span className="text-xs font-mono tracking-wider uppercase">TOTAL INGESTED LOGS</span>
            <div className="p-1.5 rounded bg-sentinel-cyan/10 text-sentinel-cyan">
              <Radio className="w-4 h-4" />
            </div>
          </div>
          <div className="text-3xl font-black font-mono text-white tracking-tight">
            {totalIncidents}
          </div>
          <div className="text-[11px] font-mono text-sentinel-muted mt-1 flex items-center gap-1">
            <TrendingUp className="w-3 h-3 text-sentinel-cyan" />
            <span>Synced across MongoDB &amp; Flutter</span>
          </div>
        </div>

        {/* Critical Threats */}
        <div className="sentinel-card p-5 border-sentinel-critical/30 hover:border-sentinel-critical/60 transition-all">
          <div className="flex items-center justify-between text-sentinel-muted mb-2">
            <span className="text-xs font-mono tracking-wider uppercase text-sentinel-critical">
              CRITICAL THREATS
            </span>
            <div className="p-1.5 rounded bg-sentinel-critical/10 text-sentinel-critical">
              <ShieldAlert className="w-4 h-4" />
            </div>
          </div>
          <div className="text-3xl font-black font-mono text-sentinel-critical tracking-tight">
            {criticalCount}
          </div>
          <div className="text-[11px] font-mono text-sentinel-critical/80 mt-1 flex items-center gap-1">
            <span className="w-2 h-2 rounded-full bg-sentinel-critical animate-pulse" />
            <span>Immediate CAD Attention</span>
          </div>
        </div>

        {/* Active Dispatches */}
        <div className="sentinel-card p-5 border-sentinel-warning/30 hover:border-sentinel-warning/60 transition-all">
          <div className="flex items-center justify-between text-sentinel-muted mb-2">
            <span className="text-xs font-mono tracking-wider uppercase text-sentinel-warning">
              DISPATCHED // EN ROUTE
            </span>
            <div className="p-1.5 rounded bg-sentinel-warning/10 text-sentinel-warning">
              <Siren className="w-4 h-4" />
            </div>
          </div>
          <div className="text-3xl font-black font-mono text-sentinel-warning tracking-tight">
            {dispatchedCount}
          </div>
          <div className="text-[11px] font-mono text-sentinel-muted mt-1">
            Patrol Units Mobilized
          </div>
        </div>

        {/* Resolved Cases */}
        <div className="sentinel-card p-5 border-sentinel-success/30 hover:border-sentinel-success/60 transition-all">
          <div className="flex items-center justify-between text-sentinel-muted mb-2">
            <span className="text-xs font-mono tracking-wider uppercase text-sentinel-success">
              RESOLVED &amp; SECURE
            </span>
            <div className="p-1.5 rounded bg-sentinel-success/10 text-sentinel-success">
              <CheckCircle className="w-4 h-4" />
            </div>
          </div>
          <div className="text-3xl font-black font-mono text-sentinel-success tracking-tight">
            {resolvedCount}
          </div>
          <div className="text-[11px] font-mono text-sentinel-muted mt-1">
            Incidents Cleared
          </div>
        </div>
      </div>

      {/* Threat Distribution & Camera Grid Preview */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Threat Distribution Card */}
        <div className="lg:col-span-5 sentinel-card p-5 space-y-4">
          <div className="flex items-center justify-between border-b border-sentinel-border pb-3">
            <h2 className="text-xs font-bold font-mono tracking-wider text-white uppercase flex items-center gap-2">
              <Activity className="w-4 h-4 text-sentinel-cyan" />
              THREAT FREQUENCY BY CATEGORY
            </h2>
            <span className="text-[10px] font-mono text-sentinel-muted">LIVE AGGREGATION</span>
          </div>

          <div className="space-y-3 font-mono text-xs">
            {[
              { label: 'Acoustic Distress (HELP)', count: 6, color: 'bg-sentinel-critical', pct: '85%' },
              { label: 'Weapon Detected', count: 4, color: 'bg-rose-500', pct: '60%' },
              { label: 'Explosion / Hazard', count: 2, color: 'bg-sentinel-warning', pct: '35%' },
              { label: 'Violent Fighting', count: 5, color: 'bg-purple-500', pct: '70%' },
              { label: 'Crowd Panic / Stampede', count: 3, color: 'bg-sentinel-blue', pct: '45%' },
            ].map((item) => (
              <div key={item.label} className="space-y-1">
                <div className="flex justify-between text-sentinel-text text-[11px]">
                  <span>{item.label}</span>
                  <span className="text-sentinel-muted">{item.count} events</span>
                </div>
                <div className="w-full h-2 rounded-full bg-sentinel-bg border border-sentinel-border overflow-hidden">
                  <div
                    className={`h-full ${item.color} rounded-full transition-all duration-500`}
                    style={{ width: item.pct }}
                  />
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Dual Camera Telemetry Bar */}
        <div className="lg:col-span-7 sentinel-card p-5 space-y-4">
          <div className="flex items-center justify-between border-b border-sentinel-border pb-3">
            <h2 className="text-xs font-bold font-mono tracking-wider text-white uppercase flex items-center gap-2">
              <Camera className="w-4 h-4 text-sentinel-cyan" />
              ACTIVE SURVEILLANCE SENSORS (2 CHANNELS)
            </h2>
            <span className="text-[10px] font-mono text-sentinel-success flex items-center gap-1">
              <span className="w-2 h-2 rounded-full bg-sentinel-success" />
              HEALTHY
            </span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {/* CAM-001 Laptop Webcam */}
            <div className="p-4 rounded-lg bg-sentinel-bg border border-sentinel-border space-y-2 font-mono text-xs">
              <div className="flex items-center justify-between">
                <span className="font-bold text-white flex items-center gap-1.5">
                  <Camera className="w-4 h-4 text-sentinel-cyan" />
                  CAM-001
                </span>
                <span className="badge badge-normal text-[9px] text-sentinel-success">ONLINE</span>
              </div>
              <p className="text-[11px] text-sentinel-muted">Integrated Laptop Camera // Control Room</p>
              <div className="pt-2 border-t border-sentinel-border/80 text-[10px] text-sentinel-muted space-y-1">
                <div className="flex justify-between">
                  <span>Stream:</span>
                  <span className="text-sentinel-text">DirectShow / Hardware</span>
                </div>
                <div className="flex justify-between">
                  <span>Inference:</span>
                  <span className="text-sentinel-cyan">Local ONNX INT8 + API</span>
                </div>
                <div className="flex justify-between">
                  <span>FPS:</span>
                  <span className="text-sentinel-success">30.0 FPS</span>
                </div>
              </div>
            </div>

            {/* CAM-002 Mobile Phone Camera */}
            <div className="p-4 rounded-lg bg-sentinel-bg border border-sentinel-border space-y-2 font-mono text-xs">
              <div className="flex items-center justify-between">
                <span className="font-bold text-white flex items-center gap-1.5">
                  <Camera className="w-4 h-4 text-sentinel-blue" />
                  CAM-002
                </span>
                <span className="badge badge-normal text-[9px] text-sentinel-blue">IP READY</span>
              </div>
              <p className="text-[11px] text-sentinel-muted">Field Patrol Smartphone // Tactical Cam</p>
              <div className="pt-2 border-t border-sentinel-border/80 text-[10px] text-sentinel-muted space-y-1">
                <div className="flex justify-between">
                  <span>Stream:</span>
                  <span className="text-sentinel-text">RTSP / HTTP MJPEG</span>
                </div>
                <div className="flex justify-between">
                  <span>Host:</span>
                  <span className="text-sentinel-blue">192.168.1.x:8080</span>
                </div>
                <div className="flex justify-between">
                  <span>Sync:</span>
                  <span className="text-sentinel-success">MongoDB Shared Store</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Recent Live Activity Stream Table */}
      <div className="sentinel-card p-5 space-y-4">
        <div className="flex items-center justify-between border-b border-sentinel-border pb-3">
          <div className="flex items-center gap-2">
            <h2 className="text-sm font-bold font-mono tracking-wider text-white uppercase">
              LIVE ANOMALY &amp; INCIDENT STREAM
            </h2>
            <span className="badge badge-normal text-[10px]">
              {recentLogs.length} RECENT EVENTS
            </span>
          </div>

          <button
            onClick={onOpenDrillModal}
            className="btn-primary text-xs py-1 px-3 flex items-center gap-1.5"
          >
            <Zap className="w-3.5 h-3.5" />
            <span>+ TEST DRILL ANOMALY</span>
          </button>
        </div>

        {loading && recentLogs.length === 0 ? (
          <div className="space-y-3 py-4">
            {[1, 2, 3, 4].map((n) => (
              <div key={n} className="h-10 w-full skeleton rounded-lg" />
            ))}
          </div>
        ) : recentLogs.length === 0 ? (
          <div className="py-12 text-center text-sentinel-muted font-mono text-xs">
            NO INCIDENTS LOGGED YET. USE "TEST DRILL ANOMALY" OR FLUTTER APP TO TRIGGER DETECTION.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left font-mono text-xs">
              <thead>
                <tr className="border-b border-sentinel-border text-sentinel-muted text-[10px] uppercase tracking-wider">
                  <th className="py-2.5 px-3">TIMESTAMP</th>
                  <th className="py-2.5 px-3">THREAT CLASSIFICATION</th>
                  <th className="py-2.5 px-3">SEVERITY</th>
                  <th className="py-2.5 px-3">CAMERA</th>
                  <th className="py-2.5 px-3">CONFIDENCE</th>
                  <th className="py-2.5 px-3">DISPATCH STATUS</th>
                  <th className="py-2.5 px-3 text-right">ACTION</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-sentinel-border/50">
                {recentLogs.map((log) => {
                  const isDistress =
                    log.threatClass?.includes('HELP') || log.severity === 'critical';
                  return (
                    <tr
                      key={log._id}
                      className={`hover:bg-white/[0.02] transition-colors cursor-pointer ${
                        isDistress ? 'bg-red-500/[0.04]' : ''
                      }`}
                      onClick={() => onSelectIncident(log)}
                    >
                      <td className="py-3 px-3 text-sentinel-muted whitespace-nowrap">
                        {new Date(log.frameTimestamp || log.createdAt).toLocaleTimeString()}
                      </td>
                      <td className="py-3 px-3">
                        <div className="flex items-center gap-2">
                          {isDistress ? (
                            <Volume2 className="w-3.5 h-3.5 text-sentinel-critical" />
                          ) : (
                            <ShieldAlert className="w-3.5 h-3.5 text-sentinel-cyan" />
                          )}
                          <span className="font-bold text-white">{log.threatClass}</span>
                          {log.detectionStatus === 'low_confidence_review' && (
                            <span className="px-1.5 py-0.5 rounded text-[9px] font-bold bg-amber-500/20 text-amber-300 border border-amber-500/40">
                              REVIEW
                            </span>
                          )}
                          {(log.detectionStatus === 'subprocess_fallback' || log.detectionSource === 'subprocess_fallback') && (
                            <span className="px-1.5 py-0.5 rounded text-[9px] font-bold bg-yellow-500/20 text-yellow-300 border border-yellow-500/40">
                              FALLBACK
                            </span>
                          )}
                          {(log.detectionStatus === 'legacy_unclassified' || log.detectionSource === 'legacy_unspecified') && (
                            <span className="px-1.5 py-0.5 rounded text-[9px] font-bold bg-gray-700/50 text-gray-400 border border-gray-600/50">
                              LEGACY
                            </span>
                          )}
                          {log.detectionSource === 'drill_simulation' && (
                            <span className="px-1.5 py-0.5 rounded text-[9px] font-bold bg-purple-500/20 text-purple-300 border border-purple-500/40">
                              DRILL
                            </span>
                          )}
                        </div>
                        {log.audioTranscript && (
                          <span className="text-[10px] text-amber-300 block truncate max-w-xs mt-0.5">
                            "{log.audioTranscript}"
                          </span>
                        )}
                      </td>
                      <td className="py-3 px-3">
                        <span
                          className={`badge ${
                            log.severity === 'critical'
                              ? 'badge-critical'
                              : log.severity === 'high'
                              ? 'badge-high'
                              : 'badge-normal'
                          }`}
                        >
                          {log.severity?.toUpperCase()}
                        </span>
                      </td>
                      <td className="py-3 px-3 text-sentinel-text">{log.cameraId}</td>
                      <td className="py-3 px-3 text-sentinel-cyan font-bold">
                        {((log.confidence || 0.95) * 100).toFixed(1)}%
                      </td>
                      <td className="py-3 px-3">
                        <span
                          className={`inline-block px-2 py-0.5 rounded text-[10px] font-bold ${
                            log.dispatchStatus === 'resolved'
                              ? 'bg-sentinel-success/20 text-sentinel-success border border-sentinel-success/40'
                              : log.dispatchStatus === 'en_route' || log.dispatchStatus === 'on_scene'
                              ? 'bg-sentinel-warning/20 text-sentinel-warning border border-sentinel-warning/40'
                              : 'bg-sentinel-critical/20 text-sentinel-critical border border-sentinel-critical/40'
                          }`}
                        >
                          {(log.dispatchStatus || 'UNASSIGNED').replace('_', ' ').toUpperCase()}
                        </span>
                      </td>
                      <td className="py-3 px-3 text-right">
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            onSelectIncident(log);
                          }}
                          className="btn-secondary text-xs py-1 px-2.5"
                        >
                          Details
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
};
