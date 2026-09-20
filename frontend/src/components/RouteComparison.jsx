import React from 'react';

export default function RouteComparison({
  routes = [],
  safestIndex = 0,
  activeRouteIndex = 0,
  onSelectRoute,
  _userProfile = null,
}) {
  if (!routes || routes.length === 0) return null;

  return (
    <div className="route-cards-list">
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 2px' }}>
        <span style={{ fontSize: '0.84rem', fontWeight: 800, color: 'var(--text-primary)', letterSpacing: '-0.2px' }}>
          Analyzed Corridors ({routes.length})
        </span>
        <span style={{ fontSize: '0.72rem', color: 'var(--accent-emerald)', fontWeight: 700, display: 'flex', alignItems: 'center', gap: '4px' }}>
          <span>🌿</span> Spatial IDW Optimized
        </span>
      </div>

      {routes.map((route, idx) => {
        const isSafest = idx === safestIndex;
        const isActive = idx === activeRouteIndex;
        const timeMins = Math.round(route.duration_in_traffic_minutes || route.total_duration_minutes || route.travel_time_minutes);

        return (
          <div
            key={idx}
            className={`route-card ${isSafest ? 'safest' : ''} ${isActive ? 'active' : ''}`}
            onClick={() => onSelectRoute(idx)}
            role="button"
            tabIndex={0}
          >
            {/* Top row: Big Time, Distance, and Eco Shield Tag */}
            <div className="route-card-top">
              <div className={`route-time-big ${isSafest ? '' : 'moderate'}`}>
                <span>{timeMins} min</span>
                <span className="route-dist-muted">({route.total_distance_km ? route.total_distance_km.toFixed(1) : '—'} km)</span>
              </div>
              <span className={`route-tag-pill ${isSafest ? 'best' : 'alt'}`}>
                {isSafest ? '🛡️ Eco-Shield Safest' : `Option #${idx + 1}`}
              </span>
            </div>

            {/* Corridor Name / Highway */}
            <div className="route-via-name">
              {route.summary || `Corridor Option ${idx + 1}`}
            </div>

            {/* Metrics Chips */}
            <div className="route-metrics-row">
              <span className="metric-badge">
                Avg AQI: <strong>{Math.round(route.average_aqi || 0)}</strong>
              </span>

              <span className={`metric-badge ${isSafest ? 'highlight-green' : ''}`}>
                Inhaled Dose: <strong>{Math.round(route.cumulative_exposure || 0).toLocaleString()}</strong> AQI·m
              </span>

              {route.exposure_reduction_pct > 0 && (
                <span className="metric-badge highlight-green">
                  -{route.exposure_reduction_pct}% Inhaled PM2.5
                </span>
              )}
            </div>

            {/* Practical Exposure Reasoning */}
            {route.practical_reasoning && (
              <div className={`reasoning-box ${isSafest ? '' : 'alt'}`}>
                <strong>{isSafest ? '💡 Eco-Shield AI Assessment: ' : 'ℹ️ Corridor Notes: '}</strong>
                {route.practical_reasoning}
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}
