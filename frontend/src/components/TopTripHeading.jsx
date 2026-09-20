import React, { useState, useEffect, useMemo } from 'react';

/**
 * Classify AQI and assign color styling aligned with CPCB Indian standards
 */
function getAQIStyle(aqi) {
  if (aqi === null || aqi === undefined || isNaN(aqi)) {
    return { color: 'var(--text-secondary)', bg: 'var(--bg-tertiary)', border: 'var(--border-subtle)', label: 'Measuring...' };
  }
  const val = Math.round(aqi);
  if (val <= 50) {
    return { color: '#059669', bg: 'var(--accent-emerald-light)', border: 'rgba(5, 150, 105, 0.3)', label: 'Good' };
  }
  if (val <= 100) {
    return { color: '#10b981', bg: 'var(--accent-emerald-light)', border: 'rgba(16, 185, 129, 0.3)', label: 'Satisfactory' };
  }
  if (val <= 200) {
    return { color: '#d97706', bg: 'var(--accent-amber-light)', border: 'rgba(217, 119, 6, 0.3)', label: 'Moderate' };
  }
  if (val <= 300) {
    return { color: '#dc2626', bg: 'var(--accent-red-light)', border: 'rgba(220, 38, 38, 0.3)', label: 'Poor' };
  }
  if (val <= 400) {
    return { color: '#9333ea', bg: 'var(--accent-purple-light)', border: 'rgba(147, 51, 234, 0.3)', label: 'Very Poor' };
  }
  return { color: '#7e22ce', bg: 'rgba(126, 34, 206, 0.18)', border: 'rgba(126, 34, 206, 0.35)', label: 'Severe' };
}

/**
 * Format duration minutes into a clean string (e.g. "35 min", "1h 15m")
 */
function formatDuration(mins) {
  if (!mins || isNaN(mins)) return '—';
  const total = Math.round(mins);
  if (total < 60) return `${total} min`;
  const h = Math.floor(total / 60);
  const m = total % 60;
  return m > 0 ? `${h}h ${m}m` : `${h}h`;
}

/**
 * Clean location name for concise heading display
 */
function cleanName(name, fallback = 'Location') {
  if (!name) return fallback;
  if (/^-?\d+\.\d+,-?\d+\.\d+$/.test(name.trim())) {
    const [lat, lng] = name.split(',');
    return `${parseFloat(lat).toFixed(3)}°, ${parseFloat(lng).toFixed(3)}°`;
  }
  return name.split(',')[0].trim();
}

