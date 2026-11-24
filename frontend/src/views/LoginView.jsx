// SentinelX Web - Login View
import React, { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { Shield, Lock, Mail, AlertCircle, ArrowRight, UserCheck } from 'lucide-react';

export const LoginView = () => {
  const { login } = useAuth();
  const [email, setEmail] = useState('admin@sentinelx.local');
  const [password, setPassword] = useState('ChangeMe!2024');
  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState(null);

  const demoAccounts = [
    { label: 'Admin', email: 'admin@sentinelx.local', desc: 'Control Room Director' },
    { label: 'Police', email: 'police@sentinelx.local', desc: 'Patrol Unit #104' },
    { label: 'Analyst', email: 'analyst@sentinelx.local', desc: 'Threat Forensics' },
    { label: 'User', email: 'user@sentinelx.local', desc: 'Field Guard' },
  ];

  const handleSelectRole = (roleEmail) => {
    setEmail(roleEmail);
    setPassword('ChangeMe!2024');
    setErrorMsg(null);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!email || !password) return;

    setLoading(true);
    setErrorMsg(null);

    const res = await login(email, password);
    setLoading(false);

    if (!res.success) {
      setErrorMsg(res.error || 'Failed to authenticate. Ensure Express backend is running on port 3000.');
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-4 bg-[radial-gradient(ellipse_at_top,_var(--tw-gradient-stops))] from-sentinel-sidebar via-sentinel-bg to-[#05070D]">
      <div className="w-full max-w-md">
        {/* Brand Header */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-gradient-to-br from-sentinel-cyan to-sentinel-blue shadow-[0_0_30px_rgba(0,217,217,0.3)] mb-4">
            <Shield className="w-8 h-8 text-black" strokeWidth={2.5} />
          </div>
          <h1 className="text-3xl font-extrabold tracking-wider font-display text-white">
            Sentinel<span className="text-sentinel-cyan">X</span>
          </h1>
          <p className="text-xs font-mono tracking-widest text-sentinel-muted uppercase mt-1">
            URBAN ANOMALY &amp; CRIME DETECTION PLATFORM
          </p>
        </div>

        {/* Login Card */}
        <div className="sentinel-card p-8 border border-sentinel-cyan/30 shadow-[0_0_40px_rgba(0,0,0,0.6)]">
          <div className="flex items-center justify-between pb-4 mb-5 border-b border-sentinel-border">
            <div>
              <h2 className="text-base font-bold text-white font-display">AUTHENTICATED ACCESS</h2>
              <p className="text-xs text-sentinel-muted">Security Command Console (MERN Stack)</p>
            </div>
            <span className="badge badge-normal text-[10px]">VER: 1.0</span>
          </div>

          {/* Quick Role Selector Pills */}
          <div className="mb-6">
            <label className="block text-[11px] font-mono text-sentinel-muted mb-2 uppercase tracking-wider">
              Quick Role Switcher (One-Click Demo):
            </label>
            <div className="grid grid-cols-2 gap-2">
              {demoAccounts.map(acc => {
                const isSelected = email === acc.email;
                return (
                  <button
                    key={acc.label}
                    type="button"
                    onClick={() => handleSelectRole(acc.email)}
                    className={`flex flex-col items-start p-2.5 rounded-lg border text-left transition-all ${
                      isSelected
                        ? 'border-sentinel-cyan bg-sentinel-cyan/15 shadow-[0_0_12px_rgba(0,217,217,0.2)]'
                        : 'border-sentinel-border bg-sentinel-bg/60 hover:border-sentinel-muted'
                    }`}
                  >
                    <div className="flex items-center justify-between w-full">
                      <span className="text-xs font-bold font-mono text-white">{acc.label}</span>
                      {isSelected && <UserCheck className="w-3.5 h-3.5 text-sentinel-cyan" />}
                    </div>
                    <span className="text-[10px] text-sentinel-muted truncate w-full">{acc.desc}</span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Form */}
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-xs font-mono text-sentinel-text mb-1.5">EMAIL ADDRESS</label>
              <div className="relative">
                <Mail className="w-4 h-4 text-sentinel-muted absolute left-3 top-3" />
                <input
                  type="email"
                  value={email}
                  onChange={e => setEmail(e.target.value)}
                  required
                  placeholder="operator@sentinelx.local"
                  className="w-full pl-9 pr-3 py-2 bg-sentinel-bg border border-sentinel-border focus:border-sentinel-cyan rounded-lg text-xs font-mono text-white focus:outline-none transition-colors"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-mono text-sentinel-text mb-1.5">PASSWORD</label>
              <div className="relative">
                <Lock className="w-4 h-4 text-sentinel-muted absolute left-3 top-3" />
                <input
                  type="password"
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  required
                  placeholder="••••••••••••"
                  className="w-full pl-9 pr-3 py-2 bg-sentinel-bg border border-sentinel-border focus:border-sentinel-cyan rounded-lg text-xs font-mono text-white focus:outline-none transition-colors"
                />
              </div>
            </div>

            {errorMsg && (
              <div className="p-3 rounded-lg bg-sentinel-critical/10 border border-sentinel-critical/30 flex items-start gap-2 text-xs text-sentinel-critical font-mono">
                <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
                <span>{errorMsg}</span>
              </div>
            )}

            <button
              type="submit"
              disabled={loading}
              className="w-full btn-primary justify-center py-2.5 text-xs font-mono tracking-wider uppercase mt-2"
            >
              {loading ? (
                <div className="flex items-center gap-2">
                  <div className="w-3.5 h-3.5 border-2 border-black/30 border-t-black rounded-full animate-spin" />
                  <span>AUTHENTICATING...</span>
                </div>
              ) : (
                <div className="flex items-center gap-2">
                  <span>ENTER COMMAND CONSOLE</span>
                  <ArrowRight className="w-4 h-4" />
                </div>
              )}
            </button>
          </form>

          <div className="mt-6 pt-4 border-t border-sentinel-border text-center text-[10px] text-sentinel-muted font-mono">
            CONNECTED TO LOCAL MONGODB COMMUNITY INSTANCE // REST PORT 3000
          </div>
        </div>
      </div>
    </div>
  );
};
