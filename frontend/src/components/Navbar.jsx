// SentinelX Web - Header Navigation Bar (Tactical Security Operations)
import React, { useState, useEffect } from 'react';
import { useAuth } from '../context/AuthContext';
import { detectApi, logsApi } from '../api/client';
import {
  Shield,
  Radio,
  Activity,
  LogOut,
  Zap,
  Menu,
  X,
  AlertOctagon,
  Wifi,
  WifiOff,
  User,
} from 'lucide-react';

export const Navbar = ({ currentView, setCurrentView, onOpenDrillModal, isMobileOpen, setIsMobileOpen }) => {
  const { user, role, logout } = useAuth();
  const [apiOnline, setApiOnline] = useState(true);
  const [dbOnline, setDbOnline] = useState(true);
  const [criticalCount, setCriticalCount] = useState(0);

  // Poll server health and active alerts
  useEffect(() => {
    let isMounted = true;

    const checkHealth = async () => {
      try {
        await detectApi.checkServerHealth();
        if (isMounted) setApiOnline(true);
      } catch {
        if (isMounted) setApiOnline(false);
      }

      try {
        const statsRes = await logsApi.getStats();
        if (isMounted && statsRes?.success) {
          setDbOnline(true);
          const activeCrit = statsRes.data?.bySeverity?.critical || 0;
          setCriticalCount(activeCrit);
        }
      } catch {
        if (isMounted) setDbOnline(false);
      }
    };

    checkHealth();
    const interval = setInterval(checkHealth, 8000);
    return () => {
      isMounted = false;
      clearInterval(interval);
    };
  }, []);

  const getRoleBadgeClass = () => {
    switch (role) {
      case 'admin':
        return 'badge-critical';
      case 'police':
        return 'badge-police';
      case 'analyst':
        return 'badge-high';
      default:
        return 'badge-normal';
    }
  };

  const getViewTitle = () => {
    switch (currentView) {
      case 'dashboard':
        return 'COMMAND OPERATIONS // REAL-TIME OVERVIEW';
      case 'cameras':
        return 'SURVEILLANCE FEEDS // MULTI-CAMERA MATRIX';
      case 'audio':
        return 'ACOUSTIC MONITOR // HARDWARE TELEMETRY & DSP';
      case 'incidents':
        return 'FORENSIC AUDIT // INCIDENT MANAGEMENT';
      case 'police':
        return 'TACTICAL CAD // POLICE DISPATCH QUEUE';
      case 'analytics':
        return 'SECURITY ANALYTICS // THREAT INTELLIGENCE & PATTERNS';
      case 'trigger':
        return 'DRILL SIMULATOR // ANOMALY INJECTION LAB';
      case 'users':
        return 'ACCESS CONTROL // OPERATOR & RBAC DIRECTORY';
      case 'settings':
        return 'INFRASTRUCTURE // SYSTEM HEALTH & DIAGNOSTICS';
      default:
        return 'SECURITY OPERATIONS CONSOLE';
    }
  };

  return (
    <header className="sticky top-0 z-30 flex items-center justify-between px-4 sm:px-6 py-2.5 border-b border-[rgba(255,255,255,0.08)] bg-[#0A0E1D]/90 backdrop-blur-xl">
      {/* Left: Mobile Toggle & Brand Identity */}
      <div className="flex items-center gap-3">
        {/* Mobile Hamburger Button */}
        <button
          onClick={() => setIsMobileOpen(!isMobileOpen)}
          className="lg:hidden p-2 text-sentinel-muted hover:text-white rounded-lg hover:bg-sentinel-card border border-transparent hover:border-white/10 transition-colors"
          aria-label="Toggle navigation menu"
        >
          {isMobileOpen ? <X className="w-5 h-5 text-sentinel-cyan" /> : <Menu className="w-5 h-5" />}
        </button>

        {/* Brand Logo & Name */}
        <div
          className="flex items-center gap-2.5 cursor-pointer select-none group"
          onClick={() => setCurrentView('dashboard')}
        >
          <div className="relative flex items-center justify-center w-9 h-9 rounded-xl bg-gradient-to-br from-[#00D9D9] to-[#477BFF] shadow-[0_0_18px_rgba(0,217,217,0.35)] transition-transform group-hover:scale-105">
            <Shield className="w-5 h-5 text-[#050811]" strokeWidth={2.5} />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <span className="text-base sm:text-lg font-black tracking-wider font-display text-transparent bg-clip-text bg-gradient-to-r from-white via-[#E0F2FE] to-[#00D9D9]">
                SentinelX
              </span>
              <span className="text-[9px] font-mono px-1.5 py-0.5 rounded bg-[rgba(0,217,217,0.12)] text-[#00D9D9] border border-[rgba(0,217,217,0.3)] font-semibold">
                SOC v1.0
              </span>
            </div>
            <p className="text-[9px] tracking-widest text-sentinel-muted uppercase font-mono hidden sm:block">
              COMMAND &amp; DISPATCH
            </p>
          </div>
        </div>

        {/* Dynamic Breadcrumb / Page Title */}
        <div className="hidden xl:flex items-center pl-4 ml-4 border-l border-white/10 text-xs font-mono tracking-wider text-sentinel-muted">
          <span className="text-white/40 mr-2">&gt;</span>
          <span className="text-white font-medium">{getViewTitle()}</span>
        </div>
      </div>

      {/* Center: System Telemetry Ticker */}
      <div className="hidden md:flex items-center gap-5 px-4 py-1.5 rounded-full bg-[#151F35]/80 border border-white/10 text-xs font-mono shadow-inner">
        {/* Backend API Connection */}
        <div className="flex items-center gap-2">
          {apiOnline ? (
            <>
              <span className="pulse-dot pulse-live"></span>
              <span className="text-sentinel-muted text-[11px]">API:</span>
              <span className="text-sentinel-success font-semibold text-[11px]">ONLINE</span>
            </>
          ) : (
            <>
              <span className="pulse-dot pulse-critical"></span>
              <span className="text-sentinel-muted text-[11px]">API:</span>
              <span className="text-sentinel-critical font-semibold text-[11px]">OFFLINE</span>
            </>
          )}
        </div>

        <div className="w-px h-3 bg-white/10"></div>

        {/* Database Status */}
        <div className="flex items-center gap-2">
          <Radio className="w-3.5 h-3.5 text-sentinel-cyan" />
          <span className="text-sentinel-muted text-[11px]">DB:</span>
          <span className={dbOnline ? "text-sentinel-cyan font-semibold text-[11px]" : "text-sentinel-critical font-semibold text-[11px]"}>
            {dbOnline ? "MONGODB ACTIVE" : "DB OFFLINE"}
          </span>
        </div>

        <div className="w-px h-3 bg-white/10"></div>

        {/* ML Inference Bridge */}
        <div className="flex items-center gap-2">
          <Activity className="w-3.5 h-3.5 text-purple-400" />
          <span className="text-sentinel-muted text-[11px]">ML:</span>
          <span className="text-purple-300 font-semibold text-[11px]">ONNX RUNTIME</span>
        </div>
      </div>

      {/* Right Controls: Threat Banner, Quick Drill, Profile */}
      <div className="flex items-center gap-2.5 sm:gap-3">
        {/* Active Emergency Indicator */}
        {criticalCount > 0 && (
          <button
            onClick={() => setCurrentView('incidents')}
            className="flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-sentinel-critical/20 text-sentinel-critical border border-sentinel-critical/40 hover:bg-sentinel-critical/30 transition-colors text-xs font-mono animate-pulse"
            title="Active Critical Alerts Pending Review"
          >
            <AlertOctagon className="w-3.5 h-3.5" />
            <span className="font-bold">{criticalCount} CRITICAL</span>
          </button>
        )}

        {/* Quick Anomaly Simulation Drill Button */}
        <button
          onClick={onOpenDrillModal}
          className="btn-critical text-xs py-1.5 px-3 flex items-center gap-1.5"
          title="Inject real anomaly into MongoDB and test cross-platform sync"
        >
          <Zap className="w-3.5 h-3.5" />
          <span className="hidden sm:inline">INJECT DRILL</span>
        </button>

        {/* User Role Badge & Profile */}
        <div className="flex items-center gap-2.5 pl-2 sm:pl-3 border-l border-white/10">
          <div className="text-right hidden sm:block">
            <div className="text-xs font-semibold text-white truncate max-w-[140px]">
              {user?.name || 'Authorized Operator'}
            </div>
            <div className={`badge ${getRoleBadgeClass()} text-[9px] py-0 px-2 mt-0.5`}>
              {role.toUpperCase()}
            </div>
          </div>

          {/* Logout Action */}
          <button
            onClick={logout}
            className="p-2 text-sentinel-muted hover:text-sentinel-critical hover:bg-sentinel-critical/10 rounded-lg border border-transparent hover:border-sentinel-critical/20 transition-all"
            title="Sign Out of Session"
          >
            <LogOut className="w-4 h-4" />
          </button>
        </div>
      </div>
    </header>
  );
};
