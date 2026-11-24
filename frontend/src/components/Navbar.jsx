// SentinelX Web - Header Navigation Bar
import React from 'react';
import { useAuth } from '../context/AuthContext';
import { Shield, Radio, Activity, LogOut, Bell, Zap } from 'lucide-react';

export const Navbar = ({ currentView, setCurrentView, onOpenDrillModal }) => {
  const { user, role, logout } = useAuth();

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

  return (
    <header className="sticky top-0 z-30 flex items-center justify-between px-6 py-3 border-b border-[rgba(255,255,255,0.08)] bg-[rgba(7,9,14,0.85)] backdrop-blur-md">
      {/* Brand Identity */}
      <div className="flex items-center gap-3 cursor-pointer" onClick={() => setCurrentView('dashboard')}>
        <div className="relative flex items-center justify-center w-10 h-10 rounded-lg bg-gradient-to-br from-[#00F0FF] to-[#3B82F6] shadow-[0_0_15px_rgba(0,240,255,0.35)]">
          <Shield className="w-5 h-5 text-black" strokeWidth={2.5} />
        </div>
        <div>
          <div className="flex items-center gap-2">
            <span className="text-lg font-extrabold tracking-wider font-display text-transparent bg-clip-text bg-gradient-to-r from-white via-[#E0F2FE] to-[#00F0FF]">
              SentinelX
            </span>
            <span className="text-[10px] font-mono px-1.5 py-0.5 rounded bg-[rgba(0,240,255,0.12)] text-[#00F0FF] border border-[rgba(0,240,255,0.3)]">
              MERN WEB
            </span>
          </div>
          <p className="text-[10px] tracking-widest text-[#9CA3AF] uppercase font-mono">
            COMMAND & DISPATCH CONSOLE
          </p>
        </div>
      </div>

      {/* Center System Telemetry Ticker */}
      <div className="hidden lg:flex items-center gap-6 px-4 py-1.5 rounded-full bg-[rgba(19,25,38,0.7)] border border-[rgba(255,255,255,0.06)] text-xs font-mono">
        <div className="flex items-center gap-2">
          <span className="pulse-dot pulse-live"></span>
          <span className="text-[#9CA3AF]">API:</span>
          <span className="text-[#34D399] font-semibold">PORT 3000 ONLINE</span>
        </div>
        <div className="w-px h-3 bg-gray-700"></div>
        <div className="flex items-center gap-2">
          <Radio className="w-3.5 h-3.5 text-[#00F0FF]" />
          <span className="text-[#9CA3AF]">DB:</span>
          <span className="text-[#00F0FF] font-semibold">MONGODB CONNECTED</span>
        </div>
        <div className="w-px h-3 bg-gray-700"></div>
        <div className="flex items-center gap-2">
          <Activity className="w-3.5 h-3.5 text-[#8B5CF6]" />
          <span className="text-[#9CA3AF]">ML:</span>
          <span className="text-[#A78BFA] font-semibold">ONNX / FASTAPI BRIDGE</span>
        </div>
      </div>

      {/* Right Controls & Profile */}
      <div className="flex items-center gap-3">
        {/* Quick Simulation Anomaly Trigger */}
        <button
          onClick={onOpenDrillModal}
          className="btn-critical text-xs py-1.5 px-3"
          title="Inject real anomaly into MongoDB and test cross-platform sync"
        >
          <Zap className="w-3.5 h-3.5" />
          <span className="hidden sm:inline">SIMULATE ANOMALY</span>
        </button>

        {/* User Role Badge & Profile */}
        <div className="flex items-center gap-3 pl-3 border-l border-gray-800">
          <div className="text-right hidden sm:block">
            <div className="text-xs font-semibold text-gray-200">
              {user?.name || 'Authorized Operator'}
            </div>
            <div className={`badge ${getRoleBadgeClass()} text-[9px] py-0 px-2 mt-0.5`}>
              {role.toUpperCase()}
            </div>
          </div>

          <button
            onClick={logout}
            className="p-2 text-gray-400 hover:text-red-400 transition-colors rounded-lg hover:bg-red-500/10 border border-transparent hover:border-red-500/20"
            title="Sign Out"
          >
            <LogOut className="w-4 h-4" />
          </button>
        </div>
      </div>
    </header>
  );
};
