// SentinelX Web - Incident Logs & Forensics View
import React, { useState, useEffect } from 'react';
import { useAuth } from '../context/AuthContext';
import { logsApi } from '../api/client';
import {
  AlertTriangle,
  Search,
  Filter,
  CheckCircle,
  Trash2,
  Eye,
  RefreshCw,
  Camera,
  ChevronLeft,
  ChevronRight,
  ShieldAlert,
  SlidersHorizontal,
} from 'lucide-react';

export const IncidentsView = ({ onSelectIncident }) => {
  const { isAnalyst, isAdmin } = useAuth();
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [pagination, setPagination] = useState({ page: 1, limit: 15, total: 0, pages: 1 });

  // Filters
  const [search, setSearch] = useState('');
  const [severity, setSeverity] = useState('');
  const [threatClass, setThreatClass] = useState('');
  const [cameraId, setCameraId] = useState('');
  const [dispatchStatus, setDispatchStatus] = useState('');
  const [acknowledged, setAcknowledged] = useState('');

  const fetchLogs = async (page = 1) => {
    setLoading(true);
    try {
      const res = await logsApi.getLogs({
        page,
        limit: 15,
        severity: severity || undefined,
        threatClass: threatClass || undefined,
        cameraId: cameraId || undefined,
        dispatchStatus: dispatchStatus || undefined,
        acknowledged: acknowledged || undefined,
      });

      if (res.success && res.data) {
        setLogs(res.data);
        if (res.pagination) {
          setPagination(res.pagination);
        }
      }
    } catch (err) {
      console.warn('Logs fetch error:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchLogs(1);
  }, [severity, threatClass, cameraId, dispatchStatus, acknowledged]);

  const handleAcknowledge = async (id, e) => {
    e.stopPropagation();
    try {
      const res = await logsApi.acknowledgeLog(id);
      if (res.success && res.data) {
        setLogs(logs.map((l) => (l._id === id ? res.data : l)));
      }
    } catch (err) {
      alert(`Acknowledge failed: ${err.message}`);
    }
  };

  const handleDelete = async (id, e) => {
    e.stopPropagation();
    if (!window.confirm('Are you sure you want to delete this incident log?')) return;
    try {
      const res = await logsApi.deleteLog(id);
      if (res.success) {
        setLogs(logs.filter((l) => l._id !== id));
      }
    } catch (err) {
      alert(`Delete failed: ${err.message}`);
    }
  };

  const filteredLogs = logs.filter((log) => {
    if (!search) return true;
    const term = search.toLowerCase();
    return (
      log.threatClass?.toLowerCase().includes(term) ||
      log.location?.toLowerCase().includes(term) ||
      log.cameraId?.toLowerCase().includes(term) ||
      log.audioTranscript?.toLowerCase().includes(term)
    );
  });

  return (
    <div className="p-6 space-y-6 max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <h1 className="text-2xl font-black font-display tracking-wider text-white">
              INCIDENT ARCHIVE &amp; FORENSICS
            </h1>
            <span className="badge badge-normal text-[10px]">AUDIT TRAIL</span>
          </div>
          <p className="text-xs font-mono text-sentinel-muted">
            Query, filter, and audit recorded anomalies across all surveillance nodes.
          </p>
        </div>

        <button
          onClick={() => fetchLogs(pagination.page)}
          className="btn-primary text-xs py-2 px-3 flex items-center gap-1.5 self-start sm:self-auto"
        >
          <RefreshCw className="w-3.5 h-3.5" />
          <span>REFRESH ARCHIVE</span>
        </button>
      </div>

      {/* Filter Toolbar */}
      <div className="sentinel-card p-4 space-y-3">
        <div className="flex items-center gap-2 text-xs font-mono text-sentinel-cyan uppercase tracking-wider mb-1">
          <SlidersHorizontal className="w-3.5 h-3.5" />
          <span>FORENSIC FILTERS</span>
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
          {/* Search Box */}
          <div className="lg:col-span-2 relative">
            <Search className="w-4 h-4 text-sentinel-muted absolute left-3 top-2.5" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search threat, location, transcript..."
              className="w-full pl-9 pr-3 py-1.5 bg-sentinel-bg border border-sentinel-border focus:border-sentinel-cyan rounded-lg text-xs font-mono text-white focus:outline-none"
            />
          </div>

          {/* Severity */}
          <div>
            <select
              value={severity}
              onChange={(e) => setSeverity(e.target.value)}
              className="w-full px-2.5 py-1.5 bg-sentinel-bg border border-sentinel-border focus:border-sentinel-cyan rounded-lg text-xs font-mono text-sentinel-text focus:outline-none"
            >
              <option value="">Severity: All</option>
              <option value="critical">Critical</option>
              <option value="high">High</option>
              <option value="medium">Medium</option>
              <option value="low">Low</option>
            </select>
          </div>

          {/* Camera */}
          <div>
            <select
              value={cameraId}
              onChange={(e) => setCameraId(e.target.value)}
              className="w-full px-2.5 py-1.5 bg-sentinel-bg border border-sentinel-border focus:border-sentinel-cyan rounded-lg text-xs font-mono text-sentinel-text focus:outline-none"
            >
              <option value="">Camera: All</option>
              <option value="CAM-001">CAM-001 (Laptop)</option>
              <option value="CAM-002">CAM-002 (Phone)</option>
            </select>
          </div>

          {/* Dispatch Status */}
          <div>
            <select
              value={dispatchStatus}
              onChange={(e) => setDispatchStatus(e.target.value)}
              className="w-full px-2.5 py-1.5 bg-sentinel-bg border border-sentinel-border focus:border-sentinel-cyan rounded-lg text-xs font-mono text-sentinel-text focus:outline-none"
            >
              <option value="">Dispatch: All</option>
              <option value="unassigned">Unassigned</option>
              <option value="assigned_police">Assigned Police</option>
              <option value="en_route">En Route</option>
              <option value="on_scene">On Scene</option>
              <option value="resolved">Resolved</option>
            </select>
          </div>

          {/* Acknowledged */}
          <div>
            <select
              value={acknowledged}
              onChange={(e) => setAcknowledged(e.target.value)}
              className="w-full px-2.5 py-1.5 bg-sentinel-bg border border-sentinel-border focus:border-sentinel-cyan rounded-lg text-xs font-mono text-sentinel-text focus:outline-none"
            >
              <option value="">Triage: All</option>
              <option value="true">Acknowledged</option>
              <option value="false">Unacknowledged</option>
            </select>
          </div>
        </div>
      </div>

      {/* Incidents Table */}
      <div className="sentinel-card overflow-hidden">
        {loading ? (
          <div className="p-6 space-y-3">
            {[1, 2, 3, 4, 5].map((n) => (
              <div key={n} className="h-10 w-full skeleton rounded-lg" />
            ))}
          </div>
        ) : filteredLogs.length === 0 ? (
          <div className="py-16 text-center text-sentinel-muted font-mono text-xs">
            NO INCIDENT LOGS MATCH YOUR QUERY CRITERIA.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left font-mono text-xs">
              <thead>
                <tr className="border-b border-sentinel-border bg-sentinel-bg/80 text-sentinel-muted text-[10px] uppercase tracking-wider">
                  <th className="py-3 px-4">TIMESTAMP</th>
                  <th className="py-3 px-4">THREAT CLASSIFICATION</th>
                  <th className="py-3 px-4">SEVERITY</th>
                  <th className="py-3 px-4">SENSOR / LOCATION</th>
                  <th className="py-3 px-4">CONFIDENCE</th>
                  <th className="py-3 px-4">DISPATCH STATUS</th>
                  <th className="py-3 px-4">TRIAGED</th>
                  <th className="py-3 px-4 text-right">ACTIONS</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-sentinel-border/50">
                {filteredLogs.map((log) => (
                  <tr
                    key={log._id}
                    onClick={() => onSelectIncident(log)}
                    className="hover:bg-white/[0.02] transition-colors cursor-pointer"
                  >
                    <td className="py-3.5 px-4 text-sentinel-muted whitespace-nowrap">
                      {new Date(log.frameTimestamp || log.createdAt).toLocaleString()}
                    </td>
                    <td className="py-3.5 px-4">
                      <span className="font-bold text-white block">{log.threatClass}</span>
                      {log.audioTranscript && (
                        <span className="text-[10px] text-sentinel-warning block truncate max-w-xs mt-0.5">
                          "{log.audioTranscript}"
                        </span>
                      )}
                    </td>
                    <td className="py-3.5 px-4">
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
                    <td className="py-3.5 px-4 text-sentinel-text">
                      <div>{log.cameraId}</div>
                      <div className="text-[10px] text-sentinel-muted">{log.location}</div>
                    </td>
                    <td className="py-3.5 px-4 text-sentinel-cyan font-semibold">
                      {((log.confidence || 0.95) * 100).toFixed(1)}%
                    </td>
                    <td className="py-3.5 px-4">
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
                    <td className="py-3.5 px-4">
                      {log.isAcknowledged ? (
                        <span className="text-sentinel-success flex items-center gap-1 text-[11px] font-bold">
                          <CheckCircle className="w-3.5 h-3.5" />
                          ACK
                        </span>
                      ) : (
                        <button
                          onClick={(e) => handleAcknowledge(log._id, e)}
                          disabled={!isAnalyst && !isAdmin}
                          className="px-2 py-0.5 rounded bg-sentinel-warning/10 border border-sentinel-warning/30 text-sentinel-warning hover:bg-sentinel-warning/20 text-[10px]"
                        >
                          ACK
                        </button>
                      )}
                    </td>
                    <td className="py-3.5 px-4 text-right">
                      <div className="flex items-center justify-end gap-2">
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            onSelectIncident(log);
                          }}
                          className="p-1.5 rounded bg-sentinel-elevated hover:bg-sentinel-card text-sentinel-muted hover:text-white transition-colors"
                          title="View Details"
                        >
                          <Eye className="w-3.5 h-3.5" />
                        </button>
                        {isAdmin && (
                          <button
                            onClick={(e) => handleDelete(log._id, e)}
                            className="p-1.5 rounded bg-sentinel-critical/10 hover:bg-sentinel-critical/20 text-sentinel-critical transition-colors"
                            title="Delete Log (Admin Only)"
                          >
                            <Trash2 className="w-3.5 h-3.5" />
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {/* Pagination Footer */}
        <div className="flex items-center justify-between px-4 py-3 border-t border-sentinel-border bg-sentinel-bg/80 text-xs font-mono text-sentinel-muted">
          <span>
            Total: {pagination.total} entries | Page {pagination.page} of {pagination.pages}
          </span>
          <div className="flex items-center gap-2">
            <button
              onClick={() => fetchLogs(pagination.page - 1)}
              disabled={pagination.page <= 1}
              className="p-1.5 rounded border border-sentinel-border hover:border-sentinel-cyan disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
            >
              <ChevronLeft className="w-4 h-4" />
            </button>
            <button
              onClick={() => fetchLogs(pagination.page + 1)}
              disabled={pagination.page >= pagination.pages}
              className="p-1.5 rounded border border-sentinel-border hover:border-sentinel-cyan disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
            >
              <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
