// SentinelX Web API Client
// Handles communication with Node.js Express backend (port 3000)
// Manages JWT access tokens and secure HttpOnly cookie refresh sessions.

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:3000';

const STORAGE_KEY_TOKEN = 'sentinelx_web_token';
const STORAGE_KEY_USER = 'sentinelx_web_user';

export const getStoredTokens = () => {
  return {
    accessToken: localStorage.getItem(STORAGE_KEY_TOKEN),
    // Refresh token is stored in HttpOnly cookie; never exposed to localStorage to prevent XSS theft
    refreshToken: null,
    user: JSON.parse(localStorage.getItem(STORAGE_KEY_USER) || 'null'),
  };
};

export const setStoredSession = ({ accessToken, user }) => {
  if (accessToken) localStorage.setItem(STORAGE_KEY_TOKEN, accessToken);
  if (user) localStorage.setItem(STORAGE_KEY_USER, JSON.stringify(user));
};

export const clearStoredSession = () => {
  localStorage.removeItem(STORAGE_KEY_TOKEN);
  localStorage.removeItem('sentinelx_web_refresh'); // Clean up any legacy token
  localStorage.removeItem(STORAGE_KEY_USER);
};

export const refreshAccessToken = async () => {
  try {
    const res = await fetch(`${API_BASE_URL}/api/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include', // Automatically attaches HttpOnly refreshToken cookie
      body: JSON.stringify({}),
    });
    const data = await res.json();
    if (res.ok && data.success && data.data?.accessToken) {
      localStorage.setItem(STORAGE_KEY_TOKEN, data.data.accessToken);
      return data.data.accessToken;
    }
  } catch (err) {
    console.warn('[API] Token refresh failed:', err);
  }
  clearStoredSession();
  return null;
};

// Generic HTTP request wrapper with auto-auth, credentials, and token refresh
export const apiRequest = async (endpoint, options = {}) => {
  const { accessToken } = getStoredTokens();
  const headers = {
    'Content-Type': 'application/json',
    Accept: 'application/json',
    ...(options.headers || {}),
  };

  if (accessToken && !options.skipAuth) {
    headers['Authorization'] = `Bearer ${accessToken}`;
  }

  let response;
  try {
    response = await fetch(`${API_BASE_URL}${endpoint}`, {
      credentials: 'include', // Supports cookies for session continuity & CSRF
      ...options,
      headers,
    });
  } catch (err) {
    throw new Error(`Cannot reach SentinelX server at ${API_BASE_URL}. (${err.message})`);
  }

  // Handle 401 Unauthorized by attempting a token refresh once
  if (response.status === 401 && !options._retry && !options.skipAuth) {
    const newToken = await refreshAccessToken();
    if (newToken) {
      headers['Authorization'] = `Bearer ${newToken}`;
      return apiRequest(endpoint, { ...options, headers, _retry: true });
    }
  }

  let body;
  try {
    body = await response.json();
  } catch {
    body = { success: response.ok, statusText: response.statusText };
  }

  if (!response.ok) {
    const errorMsg = body?.error || body?.message || `HTTP ${response.status}: Request failed`;
    const error = new Error(errorMsg);
    error.status = response.status;
    error.body = body;
    throw error;
  }

  return body;
};

// ─── Authentication API ───────────────────────────────────────────────────────

export const authApi = {
  login: async (email, password) => {
    const data = await apiRequest('/api/auth/login', {
      method: 'POST',
      skipAuth: true,
      body: JSON.stringify({ email, password }),
    });
    if (data.success && data.data) {
      setStoredSession({
        accessToken: data.data.accessToken,
        user: data.data.user,
      });
    }
    return data;
  },

  register: async ({ name, email, password, role }) => {
    return apiRequest('/api/auth/register', {
      method: 'POST',
      skipAuth: true,
      body: JSON.stringify({ name, email, password, role }),
    });
  },

  getMe: async () => {
    return apiRequest('/api/auth/me');
  },

  logout: async () => {
    try {
      await apiRequest('/api/auth/logout', {
        method: 'POST',
        credentials: 'include',
        body: JSON.stringify({}),
      });
    } catch (e) {
      console.warn('Logout API notification error:', e);
    } finally {
      clearStoredSession();
    }
  },
};

// ─── Crime & Anomaly Logs API ─────────────────────────────────────────────────

export const logsApi = {
  getLogs: async (params = {}) => {
    const query = new URLSearchParams();
    Object.entries(params).forEach(([k, v]) => {
      if (v !== undefined && v !== null && v !== '') {
        query.append(k, v);
      }
    });
    const queryString = query.toString() ? `?${query.toString()}` : '';
    return apiRequest(`/api/logs${queryString}`);
  },

  getLogById: async (id) => {
    return apiRequest(`/api/logs/${id}`);
  },

  getStats: async () => {
    return apiRequest('/api/logs/stats');
  },

  createLog: async (logData) => {
    return apiRequest('/api/logs', {
      method: 'POST',
      body: JSON.stringify(logData),
    });
  },

  updateDispatch: async (id, { dispatchStatus, assignedTo, policeNotes }) => {
    return apiRequest(`/api/logs/${id}/dispatch`, {
      method: 'PATCH',
      body: JSON.stringify({ dispatchStatus, assignedTo, policeNotes }),
    });
  },

  acknowledgeLog: async (id) => {
    return apiRequest(`/api/logs/${id}/acknowledge`, {
      method: 'PATCH',
    });
  },

  deleteLog: async (id) => {
    return apiRequest(`/api/logs/${id}`, {
      method: 'DELETE',
    });
  },

  triggerAnomaly: async (triggerData) => {
    return apiRequest('/api/logs/trigger', {
      method: 'POST',
      body: JSON.stringify(triggerData),
    });
  },
};

// ─── ML Detection API ─────────────────────────────────────────────────────────

export const detectApi = {
  runDetect: async ({ cameraId, location, frameTimestamp, videoFrames, audioData }) => {
    return apiRequest('/api/detect', {
      method: 'POST',
      body: JSON.stringify({ cameraId, location, frameTimestamp, videoFrames, audioData }),
    });
  },

  checkMlHealth: async () => {
    return apiRequest('/api/detect/health');
  },

  checkServerHealth: async () => {
    return apiRequest('/health', { skipAuth: true });
  },
};
