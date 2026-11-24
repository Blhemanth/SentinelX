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
    { label: 'Admin', email: 'admin@sentinelx.local', desc: 'Control Room Director', color: 'from-red-500 to-rose-600' },
    { label: 'Police', email: 'police@sentinelx.local', desc: 'Patrol Unit #104', color: 'from-blue-500 to-indigo-600' },
    { label: 'Analyst', email: 'analyst@sentinelx.local', desc: 'Threat Forensics', color: 'from-cyan-500 to-teal-600' },
    { label: 'User', email: 'user@sentinelx.local', desc: 'Field Guard', color: 'from-emerald-500 to-green-600' },
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
    <div className="min-h-screen flex items-center justify-center p-4 bg-gradient-to-br from-[#07090E] via-[#0A0D15] to-[#0E131F]">
      <div className="w-full max-w-md">
        {/* Brand Header */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-gradient-to-br from-[#00F0FF] to-[#3B82F6] shadow-[0_0_30px_rgba(0,240,255,0.3)] mb-4">
            <Shield className="w-8 h-8 text-black" strokeWidth={2.5} />
          </div>
          <h1 className="text-3xl font-extrabold tracking-wider font-display text-transparent bg-clip-text bg-gradient-to-r from-white via-[#E0F2FE] to-[#00F0FF]">
            SentinelX
          </h1>
          <p className="text-xs font-mono tracking-widest text-[#9CA3AF] uppercase mt-1">
            URBAN ANOMALY & CRIME DETECTION PLATFORM
          </p>
        </div>

        {/* Login Card */}
        <div className="glass-panel p-8 border border-[rgba(0,240,255,0.2)] shadow-[0_0_40px_rgba(0,0,0,0.6)]">
          <div className="flex items-center justify-between pb-4 mb-5 border-b border-gray-800">
            <div>
              <h2 className="text-base font-bold text-white font-display">AUTHENTICATED ACCESS</h2>
              <p className="text-xs text-gray-400">Security Command Console (MERN Stack)</p>
            </div>
            <span className="badge badge-normal text-[10px]">VER: 1.0</span>
          </div>

          {/* Quick Role Selector Pills */}
          <div className="mb-6">
            <label className="block text-[11px] font-mono text-gray-400 mb-2 uppercase tracking-wider">
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
                        ? 'border-[#00F0FF] bg-[rgba(0,240,255,0.12)] shadow-[0_0_12px_rgba(0,240,255,0.2)]'
                        : 'border-gray-800 bg-[rgba(19,25,38,0.5)] hover:border-gray-700'
                    }`}
                  >
                    <div className="flex items-center justify-between w-full">
                      <span className="text-xs font-bold font-mono text-white">{acc.label}</span>
                      {isSelected && <UserCheck className="w-3.5 h-3.5 text-[#00F0FF]" />}
                    </div>
                    <span className="text-[10px] text-gray-400 truncate w-full">{acc.desc}</span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Form */}
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-xs font-mono text-gray-300 mb-1.5">EMAIL ADDRESS</label>
              <div className="relative">
                <Mail className="w-4 h-4 text-gray-500 absolute left-3 top-3" />
                <input
                  type="email"
                  value={email}
                  onChange={e => setEmail(e.target.value)}
                  required
                  placeholder="operator@sentinelx.local"
                  className="w-full pl-9 pr-3 py-2 bg-[rgba(13,17,26,0.8)] border border-gray-800 focus:border-[#00F0FF] rounded-lg text-xs font-mono text-white focus:outline-none transition-colors"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-mono text-gray-300 mb-1.5">PASSWORD</label>
              <div className="relative">
                <Lock className="w-4 h-4 text-gray-500 absolute left-3 top-3" />
                <input
                  type="password"
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  required
                  placeholder="••••••••••••"
                  className="w-full pl-9 pr-3 py-2 bg-[rgba(13,17,26,0.8)] border border-gray-800 focus:border-[#00F0FF] rounded-lg text-xs font-mono text-white focus:outline-none transition-colors"
                />
              </div>
            </div>

            {errorMsg && (
              <div className="p-3 rounded-lg bg-red-500/10 border border-red-500/30 flex items-start gap-2 text-xs text-red-400">
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
                  <div className="w-3.5 h-3.5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
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

          <div className="mt-6 pt-4 border-t border-gray-800/80 text-center text-[10px] text-gray-500 font-mono">
            CONNECTED TO LOCAL MONGODB COMMUNITY INSTANCE // REST PORT 3000
          </div>
        </div>
      </div>
    </div>
  );
};