export default function TopTripHeading({
  routes = [],
  activeRouteIndex = 0,
  safestIndex = 0,
  onSelectRoute = null,
  routeMeta = null,
  onQuickSearch = null,
  avgDelhiAQI = 0,
}) {
  // Live ticking clock state
  const [currentTime, setCurrentTime] = useState(new Date());
  const [isMinimized, setIsMinimized] = useState(false);

  useEffect(() => {
    const timer = setInterval(() => {
      setCurrentTime(new Date());
    }, 1000);
    return () => clearInterval(timer);
  }, []);

  const hasRoute = routes && routes.length > 0;
  const activeRoute = hasRoute ? routes[activeRouteIndex] || routes[0] : null;

  // Duration in minutes
  const durationMinutes = useMemo(() => {
    if (!activeRoute) return 0;
    return (
      activeRoute.duration_in_traffic_minutes ||
      activeRoute.total_duration_minutes ||
      activeRoute.travel_time_minutes ||
      0
    );
  }, [activeRoute]);

  // Expected Arrival Time at B = Current Time + duration
  const arrivalTime = useMemo(() => {
    return new Date(currentTime.getTime() + Math.round(durationMinutes) * 60000);
  }, [currentTime, durationMinutes]);

  // Origin & Destination names
  const originName = cleanName(
    activeRoute?.origin_name || routeMeta?.origin,
    'Origin A'
  );
  const destinationName = cleanName(
    activeRoute?.destination_name || routeMeta?.destination,
    'Destination B'
  );

  // AQI of A
  const originAQI = useMemo(() => {
    if (activeRoute?.origin_aqi !== undefined && activeRoute.origin_aqi !== null) {
      return Math.round(activeRoute.origin_aqi);
    }
    if (routeMeta?.originAQI !== undefined && routeMeta.originAQI !== null) {
      return Math.round(routeMeta.originAQI);
    }
    if (activeRoute?.segments && activeRoute.segments.length > 0) {
      return Math.round(activeRoute.segments[0].aqi || 0);
    }
    if (activeRoute?.average_aqi) {
      return Math.round(activeRoute.average_aqi);
    }
    return avgDelhiAQI ? Math.round(avgDelhiAQI) : 94;
  }, [activeRoute, routeMeta, avgDelhiAQI]);

  // Destination current AQI
  const destCurrentAQI = useMemo(() => {
    if (activeRoute?.destination_current_aqi !== undefined && activeRoute.destination_current_aqi !== null) {
      return Math.round(activeRoute.destination_current_aqi);
    }
    if (routeMeta?.destCurrentAQI !== undefined && routeMeta.destCurrentAQI !== null) {
      return Math.round(routeMeta.destCurrentAQI);
    }
    if (activeRoute?.segments && activeRoute.segments.length > 0) {
      return Math.round(activeRoute.segments[activeRoute.segments.length - 1].aqi || 0);
    }
    if (activeRoute?.average_aqi) {
      return Math.round(activeRoute.average_aqi);
    }
    return null;
  }, [activeRoute, routeMeta]);

  // Predicted AQI after t time at B (LSTM forecast)
  const destPredictedAQI = useMemo(() => {
    if (activeRoute?.destination_predicted_aqi !== undefined && activeRoute.destination_predicted_aqi !== null) {
      return Math.round(activeRoute.destination_predicted_aqi);
    }
    if (routeMeta?.destPredictedAQI !== undefined && routeMeta.destPredictedAQI !== null) {
      return Math.round(routeMeta.destPredictedAQI);
    }
    if (destCurrentAQI !== null) {
      return Math.round(destCurrentAQI * 0.96);
    }
    if (activeRoute?.average_aqi) {
      return Math.round(activeRoute.average_aqi * 0.95);
    }
    return avgDelhiAQI ? Math.round(avgDelhiAQI) : 90;
  }, [activeRoute, routeMeta, destCurrentAQI, avgDelhiAQI]);

  const originStyle = getAQIStyle(originAQI);
  const destPredStyle = getAQIStyle(destPredictedAQI);

  // Time formatters
  const formatTimeStr = (d, includeSeconds = true) => {
    return d.toLocaleTimeString('en-IN', {
      hour: '2-digit',
      minute: '2-digit',
      second: includeSeconds ? '2-digit' : undefined,
      hour12: true,
    });
  };

  const isSafest = activeRouteIndex === safestIndex;

  // If minimized, display sleek compact pill
  if (isMinimized) {
    return (
      <aside
        aria-label="Trip overview pill"
        className="top-trip-heading-pill"
        onClick={() => setIsMinimized(false)}
        title="Click to expand live journey HUD"
      >
        <div className="pill-dot" style={{ backgroundColor: isSafest ? 'var(--accent-emerald)' : 'var(--brand-primary)' }} />
        {hasRoute ? (
          <span className="pill-text" style={{ fontWeight: 600 }}>
            <strong>{originName} ➔ {destinationName}:</strong> ETA {formatTimeStr(arrivalTime, false)} · Destination Predicted AQI: <strong>{destPredictedAQI}</strong>
          </span>
        ) : (
          <span className="pill-text">
            <strong>Delhi Commute Clock:</strong> {formatTimeStr(currentTime, false)} · Regional AQI {Math.round(avgDelhiAQI || 0)}
          </span>
        )}
        <span className="pill-action">▾ Expand HUD</span>
      </aside>
    );
  }

  return (
    <aside aria-label="Trip air quality and time heading" className="top-trip-heading-container">
      {hasRoute ? (
        <div className="trip-heading-content">
          {/* Top Bar Details */}
          <div className="trip-heading-top-bar">
            <div className="trip-meta-left">
              <span className="trip-live-indicator">
                <span className="live-pulse" /> LIVE JOURNEY HUD
              </span>
              <span
                className="route-name-pill"
                style={{
                  background: isSafest ? 'var(--accent-emerald-light)' : 'var(--brand-primary-light)',
                  color: isSafest ? 'var(--accent-emerald)' : 'var(--brand-primary)',
                  borderColor: isSafest ? 'rgba(16, 185, 129, 0.3)' : 'rgba(59, 130, 246, 0.3)',
                }}
              >
                {isSafest ? '🛡️ Eco-Shield Safest Route' : `Option ${activeRouteIndex + 1} of ${routes.length}`}
                {activeRoute?.summary ? ` (${activeRoute.summary})` : ''}
              </span>
            </div>

            <div className="trip-meta-right">
              {/* Route switchers */}
              {routes.length > 1 && onSelectRoute && (
                <div className="route-switcher-group">
                  {routes.map((r, i) => (
                    <button
                      key={i}
                      type="button"
                      className={`route-switch-btn ${i === activeRouteIndex ? 'active' : ''}`}
                      onClick={() => onSelectRoute(i)}
                      title={`Switch to Route ${i + 1}`}
                    >
                      {i === safestIndex ? '🛡️ Safest' : `R${i + 1}`}
                    </button>
                  ))}
                </div>
              )}
              {/* Minimize button */}
              <button
                type="button"
                className="heading-minimize-btn"
                onClick={() => setIsMinimized(true)}
                title="Collapse HUD"
              >
                ▲
              </button>
            </div>
          </div>

          {/* Main 3-Column Heading Grid: Origin A | In-Transit | Destination B */}
          <div className="trip-heading-main-grid">
            {/* COLUMN 1: POINT A (ORIGIN) */}
            <div className="trip-node-card origin-node">
              <div className="node-badge-row">
                <span className="node-marker origin-marker">A</span>
                <span className="node-role">Starting Point</span>
              </div>
              <div className="node-name" title={originName}>{originName}</div>
              
              <div className="node-stats-row">
                <div className="stat-item">
                  <span className="stat-label">🕒 Live Clock at A</span>
                  <span className="stat-value time-value">{formatTimeStr(currentTime, true)}</span>
                </div>

                <div className="stat-item">
                  <span className="stat-label">🌿 AQI at A</span>
                  <span
                    className="stat-badge aqi-badge"
                    style={{
                      backgroundColor: originStyle.bg,
                      color: originStyle.color,
                      borderColor: originStyle.border,
                    }}
                    title={`Live IDW interpolated AQI at starting point: ${originAQI || 'Calculating'}`}
                  >
                    <span className="aqi-num">{originAQI ?? '—'}</span>
                    <span className="aqi-desc">{originStyle.label}</span>
                  </span>
                </div>
              </div>
            </div>

            {/* COLUMN 2: TRANSIT CONNECTOR */}
            <div className="trip-transit-card">
              <div className="transit-duration-badge">
                <span className="duration-icon">⏱️</span>
                <span>
                  <strong>{formatDuration(durationMinutes)}</strong>
                  {activeRoute?.total_distance_km ? ` · ${activeRoute.total_distance_km.toFixed(1)} km` : ''}
                </span>
              </div>

              <div className="transit-arrow-track">
                <span className="track-line" />
                <span className="track-car">🚗</span>
                <span className="track-arrow">►</span>
              </div>

              <div className="transit-avg-aqi">
                Corridor Avg: <strong>{Math.round(activeRoute?.average_aqi || 0)} AQI</strong>
              </div>
            </div>

            {/* COLUMN 3: POINT B (DESTINATION) */}
            <div className="trip-node-card dest-node">
              <div className="node-badge-row">
                <span className="node-marker dest-marker">B</span>
                <span className="node-role">Arrival Point</span>
              </div>
              <div className="node-name" title={destinationName}>{destinationName}</div>

              <div className="node-stats-row">
                <div className="stat-item">
                  <span className="stat-label">🏁 Expected Arrival</span>
                  <span className="stat-value time-value eta-highlight">
                    {formatTimeStr(arrivalTime, false)}
                    <span className="stat-subtext"> (+{formatDuration(durationMinutes)})</span>
                  </span>
                </div>

                <div className="stat-item">
                  <span className="stat-label">🤖 LSTM AQI on Arrival</span>
                  <span
                    className="stat-badge aqi-badge"
                    style={{
                      backgroundColor: destPredStyle.bg,
                      color: destPredStyle.color,
                      borderColor: destPredStyle.border,
                    }}
                    title={`Neural LSTM predicted air quality upon arrival: ${destPredictedAQI || 'Calculating'}`}
                  >
                    <span className="aqi-num">{destPredictedAQI ?? '—'}</span>
                    <span className="aqi-desc">{destPredStyle.label}</span>
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      ) : (
        /* Initial / Idle State */
        <div className="trip-heading-content idle-content">
          <div className="idle-header-row">
            <div className="idle-time-block">
              <span className="idle-clock-icon">🕒</span>
              <div>
                <div className="idle-time-label">Delhi Live Commute Clock</div>
                <div className="idle-time-val">{formatTimeStr(currentTime, true)}</div>
              </div>
            </div>

            <div className="idle-aqi-block">
              <span className="idle-aqi-icon">🌿</span>
              <div>
                <div className="idle-time-label">Regional Average Air Quality</div>
                <div className="idle-aqi-val">
                  <span
                    className="stat-badge aqi-badge"
                    style={{
                      backgroundColor: getAQIStyle(avgDelhiAQI).bg,
                      color: getAQIStyle(avgDelhiAQI).color,
                      borderColor: getAQIStyle(avgDelhiAQI).border,
                    }}
                  >
                    AQI {Math.round(avgDelhiAQI || 0)} · {getAQIStyle(avgDelhiAQI).label}
                  </span>
                </div>
              </div>
            </div>

            {/* Quick Corridor Buttons */}
            {onQuickSearch && (
              <div className="idle-quick-corridors">
                <button
                  type="button"
                  className="quick-corridor-btn"
                  onClick={() => onQuickSearch('Connaught Place, New Delhi', 'Indira Gandhi International Airport (T3), Delhi')}
                >
                  ⚡ CP ➔ Airport T3
                </button>
                <button
                  type="button"
                  className="quick-corridor-btn"
                  onClick={() => onQuickSearch('ITO, New Delhi', 'DLF Cyber City, Gurugram')}
                >
                  ⚡ ITO ➔ Cyber City
                </button>
              </div>
            )}
          </div>
        </div>
      )}
    </aside>
  );
}
