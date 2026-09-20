import React from 'react';

export default function Header({
  showTraffic,
  onToggleTraffic,
  onLocateUser,
  locating = false,
  userProfile = null,
  onOpenProfile,
  avgDelhiAQI = 0,
  theme = 'light',
  onToggleTheme,
  sidebarOpen = true,
  onToggleSidebar,
}) {
  const getProfileColor = (category) => {
    switch (category) {
      case 'asthmatic':
        return '#ef4444';
      case 'children':
      case 'elderly':
        return '#f59e0b';
      default:
        return '#10b981';
    }
  };

  const getAQIStatus = (aqi) => {
    if (!aqi || isNaN(aqi)) return { label: 'Active', bg: 'var(--accent-blue-light)', color: 'var(--accent-blue)' };
    const val = Math.round(aqi);
    if (val <= 50) return { label: 'Good', bg: 'var(--accent-emerald-light)', color: 'var(--accent-emerald)' };
    if (val <= 100) return { label: 'Satisfactory', bg: 'var(--accent-emerald-light)', color: 'var(--accent-emerald)' };
    if (val <= 200) return { label: 'Moderate', bg: 'var(--accent-amber-light)', color: 'var(--accent-amber)' };
    if (val <= 300) return { label: 'Poor', bg: 'var(--accent-red-light)', color: 'var(--accent-red)' };
    return { label: 'Severe', bg: 'rgba(168, 85, 247, 0.16)', color: 'var(--accent-purple)' };
  };

  const aqiStatus = getAQIStatus(avgDelhiAQI);

  return (
    <header className="app-header">
      <div className="logo" onClick={onToggleSidebar} title="Click to toggle route panel">
        <div className="logo-icon">🌿</div>
        <div className="logo-text-group">
          <div className="logo-text">
            <span>AeroMobility AI</span>
            <span className="logo-badge">LSTM 2.0</span>
          </div>
          <div className="logo-subtitle">Environmental Intelligence & Smart Routing</div>
        </div>
      </div>

      <div className="header-actions">
        {/* Toggle Routes Sidebar Button */}
        {onToggleSidebar && (
          <button
            className="header-icon-btn"
            onClick={onToggleSidebar}
            title={sidebarOpen ? "Collapse Route Panel" : "Open Route Panel"}
            aria-label="Toggle Route Panel"
          >
            {sidebarOpen ? '◀' : '🧭'}
          </button>
        )}

        {/* Delhi Average AQI Pill */}
        {avgDelhiAQI > 0 && (
          <div
            className="header-aqi-pill"
            style={{
              background: aqiStatus.bg,
              color: aqiStatus.color,
            }}
            title="Real-time average AQI across all Delhi monitoring stations"
          >
            <span className="header-aqi-dot" style={{ backgroundColor: aqiStatus.color }} />
            <span>Delhi AQI: <strong>{Math.round(avgDelhiAQI)}</strong></span>
            <span style={{ fontSize: '0.7rem', opacity: 0.85 }}>({aqiStatus.label})</span>
          </div>
        )}

        {/* Live Traffic Toggle */}
        <div className="toggle-wrapper" style={{
          padding: '4px 10px',
          background: 'var(--bg-tertiary)',
          borderRadius: 'var(--radius-full)',
          border: '1px solid var(--border-subtle)',
        }}>
          <span style={{ fontSize: '0.74rem', fontWeight: 600, color: 'var(--text-secondary)' }}>
            Traffic
          </span>
          <label className="toggle">
            <input
              type="checkbox"
              checked={showTraffic}
              onChange={(e) => onToggleTraffic(e.target.checked)}
              aria-label="Toggle Live Traffic Layer"
            />
            <span className="toggle-slider"></span>
          </label>
        </div>

        {/* Locate Me Button */}
        <button
          className="btn btn-secondary btn-sm"
          onClick={onLocateUser}
          disabled={locating}
          title="Detect Current GPS Location via Geolocation"
        >
          {locating ? (
            <div className="loading-spinner" style={{ borderTopColor: 'var(--brand-primary)' }} />
          ) : (
            <>
              <span>🎯</span>
              <span>Locate Me</span>
            </>
          )}
        </button>

        {/* User Health Profile Chip */}
        <button
          className="btn btn-secondary btn-sm"
          onClick={onOpenProfile}
          title="Edit Sensitivity & Exposure Thresholds"
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
          }}
        >
          <span
            style={{
              width: '8px',
              height: '8px',
              borderRadius: '50%',
              backgroundColor: getProfileColor(userProfile?.health_category),
              boxShadow: `0 0 6px ${getProfileColor(userProfile?.health_category)}`,
            }}
          />
          <span>{userProfile?.name || 'Commuter'}</span>
        </button>

        {/* Theme Switcher (Dark / Light) */}
        {onToggleTheme && (
          <button
            className="header-icon-btn"
            onClick={onToggleTheme}
            title={theme === 'dark' ? 'Switch to Light Theme' : 'Switch to Dark Theme'}
            aria-label="Toggle visual theme"
          >
            {theme === 'dark' ? '☀️' : '🌙'}
          </button>
        )}
      </div>
    </header>
  );
}
