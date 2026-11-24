// SentinelX Web - Operator Directory & RBAC Management
import React, { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { authApi } from '../api/client';
import {
  Users,
  Shield,
  UserPlus,
  Lock,
} from 'lucide-react';

export const UserManagementView = () => {
  const { isAdmin } = useAuth();

  const [newName, setNewName] = useState('');
  const [newEmail, setNewEmail] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [newRole, setNewRole] = useState('user');
  const [submitting, setSubmitting] = useState(false);
  const [statusMsg, setStatusMsg] = useState(null);

  // Pre-configured system operators
  const [operators, setOperators] = useState([
    {
      id: 'OP-001',
      name: 'System Administrator',
      email: 'admin@sentinelx.local',
      role: 'admin',
      status: 'Active',
      lastLogin: 'Just now',
    },
    {
      id: 'OP-002',
      name: 'Officer Vance',
      email: 'police@sentinelx.local',
      role: 'police',
      status: 'Active',
      lastLogin: '12 min ago',
    },
    {
      id: 'OP-003',
      name: 'Threat Analyst Sarah',
      email: 'analyst@sentinelx.local',
      role: 'analyst',
      status: 'Active',
      lastLogin: '45 min ago',
    },
    {
      id: 'OP-004',
      name: 'Field Guard Alex',
      email: 'user@sentinelx.local',
      role: 'user',
      status: 'Active',
      lastLogin: '2 hrs ago',
    },
  ]);

  const handleCreateUser = async (e) => {
    e.preventDefault();
    if (!isAdmin) {
      setStatusMsg({ type: 'error', text: 'Administrative privileges required to register operators.' });
      return;
    }

    setSubmitting(true);
    setStatusMsg(null);

    try {
      const res = await authApi.register({
        name: newName,
        email: newEmail,
        password: newPassword,
        role: newRole,
      });

      if (res.success) {
        setOperators((prev) => [
          ...prev,
          {
            id: `OP-00${prev.length + 1}`,
            name: newName,
            email: newEmail,
            role: newRole,
            status: 'Active',
            lastLogin: 'Never',
          },
        ]);
        setStatusMsg({ type: 'success', text: `Operator ${newEmail} successfully provisioned!` });
        setNewName('');
        setNewEmail('');
        setNewPassword('');
        setNewRole('user');
      } else {
        setStatusMsg({ type: 'error', text: res.message || 'Failed to create operator.' });
      }
    } catch (err) {
      setStatusMsg({ type: 'error', text: err.message });
    } finally {
      setSubmitting(false);
    }
  };

  const getRoleBadge = (r) => {
    switch (r) {
      case 'admin':
        return <span className="badge badge-critical">ADMIN</span>;
      case 'police':
        return <span className="badge badge-police">POLICE</span>;
      case 'analyst':
        return <span className="badge badge-high">ANALYST</span>;
      default:
        return <span className="badge badge-normal">USER</span>;
    }
  };

  return (
    <div className="p-6 space-y-6 max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <h1 className="text-2xl font-black font-display tracking-wider text-white">
              OPERATOR DIRECTORY & ACCESS CONTROL
            </h1>
            <span className="badge badge-normal text-[10px]">RBAC ENFORCED</span>
          </div>
          <p className="text-xs font-mono text-sentinel-muted">
            Manage authenticated security personnel, roles, and administrative credentials.
          </p>
        </div>
      </div>

      {statusMsg && (
        <div
          className={`p-3 rounded-lg border text-xs font-mono flex items-center justify-between ${
            statusMsg.type === 'success'
              ? 'bg-sentinel-success/10 border-sentinel-success/30 text-sentinel-success'
              : 'bg-sentinel-critical/10 border-sentinel-critical/30 text-sentinel-critical'
          }`}
        >
          <span>{statusMsg.text}</span>
          <button onClick={() => setStatusMsg(null)} className="text-sentinel-muted hover:text-white">
            ✕
          </button>
        </div>
      )}

      {/* Main Grid: Operator Roster + Provisioning Form */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Left 7 Cols: Operator Roster Table */}
        <div className="lg:col-span-7 sentinel-card p-5 space-y-4">
          <div className="flex items-center justify-between border-b border-sentinel-border pb-3">
            <span className="text-xs font-mono font-bold uppercase tracking-wider text-white flex items-center gap-2">
              <Users className="w-4 h-4 text-sentinel-cyan" />
              AUTHENTICATED OPERATOR ROSTER
            </span>
            <span className="text-[10px] font-mono text-sentinel-muted">{operators.length} OPERATORS</span>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left font-mono text-xs">
              <thead>
                <tr className="border-b border-sentinel-border text-sentinel-muted text-[10px] uppercase tracking-wider">
                  <th className="py-2.5 px-3">OPERATOR</th>
                  <th className="py-2.5 px-3">ROLE</th>
                  <th className="py-2.5 px-3">STATUS</th>
                  <th className="py-2.5 px-3 text-right">LAST SEEN</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-sentinel-border/50">
                {operators.map((op) => (
                  <tr key={op.id} className="hover:bg-white/[0.02] transition-colors">
                    <td className="py-3 px-3">
                      <div className="font-bold text-white">{op.name}</div>
                      <div className="text-[10px] text-sentinel-muted">{op.email}</div>
                    </td>
                    <td className="py-3 px-3">{getRoleBadge(op.role)}</td>
                    <td className="py-3 px-3">
                      <span className="text-[10px] text-sentinel-success font-semibold flex items-center gap-1">
                        <span className="w-1.5 h-1.5 rounded-full bg-sentinel-success" />
                        {op.status}
                      </span>
                    </td>
                    <td className="py-3 px-3 text-right text-sentinel-muted text-[10px]">
                      {op.lastLogin}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        {/* Right 5 Cols: Register Operator (Admin Only) */}
        <div className="lg:col-span-5 sentinel-card p-5 space-y-4">
          <div className="flex items-center justify-between border-b border-sentinel-border pb-3">
            <span className="text-xs font-mono font-bold uppercase tracking-wider text-white flex items-center gap-2">
              <UserPlus className="w-4 h-4 text-sentinel-cyan" />
              PROVISION NEW OPERATOR
            </span>
            {isAdmin ? (
              <span className="badge badge-normal text-[10px]">AUTHORIZED</span>
            ) : (
              <span className="badge badge-critical text-[10px]">RESTRICTED</span>
            )}
          </div>

          {!isAdmin ? (
            <div className="py-12 text-center text-sentinel-muted font-mono text-xs space-y-2">
              <Lock className="w-8 h-8 mx-auto text-sentinel-muted opacity-50" />
              <p>ADMINISTRATIVE PERMISSION REQUIRED</p>
              <p className="text-[10px]">Only administrators can register new user accounts.</p>
            </div>
          ) : (
            <form onSubmit={handleCreateUser} className="space-y-3 font-mono text-xs">
              <div>
                <label className="block text-sentinel-muted text-[10px] uppercase mb-1">Full Name</label>
                <input
                  type="text"
                  required
                  value={newName}
                  onChange={(e) => setNewName(e.target.value)}
                  placeholder="Officer Jane Doe"
                  className="w-full px-3 py-2 bg-sentinel-bg border border-sentinel-border focus:border-sentinel-cyan rounded-lg text-white text-xs outline-none"
                />
              </div>

              <div>
                <label className="block text-sentinel-muted text-[10px] uppercase mb-1">Email Address</label>
                <input
                  type="email"
                  required
                  value={newEmail}
                  onChange={(e) => setNewEmail(e.target.value)}
                  placeholder="jdoe@sentinelx.local"
                  className="w-full px-3 py-2 bg-sentinel-bg border border-sentinel-border focus:border-sentinel-cyan rounded-lg text-white text-xs outline-none"
                />
              </div>

              <div>
                <label className="block text-sentinel-muted text-[10px] uppercase mb-1">Password</label>
                <input
                  type="password"
                  required
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                  placeholder="••••••••••••"
                  className="w-full px-3 py-2 bg-sentinel-bg border border-sentinel-border focus:border-sentinel-cyan rounded-lg text-white text-xs outline-none"
                />
              </div>

              <div>
                <label className="block text-sentinel-muted text-[10px] uppercase mb-1">Security Role</label>
                <select
                  value={newRole}
                  onChange={(e) => setNewRole(e.target.value)}
                  className="w-full px-3 py-2 bg-sentinel-bg border border-sentinel-border focus:border-sentinel-cyan rounded-lg text-white text-xs outline-none"
                >
                  <option value="user">User (Field Guard)</option>
                  <option value="analyst">Analyst (Threat Forensics)</option>
                  <option value="police">Police (Tactical Patrol CAD)</option>
                  <option value="admin">Administrator (Full Control)</option>
                </select>
              </div>

              <button
                type="submit"
                disabled={submitting}
                className="w-full btn-primary py-2.5 text-xs font-mono tracking-wider uppercase mt-3"
              >
                {submitting ? 'PROVISIONING...' : '+ CREATE OPERATOR ACCOUNT'}
              </button>
            </form>
          )}
        </div>
      </div>

      {/* RBAC Matrix Card */}
      <div className="sentinel-card p-5 space-y-3 font-mono text-xs">
        <div className="flex items-center justify-between border-b border-sentinel-border pb-3">
          <span className="text-xs font-bold uppercase tracking-wider text-white flex items-center gap-2">
            <Shield className="w-4 h-4 text-sentinel-cyan" />
            ROLE-BASED ACCESS CONTROL (RBAC) PERMISSION MATRIX
          </span>
          <span className="text-[10px] text-sentinel-success">ENFORCED AT REST ENDPOINTS</span>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-sentinel-border text-sentinel-muted text-[10px] uppercase">
                <th className="py-2 px-3">CAPABILITY / ROUTE</th>
                <th className="py-2 px-3 text-center">ADMIN</th>
                <th className="py-2 px-3 text-center">POLICE</th>
                <th className="py-2 px-3 text-center">ANALYST</th>
                <th className="py-2 px-3 text-center">USER</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-sentinel-border/50 text-[11px]">
              <tr>
                <td className="py-2 px-3 text-white">View Dashboard & Telemetry</td>
                <td className="py-2 px-3 text-center text-sentinel-success font-bold">YES</td>
                <td className="py-2 px-3 text-center text-sentinel-success font-bold">YES</td>
                <td className="py-2 px-3 text-center text-sentinel-success font-bold">YES</td>
                <td className="py-2 px-3 text-center text-sentinel-success font-bold">YES</td>
              </tr>
              <tr>
                <td className="py-2 px-3 text-white">Live CCTV Feeds & Audio</td>
                <td className="py-2 px-3 text-center text-sentinel-success font-bold">YES</td>
                <td className="py-2 px-3 text-center text-sentinel-success font-bold">YES</td>
                <td className="py-2 px-3 text-center text-sentinel-success font-bold">YES</td>
                <td className="py-2 px-3 text-center text-sentinel-success font-bold">YES</td>
              </tr>
              <tr>
                <td className="py-2 px-3 text-white">Acknowledge Anomaly Logs</td>
                <td className="py-2 px-3 text-center text-sentinel-success font-bold">YES</td>
                <td className="py-2 px-3 text-center text-sentinel-muted">NO</td>
                <td className="py-2 px-3 text-center text-sentinel-success font-bold">YES</td>
                <td className="py-2 px-3 text-center text-sentinel-muted">NO</td>
              </tr>
              <tr>
                <td className="py-2 px-3 text-white">Update Police CAD Dispatch</td>
                <td className="py-2 px-3 text-center text-sentinel-success font-bold">YES</td>
                <td className="py-2 px-3 text-center text-sentinel-success font-bold">YES</td>
                <td className="py-2 px-3 text-center text-sentinel-muted">NO</td>
                <td className="py-2 px-3 text-center text-sentinel-muted">NO</td>
              </tr>
              <tr>
                <td className="py-2 px-3 text-white">Trigger Simulation Drills</td>
                <td className="py-2 px-3 text-center text-sentinel-success font-bold">YES</td>
                <td className="py-2 px-3 text-center text-sentinel-muted">NO</td>
                <td className="py-2 px-3 text-center text-sentinel-success font-bold">YES</td>
                <td className="py-2 px-3 text-center text-sentinel-muted">NO</td>
              </tr>
              <tr>
                <td className="py-2 px-3 text-white">Delete Incident Records</td>
                <td className="py-2 px-3 text-center text-sentinel-success font-bold">YES</td>
                <td className="py-2 px-3 text-center text-sentinel-muted">NO</td>
                <td className="py-2 px-3 text-center text-sentinel-muted">NO</td>
                <td className="py-2 px-3 text-center text-sentinel-muted">NO</td>
              </tr>
              <tr>
                <td className="py-2 px-3 text-white">Operator Provisioning</td>
                <td className="py-2 px-3 text-center text-sentinel-success font-bold">YES</td>
                <td className="py-2 px-3 text-center text-sentinel-muted">NO</td>
                <td className="py-2 px-3 text-center text-sentinel-muted">NO</td>
                <td className="py-2 px-3 text-center text-sentinel-muted">NO</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};
