import axios from 'axios';

const API_BASE = import.meta.env.VITE_API_BASE || 'http://localhost:8000';

const api = axios.create({
  baseURL: API_BASE,
  timeout: 15000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Automatic dual-port fallback between 8000 and 8001
api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;
    if (originalRequest && !originalRequest._retried) {
      const is8000 = (originalRequest.baseURL || api.defaults.baseURL || '').includes(':8000');
      const alternate = is8000 ? 'http://localhost:8001' : 'http://localhost:8000';
      
      if (error.code === 'ECONNABORTED' || error.code === 'ERR_NETWORK' || !error.response) {
        originalRequest._retried = true;
        originalRequest.baseURL = alternate;
        api.defaults.baseURL = alternate;
        return axios(originalRequest);
      }
    }
    return Promise.reject(error);
  }
);

// Station endpoints
export const getStations = () => api.get('/api/stations');
export const getStation = (id) => api.get(`/api/stations/${id}`);
export const getStationLive = (id) => api.get(`/api/stations/${id}/live`);

// Prediction endpoints
export const predictAQI = (stationId, hoursAhead = 24) =>
  api.post('/api/predict', { station_id: stationId, hours_ahead: hoursAhead });

// Route endpoints
export const compareRoutes = (origin, destination, userId = null) =>
  api.post('/api/routes/compare', { origin, destination, user_id: userId });

export const checkPositionAQI = (lat, lng, userId = null) =>
  api.post(`/api/routes/check-position?lat=${lat}&lng=${lng}${userId ? `&user_id=${userId}` : ''}`);

// Profile endpoints
export const createProfile = (data) => api.post('/api/profiles', data);
export const getProfile = (id) => api.get(`/api/profiles/${id}`);
export const updateProfile = (id, data) => api.put(`/api/profiles/${id}`, data);
export const listProfiles = () => api.get('/api/profiles');
export const getUserAlerts = (userId) => api.get(`/api/profiles/${userId}/alerts`);

// Health check
export const healthCheck = () => api.get('/api/health');

export default api;
