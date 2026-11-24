// SentinelX Web - Sidebar Navigation (Tactical Security Operations)
import React from 'react';
import { useAuth } from '../context/AuthContext';
import {
  LayoutDashboard,
  AlertTriangle,
  Video,
  Volume2,
  Siren,
  TrendingUp,
  Zap,
  Users,
  Settings,
  ShieldCheck,
  LogOut,
  X,
} from 'lucide-react';

export const Sidebar = ({ currentView, setCurrentView, isMobileOpen, setIsMobileOpen }) => {
  const { user, role, isPolice, isAdmin, logout } = useAuth();

  const navItems = [
    {
      id: 'dashboard',
      label: 'Overview & Metrics',
      icon: LayoutDashboard,
      roles: ['admin', 'analyst', 'police', 'user'],
    },
    {
      id: 'cameras',
      label: 'Live Surveillance',
      icon: Video,
      roles: ['admin', 'analyst', 'police', 'user'],
    },
    {
      id: 'audio',
      label: 'Audio Telemetry',
      icon: Volume2,
      roles: ['admin', 'analyst', 'police', 'user'],
    },
    {
      id: 'incidents',
      label: 'Incident Management',
      icon: AlertTriangle,
      roles: ['admin', 'analyst', 'police', 'user'],
    },
    {
      id: 'police',
      label: 'Police Dispatch CAD',
      icon: Siren,
      roles: ['admin', 'police'],
      highlight: true,
    },
    {
      id: 'analytics',
      label: 'Threat Analytics',
      icon: TrendingUp,
      roles: ['admin', 'analyst', 'police', 'user'],
    },
    {
      id: 'trigger',
      label: 'Expo Drill Center',
      icon: Zap,
      roles: ['admin', 'analyst', 'police'],
    },
    {
      id: 'users',
      label: 'User Directory & RBAC',
      icon: Users,
      roles: ['admin'],
    },
    {
      id: 'settings',
      label: 'System Diagnostics',
      icon: Settings,
      roles: ['admin', 'analyst', 'police', 'user'],
    },
  ];

  const filteredItems = navItems.filter((item) => item.roles.includes(role));

  const handleNavClick = (id) => {
    setCurrentView(id);
    if (setIsMobileOpen) {
      setIsMobileOpen(false);
    }
  };

  const sidebarContent = (
    <aside className="w-64 h-full bg-[#10172A] border-r border-white/10 p-4 flex flex-col justify-between select-none">
      <div className="space-y-4">
        {/* Header row in mobile drawer */}
        <div className="flex items-center justify-between lg:hidden pb-2 border-b border-white/10">
          <span className="text-xs font-mono font-bold tracking-wider text-sentinel-cyan">
            NAVIGATION MENU
          </span>
          <button
            onClick={() => setIsMobileOpen(false)}
            className="p-1 text-sentinel-muted hover:text-white"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Section Label */}
        <div className="px-3 text-[10px] font-mono tracking-widest text-sentinel-muted uppercase font-bold">
          OPERATIONS // CONSOLE
        </div>

        {/* Navigation Item Links */}
        <nav className="space-y-1">
          {filteredItems.map((item) => {
            const Icon = item.icon;
            const isActive = currentView === item.id;

            return (
              <button
                key={item.id}
                onClick={() => handleNavClick(item.id)}
                className={`w-full flex items-center gap-3 px-3.5 py-2.5 rounded-lg text-xs font-semibold font-mono tracking-wide transition-all ${
                  isActive
                    ? 'bg-gradient-to-r from-sentinel-cyan/20 to-sentinel-blue/10 text-sentinel-cyan border-l-2 border-sentinel-cyan shadow-[0_0_15px_rgba(0,217,217,0.18)]'
                    : item.highlight
                    ? 'text-sentinel-blue hover:bg-sentinel-blue/10 hover:text-blue-300'
                    : 'text-sentinel-muted hover:bg-white/[0.04] hover:text-white'
                }`}
              >
                <Icon
                  className={`w-4 h-4 flex-shrink-0 ${
                    isActive ? 'text-sentinel-cyan' : item.highlight ? 'text-sentinel-blue' : 'text-sentinel-muted'
                  }`}
                />
                <span className="truncate">{item.label}</span>
                {item.highlight && (
                  <span className="ml-auto w-2 h-2 rounded-full bg-sentinel-blue animate-pulse"></span>
                )}
              </button>
            );
          })}
        </nav>
      </div>

      {/* Bottom Section: Sensor Monitor & Operator Status */}
      <div className="space-y-3 pt-4 border-t border-white/10">
        {/* Sensor Status Card */}
        <div className="p-3 rounded-xl bg-sentinel-card border border-white/5 text-[11px] font-mono space-y-1.5 shadow-inner">
          <div className="flex items-center justify-between text-sentinel-muted font-bold text-[10px] tracking-wider uppercase">
            <span>EDGE SENSORS</span>
            <span className="text-sentinel-success flex items-center gap-1">
              <span className="w-1.5 h-1.5 rounded-full bg-sentinel-success inline-block"></span>
              ONLINE
            </span>
          </div>

          <div className="flex items-center justify-between text-sentinel-muted">
            <span>CAM-001 (LAPTOP)</span>
            <span className="text-sentinel-cyan font-semibold">1080P HD</span>
          </div>

          <div className="flex items-center justify-between text-sentinel-muted">
            <span>CAM-002 (PHONE IP)</span>
            <span className="text-blue-400 font-semibold">STANDBY</span>
          </div>

          <div className="flex items-center justify-between text-sentinel-muted">
            <span>MIC ARRAY (PCM16)</span>
            <span className="text-emerald-400 font-semibold">16 kHz</span>
          </div>
        </div>

        {/* Current Operator Profile Card */}
        <div className="p-2.5 rounded-xl bg-sentinel-elevated border border-white/10 flex items-center justify-between">
          <div className="flex items-center gap-2.5 overflow-hidden">
            <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-sentinel-cyan/30 to-sentinel-blue/30 border border-sentinel-cyan/40 flex items-center justify-center flex-shrink-0">
              <ShieldCheck className="w-4 h-4 text-sentinel-cyan" />
            </div>
            <div className="truncate">
              <div className="text-xs font-semibold text-white truncate">
                {user?.name || 'Operator'}
              </div>
              <div className="text-[10px] font-mono text-sentinel-muted uppercase">
                {role.toUpperCase()} // LVL {isAdmin ? '3' : isPolice ? '2' : '1'}
              </div>
            </div>
          </div>

          <button
            onClick={logout}
            className="p-1.5 text-sentinel-muted hover:text-sentinel-critical hover:bg-sentinel-critical/10 rounded-lg transition-colors"
            title="Sign Out"
          >
            <LogOut className="w-4 h-4" />
          </button>
        </div>
      </div>
    </aside>
  );

  return (
    <>
      {/* Desktop Persistent Sidebar */}
      <div className="hidden lg:block h-[calc(100vh-57px)] flex-shrink-0">
        {sidebarContent}
      </div>

      {/* Mobile / Tablet Responsive Drawer Overlay */}
      {isMobileOpen && (
        <div className="fixed inset-0 z-40 lg:hidden flex">
          {/* Backdrop Blur */}
          <div
            className="fixed inset-0 bg-black/70 backdrop-blur-sm transition-opacity"
            onClick={() => setIsMobileOpen(false)}
          />
          {/* Sliding Drawer Container */}
          <div className="relative z-50 flex-1 max-w-xs h-full shadow-2xl">
            {sidebarContent}
          </div>
        </div>
      )}
    </>
  );
};
