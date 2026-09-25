import React, { useState, useEffect, useCallback, useRef } from 'react';
import Header from './components/Header';
import MapView from './components/MapView';
import RouteSearch from './components/RouteSearch';
import RouteComparison from './components/RouteComparison';
import AQIForecast from './components/AQIForecast';
import UserProfile from './components/UserProfile';
import LandingPage from './components/LandingPage';
import {
  getStations,
  compareRoutes,
  checkPositionAQI,
  createProfile,
} from './services/api';
import { initFirebase, onFCMMessage, showBrowserNotification } from './services/firebase';

export default function App() {
  // View mode: 'landing' or 'app' (map view)
  const [viewMode, setViewMode] = useState('landing');

  // Theme State: 'dark' by default for a high-tech command center feel, or preserved from storage
  const [theme, setTheme] = useState(() => {
    return localStorage.getItem('aqi_theme') || 'dark';
  });

  // Sidebar visibility state
  const [sidebarOpen, setSidebarOpen] = useState(true);

  // App Data States
  const [stations, setStations] = useState([]);
  const [selectedStation, setSelectedStation] = useState(null);
  const [routes, setRoutes] = useState([]);
  const [safestIndex, setSafestIndex] = useState(0);
  const [activeRouteIndex, setActiveRouteIndex] = useState(0);
  const [showTraffic, setShowTraffic] = useState(false);
  const [userLocation, setUserLocation] = useState(null);
  const [locating, setLocating] = useState(false);
  const [loadingRoutes, setLoadingRoutes] = useState(false);
  const [userProfile, setUserProfile] = useState(null);
  const [showProfileModal, setShowProfileModal] = useState(false);
  const [toasts, setToasts] = useState([]);
  const [userLocationAQI, setUserLocationAQI] = useState(null);
  const [routeMeta, setRouteMeta] = useState({
    origin: 'Connaught Place, New Delhi',
    destination: 'Indira Gandhi International Airport (T3), Delhi',
    originAQI: null,
    destCurrentAQI: null,
    destPredictedAQI: null,
  });

  // Apply theme to DOM
  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('aqi_theme', theme);
  }, [theme]);

  const toggleTheme = () => {
    setTheme((prev) => (prev === 'dark' ? 'light' : 'dark'));
  };

  const userProfileRef = useRef(userProfile);
  useEffect(() => {
    userProfileRef.current = userProfile;
  }, [userProfile]);

  const initialLoadedRef = useRef(false);

  // Toast notification system
  const addToast = useCallback((title, message, type = 'warning') => {
    const id = Date.now();
    setToasts((prev) => {
      const filtered = prev.filter((t) => t.title !== title);
      return [...filtered.slice(-2), { id, title, message, type }];
    });
    showBrowserNotification(title, message);
    setTimeout(() => {
      setToasts((prev) => prev.filter((t) => t.id !== id));
    }, 5000);
  }, []);

  const removeToast = (id) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  };

  // Route Comparison Search
  const handleRouteSearch = useCallback(async (origin, destination) => {
    setLoadingRoutes(true);
    try {
      const res = await compareRoutes(origin, destination, userProfileRef.current?.id);
      const data = res.data;
      setRoutes(data.routes || []);
      setSafestIndex(data.safest_route_index || 0);
      setActiveRouteIndex(data.safest_route_index || 0);
      setRouteMeta({
        origin: data.origin || origin,
        destination: data.destination || destination,
        originAQI: data.origin_aqi,
        destCurrentAQI: data.destination_current_aqi,
        destPredictedAQI: data.destination_predicted_aqi,
      });

      // Ensure sidebar is open to display results
      setSidebarOpen(true);

      if (data.alert_triggered && data.alert_message) {
        addToast('Route Exposure Alert', data.alert_message, 'danger');
      } else {
        addToast(
          'Routes Analyzed',
          `Evaluated ${data.routes?.length} routes via spatial IDW. Green corridor indicates lowest cumulative exposure.`,
          'success'
        );
      }
    } catch (err) {
      console.error('Route comparison error:', err);
      const msg = err.response?.data?.detail || 'Could not fetch route directions. Check API keys and inputs.';
      addToast('Route Query Error', msg, 'danger');
    } finally {
      setLoadingRoutes(false);
    }
  }, [addToast]);

  // Initialize Stations & Firebase
  useEffect(() => {
    if (initialLoadedRef.current) return;
    initialLoadedRef.current = true;

    initFirebase();
    onFCMMessage((payload) => {
      addToast(
        payload.notification?.title || 'Air Quality Alert',
        payload.notification?.body || 'High AQI threshold reached on your path!',
        'danger'
      );
    });

    // Load Delhi monitoring stations
    getStations()
      .then((res) => {
        setStations(res.data || []);
        if (res.data && res.data.length > 0) {
          const defaultStation = res.data.find((s) => s.station_id === 'DL014') || res.data[0];
          setSelectedStation(defaultStation);
        }
      })
      .catch((err) => console.error('Failed to load stations:', err));

    // Load or create commuter profile
    const savedProfile = localStorage.getItem('aqi_user_profile');
    if (savedProfile) {
      try {
        setUserProfile(JSON.parse(savedProfile));
      } catch (_e) {
        // ignore
      }
    } else {
      createProfile({
        name: 'Delhi Commuter',
        health_category: 'normal',
        custom_threshold: 250,
      })
        .then((res) => {
          setUserProfile(res.data);
          localStorage.setItem('aqi_user_profile', JSON.stringify(res.data));
        })
        .catch((err) => console.error('Error creating default profile:', err));
    }
  }, [addToast, handleRouteSearch]);

  // Geolocation Workflow
  const handleLocateUser = useCallback(() => {
    if (!navigator.geolocation) {
      addToast('Location Error', 'Geolocation is not supported by your browser.', 'warning');
      return;
    }

    setLocating(true);
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const coords = { lat: pos.coords.latitude, lng: pos.coords.longitude };
        setUserLocation(coords);
        setLocating(false);

        checkPositionAQI(coords.lat, coords.lng, userProfile?.id)
          .then((res) => {
            const data = res.data;
            const aqiVal = data.interpolated?.aqi;
            setUserLocationAQI(Math.round(aqiVal || 0));

            if (data.alert_triggered) {
              addToast(
                '⚠️ Health Threshold Warning',
                data.alert_message || `Local AQI is ${Math.round(aqiVal)}, exceeding your sensitivity threshold!`,
                'danger'
              );
            } else {
              addToast(
                'Location Detected',
                `Current interpolated AQI at your spot: ${Math.round(aqiVal || 0)} (${data.classification?.label || 'Moderate'})`,
                'success'
              );
            }
          })
          .catch((err) => console.error('Position check error:', err));
      },
      (err) => {
        setLocating(false);
        console.warn('Geolocation denied or failed, using Connaught Place fallback:', err);
        const fallback = { lat: 28.6315, lng: 77.2167 };
        setUserLocation(fallback);
        addToast('Location Fallback', 'Using central Delhi coordinates.', 'warning');
      },
      { timeout: 10000, enableHighAccuracy: true }
    );
  }, [addToast, userProfile]);

  const handleProfileUpdate = (updated) => {
    setUserProfile(updated);
    localStorage.setItem('aqi_user_profile', JSON.stringify(updated));
    addToast('Profile Saved', `Updated health persona to ${updated.health_category.toUpperCase()}`, 'success');
  };

  const handleOpenApp = () => {
    setViewMode('app');
    // Auto-search default route when entering map view
    if (routes.length === 0) {
      handleRouteSearch('Connaught Place, New Delhi', 'Indira Gandhi International Airport (T3), Delhi');
    }
  };

  const validAQIs = stations.filter((s) => s.aqi && !isNaN(s.aqi)).map((s) => s.aqi);
  const avgDelhiAQI = validAQIs.length > 0 ? validAQIs.reduce((a, b) => a + b, 0) / validAQIs.length : 0;

  // ─── LANDING PAGE VIEW ───
  if (viewMode === 'landing') {
    return (
      <div className="app-landing-wrapper" data-theme={theme}>
        {/* Slim Navigation Bar for Landing */}
        <nav className="landing-nav">
          <div className="landing-nav-brand" onClick={() => setViewMode('landing')}>
            <div className="logo-icon">🌿</div>
            <div className="logo-text-group">
              <div className="logo-text">
                <span>AeroMobility AI</span>
                <span className="logo-badge">LSTM 2.0</span>
              </div>
            </div>
          </div>
          <div className="landing-nav-actions">
            <button className="btn btn-secondary btn-sm" onClick={() => setShowProfileModal(true)}>
              <span>🛡️</span>
              <span>{userProfile?.name || 'Profile'}</span>
            </button>
            {toggleTheme && (
              <button
                className="header-icon-btn"
                onClick={toggleTheme}
                title={theme === 'dark' ? 'Switch to Light Theme' : 'Switch to Dark Theme'}
              >
                {theme === 'dark' ? '☀️' : '🌙'}
              </button>
            )}
            <button className="btn btn-primary btn-sm" onClick={handleOpenApp}>
              <span>🗺️</span>
              <span>Open Map</span>
            </button>
          </div>
        </nav>

        <LandingPage
          stations={stations}
          userProfile={userProfile}
          onProfileUpdate={handleProfileUpdate}
          avgDelhiAQI={avgDelhiAQI}
          theme={theme}
          onOpenApp={handleOpenApp}
        />

        {/* User Health Profile Modal Dialog */}
        {showProfileModal && (
          <UserProfile
            profile={userProfile}
            onProfileUpdate={handleProfileUpdate}
            onClose={() => setShowProfileModal(false)}
          />
        )}

        {/* Notification Toasts */}
        <div className="alert-toast">
          {toasts.map((t) => (
            <div key={t.id} className={`toast ${t.type}`}>
              <div className="toast-icon">
                {t.type === 'danger' ? '⚠️' : t.type === 'success' ? '✅' : 'ℹ️'}
              </div>
              <div className="toast-content">
                <div className="toast-title">{t.title}</div>
                <div className="toast-message">{t.message}</div>
              </div>
              <button className="toast-close" onClick={() => removeToast(t.id)}>
                ✕
              </button>
            </div>
          ))}
        </div>
      </div>
    );
  }

  // ─── MAP APP VIEW ───
  return (
    <div className={`app-layout ${!sidebarOpen ? 'sidebar-collapsed-active' : ''}`}>
      {/* Top Header */}
      <Header
        showTraffic={showTraffic}
        onToggleTraffic={setShowTraffic}
        onLocateUser={handleLocateUser}
        locating={locating}
        userProfile={userProfile}
        onOpenProfile={() => setShowProfileModal(true)}
        avgDelhiAQI={avgDelhiAQI}
        theme={theme}
        onToggleTheme={toggleTheme}
        sidebarOpen={sidebarOpen}
        onToggleSidebar={() => setSidebarOpen((prev) => !prev)}
        onGoHome={() => setViewMode('landing')}
      />

      {/* Main View Area */}
      <main className="app-main">
        {/* Floating Sidebar Toggle Button when closed */}
        {!sidebarOpen && (
          <button
            type="button"
            className="sidebar-floating-toggle"
            onClick={() => setSidebarOpen(true)}
            title="Open Route Search & Analytics"
          >
            <span>🧭</span>
            <span>Plan Route</span>
          </button>
        )}

        {/* Floating Intelligent Command Sidebar */}
        <aside className={`sidebar ${!sidebarOpen ? 'collapsed' : ''}`}>
          <div className="sidebar-header-bar">
            <div className="sidebar-title-badge">
              <span>🌿</span>
              <span>Mobility & Air Quality Intelligence</span>
            </div>
            <button
              type="button"
              className="sidebar-close-btn"
              onClick={() => setSidebarOpen(false)}
              title="Collapse Panel (Maximize Map)"
            >
              ✕
            </button>
          </div>

          <div className="sidebar-content">
            {/* Spot AQI Indicator */}
            {userLocationAQI !== null && (
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '8px',
                  padding: '8px 12px',
                  borderRadius: 'var(--radius-sm)',
                  background: 'var(--accent-emerald-light)',
                  border: '1px solid rgba(16, 185, 129, 0.3)',
                  fontSize: '0.78rem',
                  color: 'var(--accent-emerald)',
                }}
              >
                <span style={{ fontSize: '1rem' }}>📍</span>
                <div>
                  <span style={{ fontWeight: 700 }}>Your Spot AQI: {userLocationAQI}</span>
                  <span style={{ marginLeft: '6px', color: 'var(--text-tertiary)', fontSize: '0.72rem' }}>
                    (Live Spatial IDW)
                  </span>
                </div>
              </div>
            )}

            {/* Route Search Box */}
            <RouteSearch
              onSearch={handleRouteSearch}
              loading={loadingRoutes}
              userLocation={userLocation}
              stations={stations}
            />

            {/* Route Comparison Cards */}
            {routes.length > 0 && (
              <RouteComparison
                routes={routes}
                safestIndex={safestIndex}
                activeRouteIndex={activeRouteIndex}
                onSelectRoute={setActiveRouteIndex}
                userProfile={userProfile}
              />
            )}

            {/* 24-Hour Neural LSTM Forecast */}
            {selectedStation && (
              <AQIForecast
                station={selectedStation}
                onClose={() => setSelectedStation(null)}
              />
            )}
          </div>
        </aside>

        {/* Interactive Google Map View */}
        <section className="map-container">
          <MapView
            stations={stations}
            selectedStation={selectedStation}
            onSelectStation={(st) => {
              setSelectedStation(st);
              setSidebarOpen(true);
            }}
            routes={routes}
            safestIndex={safestIndex}
            activeRouteIndex={activeRouteIndex}
            onSelectRoute={setActiveRouteIndex}
            showTraffic={showTraffic}
            userLocation={userLocation}
            routeMeta={routeMeta}
            onQuickSearch={handleRouteSearch}
            avgDelhiAQI={avgDelhiAQI}
            theme={theme}
          />
        </section>
      </main>

      {/* User Health Profile Modal Dialog */}
      {showProfileModal && (
        <UserProfile
          profile={userProfile}
          onProfileUpdate={handleProfileUpdate}
          onClose={() => setShowProfileModal(false)}
        />
      )}

      {/* Notification Toasts */}
      <div className="alert-toast">
        {toasts.map((t) => (
          <div key={t.id} className={`toast ${t.type}`}>
            <div className="toast-icon">
              {t.type === 'danger' ? '⚠️' : t.type === 'success' ? '✅' : 'ℹ️'}
            </div>
            <div className="toast-content">
              <div className="toast-title">{t.title}</div>
              <div className="toast-message">{t.message}</div>
            </div>
            <button className="toast-close" onClick={() => removeToast(t.id)}>
              ✕
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}
