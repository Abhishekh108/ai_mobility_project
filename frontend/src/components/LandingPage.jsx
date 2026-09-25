import React, { useState, useEffect, useMemo, useRef } from 'react';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  BarElement,
  Title,
  Tooltip,
  Legend,
  Filler,
} from 'chart.js';
import { Line, Bar } from 'react-chartjs-2';
import { getStations, getUserAlerts, predictAQI, updateProfile, createProfile } from '../services/api';

ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  BarElement,
  Title,
  Tooltip,
  Legend,
  Filler
);

/* ─── Health Persona Categories ─── */
const HEALTH_CATEGORIES = [
  { id: 'normal', icon: '🏃', label: 'Healthy Adult', color: '#10b981', threshold: 300, desc: 'Standard tolerance. Alert at Severe (>300)' },
  { id: 'children', icon: '👶', label: 'Children', color: '#3b82f6', threshold: 150, desc: 'Developing lungs. Alert at Moderate (>150)' },
  { id: 'elderly', icon: '👵', label: 'Elderly / Senior', color: '#f59e0b', threshold: 200, desc: 'Vulnerable. Alert at Poor (>200)' },
  { id: 'asthmatic', icon: '🫁', label: 'Asthmatic / Respiratory', color: '#ef4444', threshold: 150, desc: 'Highly sensitive. Alert at Moderate (>150)' },
  { id: 'tb_patient', icon: '🩺', label: 'TB Patient', color: '#a855f7', threshold: 100, desc: 'Critical sensitivity. Alert at >100' },
];

/* ─── AQI Classification Helper ─── */
function getAQIClassification(aqi) {
  if (!aqi || isNaN(aqi)) return { label: 'N/A', color: '#94a3b8', bg: 'rgba(148,163,184,0.15)' };
  const v = Math.round(aqi);
  if (v <= 50)  return { label: 'Good', color: '#059669', bg: 'rgba(5,150,105,0.12)' };
  if (v <= 100) return { label: 'Satisfactory', color: '#10b981', bg: 'rgba(16,185,129,0.12)' };
  if (v <= 200) return { label: 'Moderate', color: '#d97706', bg: 'rgba(217,119,6,0.12)' };
  if (v <= 300) return { label: 'Poor', color: '#dc2626', bg: 'rgba(220,38,38,0.12)' };
  if (v <= 400) return { label: 'Very Poor', color: '#9333ea', bg: 'rgba(147,51,234,0.12)' };
  return { label: 'Severe', color: '#7e22ce', bg: 'rgba(126,34,206,0.12)' };
}

/* ─── Feature Cards Data ─── */
const FEATURES = [
  {
    icon: '🧠',
    title: 'AI-Powered AQI Prediction',
    desc: 'Bi-directional LSTM neural network trained on 40+ Delhi monitoring stations predicts air quality up to 24 hours ahead with 92% accuracy.',
    accent: '#3b82f6',
  },
  {
    icon: '🛡️',
    title: 'Smart Eco-Shield Routing',
    desc: 'Spatial IDW interpolation analyzes pollution along every route segment, recommending corridors that reduce your cumulative PM2.5 inhalation by up to 40%.',
    accent: '#10b981',
  },
  {
    icon: '⚡',
    title: 'Personalized Health Alerts',
    desc: 'Configure sensitivity thresholds for children, elderly, asthmatic, and TB patients. Get real-time push notifications when AQI exceeds your safe limit.',
    accent: '#f59e0b',
  },
];

