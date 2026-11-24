// SentinelX - React Authentication & RBAC Context
// Exposes user session, role helpers, and login/logout state to all views.

import React, { createContext, useContext, useState, useEffect } from 'react';
import { authApi, getStoredTokens, clearStoredSession, refreshAccessToken } from '../api/client';

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    // Initial check: load stored user or refresh profile
    const initAuth = async () => {
      const { user: storedUser, accessToken } = getStoredTokens();
      if (storedUser && accessToken) {
        setUser(storedUser);
        try {
          const profile = await authApi.getMe();
          if (profile.success && profile.data) {
            setUser(profile.data);
          }
        } catch {
          // Token expired or invalid; attempt silent cookie refresh
          try {
            const newToken = await refreshAccessToken();
            if (newToken) {
              const profile = await authApi.getMe();
              if (profile.success && profile.data) {
                setUser(profile.data);
              }
            }
          } catch (_) {}
        }
      } else {
        // No stored token; check if valid session cookie exists
        try {
          const newToken = await refreshAccessToken();
          if (newToken) {
            const profile = await authApi.getMe();
            if (profile.success && profile.data) {
              setUser(profile.data);
            }
          }
        } catch (_) {}
      }
      setLoading(false);
    };

    initAuth();
  }, []);

  const login = async (email, password) => {
    setError(null);
    try {
      const res = await authApi.login(email, password);
      if (res.success && res.data?.user) {
        setUser(res.data.user);
        return { success: true };
      }
      throw new Error(res.error || 'Login failed');
    } catch (err) {
      setError(err.message);
      return { success: false, error: err.message };
    }
  };

  const logout = async () => {
    await authApi.logout();
    clearStoredSession();
    setUser(null);
    setError(null);
  };

  const role = user?.role || 'guest';
  const isAdmin = role === 'admin';
  const isPolice = role === 'police' || isAdmin;
  const isAnalyst = role === 'analyst' || isPolice || isAdmin;
  const isUser = Boolean(user);

  const value = {
    user,
    role,
    isAuthenticated: Boolean(user),
    loading,
    error,
    isAdmin,
    isPolice,
    isAnalyst,
    isUser,
    login,
    logout,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
