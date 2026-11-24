// SentinelX Web - Root Application Component
import React, { useState } from 'react';
import { AuthProvider, useAuth } from './context/AuthContext';
import { Navbar } from './components/Navbar';
import { Sidebar } from './components/Sidebar';
import { LoginView } from './views/LoginView';
import { DashboardView } from './views/DashboardView';
import { IncidentsView } from './views/IncidentsView';
import { PoliceView } from './views/PoliceView';
import { CameraFeedsView } from './views/CameraFeedsView';
import { DrillTriggerView } from './views/DrillTriggerView';
import { SettingsView } from './views/SettingsView';
import { IncidentModal } from './components/IncidentModal';

const AppContent = () => {
  const { isAuthenticated, loading } = useAuth();
  const [currentView, setCurrentView] = useState('dashboard');
  const [selectedIncident, setSelectedIncident] = useState(null);

  if (loading) {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center bg-[#07090E] text-white">
        <div className="w-8 h-8 border-2 border-cyan-400 border-t-transparent rounded-full animate-spin mb-4"></div>
        <p className="font-mono text-xs text-gray-400">INITIALIZING SENTINELX COMMAND SESSION...</p>
      </div>
    );
  }

  if (!isAuthenticated) {
    return <LoginView />;
  }

  const renderView = () => {
    switch (currentView) {
      case 'dashboard':
        return (
          <DashboardView
            onSelectIncident={setSelectedIncident}
            onOpenDrillModal={() => setCurrentView('trigger')}
          />
        );
      case 'incidents':
        return <IncidentsView onSelectIncident={setSelectedIncident} />;
      case 'police':
        return <PoliceView onSelectIncident={setSelectedIncident} />;
      case 'cameras':
        return <CameraFeedsView />;
      case 'trigger':
        return (
          <DrillTriggerView
            onIncidentTriggered={(newInc) => {
              setSelectedIncident(newInc);
            }}
          />
        );
      case 'settings':
        return <SettingsView />;
      default:
        return (
          <DashboardView
            onSelectIncident={setSelectedIncident}
            onOpenDrillModal={() => setCurrentView('trigger')}
          />
        );
    }
  };

  return (
    <div className="min-h-screen flex flex-col bg-[#07090E] text-white">
      {/* Top Navbar */}
      <Navbar
        currentView={currentView}
        setCurrentView={setCurrentView}
        onOpenDrillModal={() => setCurrentView('trigger')}
      />

      {/* Main Body */}
      <div className="flex-1 flex overflow-hidden">
        {/* Navigation Sidebar */}
        <Sidebar currentView={currentView} setCurrentView={setCurrentView} />

        {/* Dynamic Viewport */}
        <main className="flex-1 overflow-y-auto bg-[radial-gradient(ellipse_at_top,_var(--tw-gradient-stops))] from-[#0d1527] via-[#080c14] to-[#05070a]">
          {renderView()}
        </main>
      </div>

      {/* Forensic CCTV & Dispatch Modal */}
      {selectedIncident && (
        <IncidentModal
          incident={selectedIncident}
          onClose={() => setSelectedIncident(null)}
          onUpdated={(updated) => setSelectedIncident(updated)}
        />
      )}
    </div>
  );
};

export default function App() {
  return (
    <AuthProvider>
      <AppContent />
    </AuthProvider>
  );
}