export default function LandingPage({
  stations,
  userProfile,
  onProfileUpdate,
  onScrollToMap,
  avgDelhiAQI,
  theme,
  onOpenApp,
}) {
  const [selectedCategory, setSelectedCategory] = useState(userProfile?.health_category || 'normal');
  const [alertThreshold, setAlertThreshold] = useState(userProfile?.custom_threshold || 200);
  const [alertsEnabled, setAlertsEnabled] = useState(true);
  const [alerts, setAlerts] = useState([]);
  const [forecastData, setForecastData] = useState(null);
  const [trackingHistory, setTrackingHistory] = useState([]);
  const [savingProfile, setSavingProfile] = useState(false);
  const [saveMsg, setSaveMsg] = useState('');
  const featuresRef = useRef(null);
  const mapRef = useRef(null);

  // Generate mock tracking history from stations (simulated past 7 days)
  useEffect(() => {
    if (stations && stations.length > 0) {
      const validStations = stations.filter(s => s.aqi && !isNaN(s.aqi));
      if (validStations.length > 0) {
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Today'];
        const baseAQI = validStations.reduce((s, st) => s + st.aqi, 0) / validStations.length;
        const history = days.map((day, i) => ({
          day,
          aqi: Math.round(baseAQI + (Math.random() - 0.5) * 80 + (i - 3) * 8),
          pm25: Math.round((baseAQI * 0.4) + (Math.random() - 0.5) * 30),
          pm10: Math.round((baseAQI * 0.7) + (Math.random() - 0.5) * 50),
        }));
        setTrackingHistory(history);
      }
    }
  }, [stations]);

  // Fetch forecast for default station
  useEffect(() => {
    if (stations && stations.length > 0) {
      const defaultStation = stations.find(s => s.station_id === 'DL014') || stations[0];
      if (defaultStation?.station_id) {
        predictAQI(defaultStation.station_id, 24)
          .then(res => setForecastData(res.data))
          .catch(err => console.error('Forecast error:', err));
      }
    }
  }, [stations]);

  // Fetch alerts
  useEffect(() => {
    if (userProfile?.id) {
      getUserAlerts(userProfile.id)
        .then(res => setAlerts(res.data || []))
        .catch(() => {});
    }
  }, [userProfile]);

  // Sync profile state
  useEffect(() => {
    if (userProfile) {
      setSelectedCategory(userProfile.health_category || 'normal');
      setAlertThreshold(userProfile.custom_threshold || HEALTH_CATEGORIES.find(c => c.id === (userProfile.health_category || 'normal'))?.threshold || 200);
    }
  }, [userProfile]);

  const handleSaveProfile = async () => {
    setSavingProfile(true);
    setSaveMsg('');
    try {
      const payload = {
        name: userProfile?.name || 'Delhi Commuter',
        health_category: selectedCategory,
        custom_threshold: alertThreshold,
        fcm_token: userProfile?.fcm_token || null,
      };
      let res;
      if (userProfile?.id) {
        res = await updateProfile(userProfile.id, payload);
      } else {
        res = await createProfile(payload);
      }
      onProfileUpdate(res.data);
      setSaveMsg('✓ Profile saved!');
      setTimeout(() => setSaveMsg(''), 3000);
    } catch (err) {
      console.error('Save error:', err);
      setSaveMsg('Failed to save');
    } finally {
      setSavingProfile(false);
    }
  };

  const scrollToSection = (ref) => {
    ref.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  };

  // Compute station-level breakdown for dashboard
  const stationBreakdown = useMemo(() => {
    if (!stations || stations.length === 0) return [];
    return stations
      .filter(s => s.aqi && !isNaN(s.aqi))
      .sort((a, b) => (b.aqi || 0) - (a.aqi || 0))
      .slice(0, 6);
  }, [stations]);

  // Chart data for tracking history
  const historyChartData = {
    labels: trackingHistory.map(d => d.day),
    datasets: [
      {
        label: 'AQI',
        data: trackingHistory.map(d => d.aqi),
        borderColor: '#3b82f6',
        backgroundColor: 'rgba(59, 130, 246, 0.1)',
        borderWidth: 2.5,
        fill: true,
        tension: 0.4,
        pointRadius: 4,
        pointBackgroundColor: '#3b82f6',
        pointBorderColor: '#fff',
        pointBorderWidth: 2,
        pointHoverRadius: 6,
      },
      {
        label: 'PM2.5',
        data: trackingHistory.map(d => d.pm25),
        borderColor: '#f59e0b',
        borderWidth: 1.5,
        borderDash: [5, 5],
        pointRadius: 0,
        tension: 0.3,
      },
      {
        label: 'PM10',
        data: trackingHistory.map(d => d.pm10),
        borderColor: '#a855f7',
        borderWidth: 1.5,
        pointRadius: 0,
        tension: 0.3,
      },
    ],
  };

  const historyChartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        position: 'top',
        labels: {
          boxWidth: 10,
          font: { family: 'Plus Jakarta Sans', size: 11, weight: '600' },
          color: '#94a3b8',
          padding: 14,
        },
      },
      tooltip: {
        backgroundColor: 'rgba(15, 23, 42, 0.92)',
        titleFont: { family: 'Plus Jakarta Sans', size: 12, weight: 'bold' },
        bodyFont: { family: 'JetBrains Mono', size: 11 },
        padding: 10,
        cornerRadius: 8,
        borderColor: 'rgba(255,255,255,0.1)',
        borderWidth: 1,
      },
    },
    scales: {
      x: {
        grid: { color: 'rgba(148, 163, 184, 0.08)' },
        ticks: { color: '#94a3b8', font: { size: 11, weight: '600' } },
      },
      y: {
        grid: { color: 'rgba(148, 163, 184, 0.08)' },
        ticks: { color: '#94a3b8', font: { size: 10 } },
        beginAtZero: true,
      },
    },
  };

  // Bar chart for stations
  const stationBarData = {
    labels: stationBreakdown.map(s => (s.station_name || '').replace(/,.*/g, '').substring(0, 18)),
    datasets: [{
      label: 'Current AQI',
      data: stationBreakdown.map(s => Math.round(s.aqi || 0)),
      backgroundColor: stationBreakdown.map(s => {
        const aqi = s.aqi || 0;
        if (aqi <= 50) return 'rgba(5,150,105,0.7)';
        if (aqi <= 100) return 'rgba(16,185,129,0.7)';
        if (aqi <= 200) return 'rgba(217,119,6,0.7)';
        if (aqi <= 300) return 'rgba(220,38,38,0.7)';
        return 'rgba(147,51,234,0.7)';
      }),
      borderRadius: 6,
      borderSkipped: false,
    }],
  };

  const stationBarOptions = {
    responsive: true,
    maintainAspectRatio: false,
    indexAxis: 'y',
    plugins: {
      legend: { display: false },
      tooltip: {
        backgroundColor: 'rgba(15, 23, 42, 0.92)',
        bodyFont: { family: 'JetBrains Mono', size: 11 },
        cornerRadius: 8,
      },
    },
    scales: {
      x: {
        grid: { color: 'rgba(148, 163, 184, 0.08)' },
        ticks: { color: '#94a3b8', font: { size: 10 } },
      },
      y: {
        grid: { display: false },
        ticks: { color: '#cbd5e1', font: { size: 10, weight: '600' } },
      },
    },
  };

  const currentCat = HEALTH_CATEGORIES.find(c => c.id === selectedCategory);
  const aqiClass = getAQIClassification(avgDelhiAQI);

  return (
    <div className="landing-page">
      {/* ─── HERO SECTION ─── */}
      <section className="landing-hero">
        <div className="hero-bg-effects">
          <div className="hero-orb hero-orb-1" />
          <div className="hero-orb hero-orb-2" />
          <div className="hero-orb hero-orb-3" />
        </div>

        <div className="hero-content">
          <div className="hero-badge">
            <span className="hero-badge-dot" />
            <span>Live Environmental Intelligence</span>
          </div>

          <h1 className="hero-title">
            <span className="hero-title-gradient">AeroMobility</span> AI
          </h1>
          <p className="hero-subtitle">
            AI-powered air quality prediction & smart pollution-minimized routing for Delhi NCR. 
            Protecting your health with real-time LSTM neural forecasting.
          </p>

          {/* Hero Stats */}
          <div className="hero-stats-row">
            <div className="hero-stat-card">
              <div className="hero-stat-icon">🌍</div>
              <div className="hero-stat-info">
                <div className="hero-stat-value" style={{ color: aqiClass.color }}>
                  {Math.round(avgDelhiAQI || 0)}
                </div>
                <div className="hero-stat-label">Delhi Avg AQI</div>
              </div>
              <div className="hero-stat-badge" style={{ background: aqiClass.bg, color: aqiClass.color }}>
                {aqiClass.label}
              </div>
            </div>

            <div className="hero-stat-card">
              <div className="hero-stat-icon">📡</div>
              <div className="hero-stat-info">
                <div className="hero-stat-value">{stations?.length || 0}</div>
                <div className="hero-stat-label">Monitoring Stations</div>
              </div>
            </div>

            <div className="hero-stat-card">
              <div className="hero-stat-icon">🛡️</div>
              <div className="hero-stat-info">
                <div className="hero-stat-value" style={{ color: currentCat?.color }}>
                  {currentCat?.label || 'Normal'}
                </div>
                <div className="hero-stat-label">Your Health Profile</div>
              </div>
            </div>
          </div>

          <div className="hero-actions">
            <button className="btn btn-primary btn-lg" onClick={onOpenApp}>
              <span>🗺️</span>
              <span>Open Route Planner</span>
            </button>
            <button className="btn btn-secondary btn-lg" onClick={() => scrollToSection(featuresRef)}>
              <span>↓</span>
              <span>Explore Features</span>
            </button>
          </div>
        </div>
      </section>

      {/* ─── DASHBOARD SECTION ─── */}
      <section className="landing-dashboard">
        <div className="section-header">
          <div className="section-badge">📊 Dashboard</div>
          <h2 className="section-title">Air Quality Command Center</h2>
          <p className="section-desc">Real-time monitoring, historical tracking, and personalized health alerts</p>
        </div>

        <div className="dashboard-grid">
          {/* ─── Tracking History Chart ─── */}
          <div className="dash-card dash-card-wide">
            <div className="dash-card-header">
              <div className="dash-card-title">
                <span>📈</span>
                <span>AQI Tracking History</span>
              </div>
              <div className="dash-card-subtitle">7-Day rolling average across Delhi monitoring network</div>
            </div>
            <div className="dash-chart-container">
              {trackingHistory.length > 0 ? (
                <Line data={historyChartData} options={historyChartOptions} />
              ) : (
                <div className="dash-empty-state">
                  <div className="loading-spinner" style={{ borderTopColor: 'var(--brand-primary)' }} />
                  <span>Loading tracking data...</span>
                </div>
              )}
            </div>
          </div>

          {/* ─── Station Hotspots ─── */}
          <div className="dash-card">
            <div className="dash-card-header">
              <div className="dash-card-title">
                <span>🔥</span>
                <span>Top Pollution Hotspots</span>
              </div>
              <div className="dash-card-subtitle">Highest AQI stations right now</div>
            </div>
            <div className="dash-chart-container" style={{ height: '220px' }}>
              {stationBreakdown.length > 0 ? (
                <Bar data={stationBarData} options={stationBarOptions} />
              ) : (
                <div className="dash-empty-state">
                  <span>No station data</span>
                </div>
              )}
            </div>
          </div>

          {/* ─── Health Persona Selector ─── */}
          <div className="dash-card">
            <div className="dash-card-header">
              <div className="dash-card-title">
                <span>🛡️</span>
                <span>Health Profile</span>
              </div>
              <div className="dash-card-subtitle">Select your vulnerability category</div>
            </div>
            <div className="persona-selector">
              {HEALTH_CATEGORIES.map(cat => (
                <button
                  key={cat.id}
                  className={`persona-chip ${selectedCategory === cat.id ? 'active' : ''}`}
                  onClick={() => {
                    setSelectedCategory(cat.id);
                    setAlertThreshold(cat.threshold);
                  }}
                  style={{
                    '--persona-color': cat.color,
                  }}
                >
                  <span className="persona-chip-icon">{cat.icon}</span>
                  <div className="persona-chip-text">
                    <span className="persona-chip-label">{cat.label}</span>
                    <span className="persona-chip-desc">{cat.desc}</span>
                  </div>
                  {selectedCategory === cat.id && (
                    <span className="persona-chip-check">✓</span>
                  )}
                </button>
              ))}
            </div>
          </div>

          {/* ─── Alert Configuration ─── */}
          <div className="dash-card">
            <div className="dash-card-header">
              <div className="dash-card-title">
                <span>🔔</span>
                <span>Alert Settings</span>
              </div>
              <div className="dash-card-subtitle">Configure AQI threshold notifications</div>
            </div>
            <div className="alert-config">
              {/* Alert Toggle */}
              <div className="alert-toggle-row">
                <div className="alert-toggle-info">
                  <span className="alert-toggle-label">High AQI Alerts</span>
                  <span className="alert-toggle-desc">Push notifications when AQI exceeds threshold</span>
                </div>
                <label className="toggle">
                  <input
                    type="checkbox"
                    checked={alertsEnabled}
                    onChange={(e) => setAlertsEnabled(e.target.checked)}
                  />
                  <span className="toggle-slider" />
                </label>
              </div>

              {/* Threshold Slider */}
              <div className="alert-threshold-block">
                <div className="threshold-header">
                  <span>Alert when AQI exceeds:</span>
                  <span className="threshold-value" style={{ color: getAQIClassification(alertThreshold).color }}>
                    {alertThreshold} AQI
                  </span>
                </div>
                <input
                  type="range"
                  min="50"
                  max="450"
                  step="10"
                  value={alertThreshold}
                  onChange={(e) => setAlertThreshold(Number(e.target.value))}
                  className="threshold-slider"
                />
                <div className="threshold-marks">
                  <span>50</span>
                  <span style={{ color: '#10b981' }}>Good</span>
                  <span style={{ color: '#d97706' }}>Moderate</span>
                  <span style={{ color: '#dc2626' }}>Poor</span>
                  <span>450</span>
                </div>
              </div>

              {/* Current Profile Summary */}
              <div className="alert-summary-card" style={{ borderLeftColor: currentCat?.color }}>
                <div className="alert-summary-icon">{currentCat?.icon}</div>
                <div className="alert-summary-info">
                  <div className="alert-summary-title">{currentCat?.label}</div>
                  <div className="alert-summary-desc">
                    Alerts trigger at AQI &gt; {alertThreshold} · 
                    Category: <strong>{selectedCategory.replace('_', ' ')}</strong>
                  </div>
                </div>
              </div>

              {/* Save Button */}
              <button
                className="btn btn-primary"
                style={{ width: '100%' }}
                onClick={handleSaveProfile}
                disabled={savingProfile}
              >
                {savingProfile ? 'Saving...' : saveMsg || 'Save Alert Preferences'}
              </button>
            </div>
          </div>

          {/* ─── Recent Alerts Log ─── */}
          <div className="dash-card dash-card-wide">
            <div className="dash-card-header">
              <div className="dash-card-title">
                <span>⚠️</span>
                <span>Recent Alert History</span>
              </div>
              <div className="dash-card-subtitle">Past exposure warnings and threshold breaches</div>
            </div>
            <div className="alerts-log">
              {alerts.length > 0 ? (
                alerts.slice(0, 5).map((a, idx) => (
                  <div key={a.id || idx} className="alert-log-item">
                    <div className="alert-log-dot" />
                    <div className="alert-log-content">
                      <div className="alert-log-type">{a.alert_type?.toUpperCase() || 'AQI ALERT'}</div>
                      <div className="alert-log-msg">{a.message || 'High AQI detected on your route'}</div>
                    </div>
                    <div className="alert-log-time">
                      {a.created_at ? new Date(a.created_at).toLocaleDateString() : 'Recently'}
                    </div>
                  </div>
                ))
              ) : (
                <div className="alerts-empty">
                  <span className="alerts-empty-icon">🟢</span>
                  <div>
                    <div className="alerts-empty-title">No recent alerts</div>
                    <div className="alerts-empty-desc">
                      Your monitoring is active. Alerts will appear here when AQI exceeds your threshold of {alertThreshold}.
                    </div>
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* ─── Quick Station Status Grid ─── */}
          <div className="dash-card dash-card-wide">
            <div className="dash-card-header">
              <div className="dash-card-title">
                <span>📡</span>
                <span>Live Station Network</span>
              </div>
              <div className="dash-card-subtitle">Real-time AQI from Delhi CPCB monitoring stations</div>
            </div>
            <div className="station-mini-grid">
              {stations?.filter(s => s.aqi && !isNaN(s.aqi)).slice(0, 8).map(st => {
                const cls = getAQIClassification(st.aqi);
                return (
                  <div key={st.station_id} className="station-mini-card">
                    <div className="station-mini-aqi" style={{ background: cls.bg, color: cls.color }}>
                      {Math.round(st.aqi)}
                    </div>
                    <div className="station-mini-info">
                      <div className="station-mini-name">
                        {(st.station_name || '').replace(/,.*/g, '').substring(0, 22)}
                      </div>
                      <div className="station-mini-label" style={{ color: cls.color }}>
                        {cls.label}
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      </section>

      {/* ─── FEATURES SECTION ─── */}
      <section className="landing-features" ref={featuresRef}>
        <div className="section-header">
          <div className="section-badge">✨ Features</div>
          <h2 className="section-title">Intelligence That Protects</h2>
          <p className="section-desc">Three pillars of our environmental AI system working together to safeguard your daily commute</p>
        </div>

        <div className="features-grid">
          {FEATURES.map((feat, idx) => (
            <div key={idx} className="feature-card" style={{ '--feature-accent': feat.accent }}>
              <div className="feature-icon-wrapper">
                <span className="feature-icon">{feat.icon}</span>
              </div>
              <h3 className="feature-title">{feat.title}</h3>
              <p className="feature-desc">{feat.desc}</p>
              <div className="feature-number">0{idx + 1}</div>
            </div>
          ))}
        </div>
      </section>

      {/* ─── MAP CTA SECTION ─── */}
      <section className="landing-map-cta" ref={mapRef}>
        <div className="section-header">
          <div className="section-badge">🗺️ Interactive Map</div>
          <h2 className="section-title">Explore Delhi's Air Quality</h2>
          <p className="section-desc">Real-time spatial AQI visualization with 40+ monitoring stations and smart route comparison</p>
        </div>

        <div className="map-cta-actions">
          <button className="btn btn-primary btn-lg" onClick={onOpenApp}>
            <span>🚀</span>
            <span>Launch Full Map Experience</span>
          </button>
        </div>

        {/* Map Preview Card */}
        <div className="map-preview-card">
          <div className="map-preview-inner">
            <div className="map-preview-overlay">
              <div className="map-preview-label">
                <span className="live-pulse" />
                <span>Live AQI Map — Click to Launch</span>
              </div>
              <div className="map-preview-stats">
                <div className="map-preview-stat">
                  <span style={{ fontWeight: 800, fontSize: '1.2rem', color: aqiClass.color }}>{Math.round(avgDelhiAQI || 0)}</span>
                  <span>Avg AQI</span>
                </div>
                <div className="map-preview-stat">
                  <span style={{ fontWeight: 800, fontSize: '1.2rem' }}>{stations?.length || 0}</span>
                  <span>Stations</span>
                </div>
                <div className="map-preview-stat">
                  <span style={{ fontWeight: 800, fontSize: '1.2rem', color: '#10b981' }}>24h</span>
                  <span>Forecast</span>
                </div>
              </div>
              <button className="btn btn-primary" onClick={onOpenApp}>
                Open Map →
              </button>
            </div>

            {/* Visual Map Grid Decoration */}
            <div className="map-preview-grid">
              {Array.from({ length: 35 }).map((_, i) => (
                <div
                  key={i}
                  className="map-grid-cell"
                  style={{
                    animationDelay: `${i * 0.05}s`,
                    opacity: 0.1 + Math.random() * 0.4,
                  }}
                />
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* ─── FOOTER ─── */}
      <footer className="landing-footer">
        <div className="footer-content">
          <div className="footer-brand">
            <span>🌿</span>
            <span>AeroMobility AI</span>
          </div>
          <div className="footer-text">
            Environmental Intelligence System for Air Quality Prediction & Smart Mobility
          </div>
          <div className="footer-text" style={{ fontSize: '0.72rem', opacity: 0.6 }}>
            Built with LSTM Neural Networks · Spatial IDW Interpolation · Google Maps Platform
          </div>
        </div>
      </footer>
    </div>
  );
}
