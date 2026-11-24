// SentinelX Web - Sidebar Navigation
import React from 'react';
import { useAuth } from '../context/AuthContext';
import {
  LayoutDashboard,
  AlertTriangle,
  Radio,
  Video,
  Zap,
  Settings,
  ShieldCheck,
  Siren,
} from 'lucide-react';

export const Sidebar = ({ currentView, setCurrentView }) => {
  const { role, isPolice, isAdmin } = useAuth();

  const navItems = [
    {
      id: 'dashboard',
      label: 'Overview & Stats',
      icon: LayoutDashboard,
      roles: ['admin', 'analyst', 'police', 'user'],
    },
    {
      id: 'incidents',
      label: 'Incident Logs',
      icon: AlertTriangle,
      roles: ['admin', 'analyst', 'police', 'user'],
    },
    {
      id: 'police',
      label: 'Police Tactical Dispatch',
      icon: Siren,
      roles: ['admin', 'police'],
      highlight: true,
    },
    {
      id: 'cameras',
      label: 'Surveillance Feeds',
      icon: Video,
      roles: ['admin', 'analyst', 'police', 'user'],
    },
    {
      id: 'trigger',
      label: 'Drill & ML Bridge',
      icon: Zap,
      roles: ['admin', 'analyst', 'police'],
    },
    {
      id: 'settings',
      label: 'System Diagnostics',
      icon: Settings,
      roles: ['admin', 'analyst', 'police', 'user'],
    },
  ];

  const filteredItems = navItems.filter(item => item.roles.includes(role));

  return (
    <aside className="w-64 min-h-[calc(100vh-61px)] bg-[rgba(13,17,26,0.6)] backdrop-blur-md border-r border-[rgba(255,255,255,0.06)] p-4 flex flex-col justify-between">
      <div className="space-y-1">
        <div className="px-3 pb-2 text-[10px] font-mono tracking-widest text-gray-500 uppercase">
          NAVIGATION // PORTAL
        </div>

        {filteredItems.map(item => {
          const Icon = item.icon;
          const isActive = currentView === item.id;

          return (
            <button
              key={item.id}
              onClick={() => setCurrentView(item.id)}
              className={`w-full flex items-center gap-3 px-3.5 py-2.5 rounded-lg text-xs font-semibold font-mono tracking-wide transition-all ${
                isActive
                  ? 'bg-gradient-to-r from-[rgba(0,240,255,0.18)] to-[rgba(59,130,246,0.1)] text-[#00F0FF] border border-[rgba(0,240,255,0.35)] shadow-[0_0_12px_rgba(0,240,255,0.15)]'
                  : item.highlight
                  ? 'text-blue-400 hover:bg-blue-500/10 hover:text-blue-300'
                  : 'text-gray-400 hover:bg-[rgba(255,255,255,0.05)] hover:text-gray-200'
              }`}
            >
              <Icon className={`w-4 h-4 ${isActive ? 'text-[#00F0FF]' : item.highlight ? 'text-blue-400' : 'text-gray-500'}`} />
              <span>{item.label}</span>
              {item.highlight && (
                <span className="ml-auto w-2 h-2 rounded-full bg-blue-500 animate-pulse"></span>
              )}
            </button>
          );
        })}
      </div>

      {/* Bottom Status Card */}
      <div className="p-3 rounded-lg bg-[rgba(19,25,38,0.7)] border border-[rgba(255,255,255,0.06)] text-[11px] font-mono space-y-1.5">
        <div className="flex items-center justify-between text-gray-400">
          <span>ACTIVE SENSORS</span>
          <span className="text-[#34D399]">2 READY</span>
        </div>
        <div className="flex items-center justify-between text-gray-400">
          <span>CAM-001 (LAPTOP)</span>
          <span className="text-[#00F0FF]">LIVE</span>
        </div>
        <div className="flex items-center justify-between text-gray-400">
          <span>CAM-002 (PHONE)</span>
          <span className="text-[#38BDF8]">IP READY</span>
        </div>
        <div className="pt-2 border-t border-gray-800 flex items-center gap-2 text-gray-400">
          <ShieldCheck className="w-3.5 h-3.5 text-[#34D399]" />
          <span>RBAC LEVEL {isAdmin ? '3 (ADMIN)' : isPolice ? '2 (POLICE)' : '1 (USER)'}</span>
        </div>
      </div>
    </aside>
  );
};
