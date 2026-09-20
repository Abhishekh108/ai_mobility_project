import React, { useState, useEffect, useRef } from 'react';
import { DELHI_LOCATIONS } from '../data/delhiLocations';

const PRESETS = [
  { label: 'CP ➔ Airport (T3)', origin: 'Connaught Place, New Delhi', dest: 'Indira Gandhi International Airport (T3), Delhi' },
  { label: 'Anand Vihar ➔ Dwarka Sec 8', origin: 'Anand Vihar ISBT & Railway Station, Delhi', dest: 'Dwarka Sector 8, New Delhi' },
  { label: 'ITO ➔ Cyber Hub Gurgaon', origin: 'ITO, New Delhi', dest: 'DLF Cyber City, Gurugram' },
  { label: 'Alipur ➔ Nehru Nagar', origin: 'Alipur, Delhi', dest: 'Nehru Nagar, New Delhi' },
  { label: 'Rohini ➔ Noida Sec 18', origin: 'Rohini Sector 10, Delhi', dest: 'Noida Sector 18 (Atta Market)' },
];

const COORD_PRESETS = [
  { label: 'Connaught Place', lat: 28.6315, lng: 77.2167 },
  { label: 'IGI Airport T3', lat: 28.5562, lng: 77.1000 },
  { label: 'Dwarka Sec 8', lat: 28.5656, lng: 77.0670 },
  { label: 'Cyber Hub Gurugram', lat: 28.4952, lng: 77.0890 },
  { label: 'Noida Sec 18', lat: 28.5700, lng: 77.3200 },
  { label: 'Anand Vihar ISBT', lat: 28.6466, lng: 77.3155 },
];

export default function RouteSearch({
  onSearch,
  loading = false,
  userLocation = null,
  pickedCoords = null,
  stations = [],
}) {
  // Search Mode: 'name', 'coords', or 'station'
  const [mode, setMode] = useState('name');

  // Place Name Inputs
  const [originText, setOriginText] = useState('Connaught Place, New Delhi');
  const [destText, setDestText] = useState('Indira Gandhi International Airport (T3), Delhi');

  // Coordinates Inputs
  const [fromLat, setFromLat] = useState('28.6315');
  const [fromLng, setFromLng] = useState('77.2167');
  const [toLat, setToLat] = useState('28.5562');
  const [toLng, setToLng] = useState('77.1000');

  // Station Picker State
  const [fromStationId, setFromStationId] = useState('');
  const [toStationId, setToStationId] = useState('');

  // Dropdown States
  const [originSuggestions, setOriginSuggestions] = useState([]);
  const [destSuggestions, setDestSuggestions] = useState([]);
  const [showOriginDropdown, setShowOriginDropdown] = useState(false);
  const [showDestDropdown, setShowDestDropdown] = useState(false);

  const originRef = useRef(null);
  const destRef = useRef(null);

  // Initialise station defaults when stations list first arrives
  useEffect(() => {
    if (stations.length >= 2 && !fromStationId && !toStationId) {
      setToStationId(stations[0].station_id);
      setFromStationId(stations[1].station_id);
    }
  }, [stations, fromStationId, toStationId]);

  // Close dropdowns on outside click
  useEffect(() => {
    const handleClickOutside = (e) => {
      if (originRef.current && !originRef.current.contains(e.target)) {
        setShowOriginDropdown(false);
      }
      if (destRef.current && !destRef.current.contains(e.target)) {
        setShowDestDropdown(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  // Update coordinates if picked from map
  useEffect(() => {
    if (pickedCoords) {
      setToLat(pickedCoords.lat.toFixed(4));
      setToLng(pickedCoords.lng.toFixed(4));
    }
  }, [pickedCoords]);

  // Filter function for auto-suggest
  const getMatches = (query) => {
    if (!query || query.trim().length === 0) return [];
    const q = query.toLowerCase().trim();
    return DELHI_LOCATIONS.filter(
      (loc) =>
        loc.name.toLowerCase().includes(q) ||
        loc.area.toLowerCase().includes(q) ||
        loc.category.toLowerCase().includes(q)
    ).slice(0, 8);
  };

  const handleOriginChange = (e) => {
    const val = e.target.value;
    setOriginText(val);
    const matches = getMatches(val);
    setOriginSuggestions(matches);
    setShowOriginDropdown(matches.length > 0);
  };

  const handleDestChange = (e) => {
    const val = e.target.value;
    setDestText(val);
    const matches = getMatches(val);
    setDestSuggestions(matches);
    setShowDestDropdown(matches.length > 0);
  };

  const selectOrigin = (loc) => {
    setOriginText(loc.name);
    setShowOriginDropdown(false);
    setFromLat(loc.lat.toFixed(4));
    setFromLng(loc.lng.toFixed(4));
  };

  const selectDest = (loc) => {
    setDestText(loc.name);
    setShowDestDropdown(false);
    setToLat(loc.lat.toFixed(4));
    setToLng(loc.lng.toFixed(4));
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    if (mode === 'name') {
      if (!originText.trim() || !destText.trim()) return;
      onSearch(originText.trim(), destText.trim());
    } else if (mode === 'coords') {
      if (!fromLat || !fromLng || !toLat || !toLng) return;
      const originCoord = `${fromLat.trim()},${fromLng.trim()}`;
      const destCoord = `${toLat.trim()},${toLng.trim()}`;
      onSearch(originCoord, destCoord);
    } else if (mode === 'station') {
      const fromSt = stations.find((s) => s.station_id === fromStationId);
      const toSt = stations.find((s) => s.station_id === toStationId);
      if (!fromSt || !toSt) return;
      onSearch(`${fromSt.latitude},${fromSt.longitude}`, `${toSt.latitude},${toSt.longitude}`);
    }
  };

  const handleApplyPreset = (preset) => {
    setOriginText(preset.origin);
    setDestText(preset.dest);
    onSearch(preset.origin, preset.dest);
  };

  const setFromToUserLocation = () => {
    if (userLocation) {
      setFromLat(userLocation.lat.toFixed(4));
      setFromLng(userLocation.lng.toFixed(4));
      setOriginText(`My Location (${userLocation.lat.toFixed(3)}, ${userLocation.lng.toFixed(3)})`);
    }
  };

  const fromStationOptions = stations.filter((s) => s.station_id !== toStationId);
  const toStationOptions = stations.filter((s) => s.station_id !== fromStationId);

  return (
    <div className="glass-card" style={{ position: 'relative' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '12px' }}>
        <div>
          <h2 style={{ fontSize: '0.92rem', fontWeight: 800, color: 'var(--text-primary)', letterSpacing: '-0.2px' }}>
            Smart Route Analyzer
          </h2>
          <div style={{ fontSize: '0.72rem', color: 'var(--text-tertiary)' }}>
            Spatial IDW Pollution & Live Traffic Optimization
          </div>
        </div>
      </div>

      {/* Mode Switcher Tabs */}
      <div className="tabs" style={{ marginBottom: '12px' }}>
        <button
          type="button"
          className={`tab ${mode === 'name' ? 'active' : ''}`}
          onClick={() => setMode('name')}
        >
          <span>📍</span> By Place
        </button>
        <button
          type="button"
          className={`tab ${mode === 'coords' ? 'active' : ''}`}
          onClick={() => setMode('coords')}
        >
          <span>🌐</span> Coordinates
        </button>
        <button
          type="button"
          className={`tab ${mode === 'station' ? 'active' : ''}`}
          onClick={() => setMode('station')}
        >
          <span>🏭</span> AQI Stations
        </button>
      </div>

      <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
        {/* MODE 1: BY PLACE NAME WITH AUTO-SUGGEST */}
        {mode === 'name' ? (
          <div className="journey-input-card">
            <div className="journey-connector">
              <div className="journey-dot-origin" />
              <div className="journey-line" />
              <div className="journey-dot-dest" />
            </div>

            <div className="journey-inputs">
              {/* FROM INPUT */}
              <div className="journey-input-row" ref={originRef}>
                <input
                  type="text"
                  className="journey-input"
                  placeholder="Starting Point (Delhi)..."
                  value={originText}
                  onChange={handleOriginChange}
                  onFocus={() => {
                    const matches = getMatches(originText);
                    setOriginSuggestions(matches);
                    setShowOriginDropdown(matches.length > 0);
                  }}
                  disabled={loading}
                  required
                  autoComplete="off"
                />
                {originText && (
                  <button
                    type="button"
                    className="journey-clear-btn"
                    onClick={() => {
                      setOriginText('');
                      setOriginSuggestions([]);
                      setShowOriginDropdown(false);
                    }}
                  >
                    ✕
                  </button>
                )}

                {/* Auto-suggest Dropdown */}
                {showOriginDropdown && originSuggestions.length > 0 && (
                  <div className="suggest-dropdown">
                    {originSuggestions.map((loc, i) => (
                      <div
                        key={i}
                        className="suggest-item"
                        onClick={() => selectOrigin(loc)}
                      >
                        <div className="suggest-name">{loc.name}</div>
                        <div className="suggest-meta">
                          <span className="suggest-area-tag">{loc.area}</span>
                          <span>•</span>
                          <span>{loc.category}</span>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {/* TO INPUT */}
              <div className="journey-input-row" ref={destRef}>
                <input
                  type="text"
                  className="journey-input"
                  placeholder="Destination in Delhi NCR..."
                  value={destText}
                  onChange={handleDestChange}
                  onFocus={() => {
                    const matches = getMatches(destText);
                    setDestSuggestions(matches);
                    setShowDestDropdown(matches.length > 0);
                  }}
                  disabled={loading}
                  required
                  autoComplete="off"
                />
                {destText && (
                  <button
                    type="button"
                    className="journey-clear-btn"
                    onClick={() => {
                      setDestText('');
                      setDestSuggestions([]);
                      setShowDestDropdown(false);
                    }}
                  >
                    ✕
                  </button>
                )}

                {/* Auto-suggest Dropdown */}
                {showDestDropdown && destSuggestions.length > 0 && (
                  <div className="suggest-dropdown">
                    {destSuggestions.map((loc, i) => (
                      <div
                        key={i}
                        className="suggest-item"
                        onClick={() => selectDest(loc)}
                      >
                        <div className="suggest-name">{loc.name}</div>
                        <div className="suggest-meta">
                          <span className="suggest-area-tag">{loc.area}</span>
                          <span>•</span>
                          <span>{loc.category}</span>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>

            {/* Quick Swap Button */}
            <button
              type="button"
              className="journey-swap-btn"
              onClick={() => {
                const temp = originText;
                setOriginText(destText);
                setDestText(temp);
              }}
              title="Swap Origin & Destination"
            >
              ⇅
            </button>
          </div>
        ) : mode === 'coords' ? (
          /* MODE 2: BY LATITUDE & LONGITUDE */
          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
            <div style={{ padding: '10px', background: 'var(--bg-tertiary)', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-subtle)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '6px' }}>
                <span style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--accent-emerald)', display: 'flex', alignItems: 'center', gap: '4px' }}>
                  <span>🟢</span> Origin Coordinates
                </span>
                {userLocation && (
                  <button
                    type="button"
                    onClick={setFromToUserLocation}
                    className="btn btn-secondary btn-sm"
                    style={{ fontSize: '0.68rem', padding: '2px 8px' }}
                  >
                    🎯 Use Current GPS
                  </button>
                )}
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px' }}>
                <div>
                  <label style={{ fontSize: '0.68rem', color: 'var(--text-tertiary)' }}>Latitude (°N)</label>
                  <input
                    type="number"
                    step="0.0001"
                    className="journey-input"
                    placeholder="28.6315"
                    value={fromLat}
                    onChange={(e) => setFromLat(e.target.value)}
                    required
                  />
                </div>
                <div>
                  <label style={{ fontSize: '0.68rem', color: 'var(--text-tertiary)' }}>Longitude (°E)</label>
                  <input
                    type="number"
                    step="0.0001"
                    className="journey-input"
                    placeholder="77.2167"
                    value={fromLng}
                    onChange={(e) => setFromLng(e.target.value)}
                    required
                  />
                </div>
              </div>
            </div>

            <div style={{ padding: '10px', background: 'var(--bg-tertiary)', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-subtle)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '6px' }}>
                <span style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--accent-red)', display: 'flex', alignItems: 'center', gap: '4px' }}>
                  <span>📍</span> Destination Coordinates
                </span>
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px' }}>
                <div>
                  <label style={{ fontSize: '0.68rem', color: 'var(--text-tertiary)' }}>Latitude (°N)</label>
                  <input
                    type="number"
                    step="0.0001"
                    className="journey-input"
                    placeholder="28.5562"
                    value={toLat}
                    onChange={(e) => setToLat(e.target.value)}
                    required
                  />
                </div>
                <div>
                  <label style={{ fontSize: '0.68rem', color: 'var(--text-tertiary)' }}>Longitude (°E)</label>
                  <input
                    type="number"
                    step="0.0001"
                    className="journey-input"
                    placeholder="77.1000"
                    value={toLng}
                    onChange={(e) => setToLng(e.target.value)}
                    required
                  />
                </div>
              </div>
            </div>

            <div>
              <span style={{ fontSize: '0.68rem', color: 'var(--text-tertiary)', textTransform: 'uppercase', fontWeight: 700 }}>
                Destination Presets:
              </span>
              <div className="presets-container">
                {COORD_PRESETS.map((p, i) => (
                  <button
                    key={i}
                    type="button"
                    className="preset-chip"
                    onClick={() => {
                      setToLat(p.lat.toFixed(4));
                      setToLng(p.lng.toFixed(4));
                    }}
                  >
                    {p.label}
                  </button>
                ))}
              </div>
            </div>
          </div>
        ) : (
          /* MODE 3: BY AQI STATION */
          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
            <div style={{ padding: '10px', background: 'var(--bg-tertiary)', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-subtle)' }}>
              <label style={{ display: 'block', fontSize: '0.74rem', fontWeight: 700, color: 'var(--accent-emerald)', marginBottom: '6px' }}>
                🟢 Origin Monitoring Station
              </label>
              <select
                className="journey-input"
                value={fromStationId}
                onChange={(e) => setFromStationId(e.target.value)}
                disabled={loading}
                required
              >
                <option value="" disabled>Choose origin station...</option>
                {fromStationOptions.map((st) => (
                  <option key={st.station_id} value={st.station_id}>
                    {st.station_name} — AQI {Math.round(st.aqi || 0)}
                  </option>
                ))}
              </select>
            </div>

            <div style={{ padding: '10px', background: 'var(--bg-tertiary)', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-subtle)' }}>
              <label style={{ display: 'block', fontSize: '0.74rem', fontWeight: 700, color: 'var(--accent-red)', marginBottom: '6px' }}>
                📍 Destination Monitoring Station
              </label>
              <select
                className="journey-input"
                value={toStationId}
                onChange={(e) => setToStationId(e.target.value)}
                disabled={loading}
                required
              >
                <option value="" disabled>Choose destination station...</option>
                {toStationOptions.map((st) => (
                  <option key={st.station_id} value={st.station_id}>
                    {st.station_name} — AQI {Math.round(st.aqi || 0)}
                  </option>
                ))}
              </select>
            </div>
          </div>
        )}

        <button type="submit" className="btn btn-primary" disabled={loading} style={{ width: '100%', marginTop: '4px' }}>
          {loading ? (
            <>
              <div className="loading-spinner" />
              <span>Analyzing Spatial Inhaled Dosage...</span>
            </>
          ) : (
            <>
              <span>⚡</span>
              <span>Find Safest Low-Pollution Route</span>
            </>
          )}
        </button>
      </form>

      {/* Popular Presets */}
      {mode === 'name' && (
        <div style={{ marginTop: '12px', borderTop: '1px solid var(--border-subtle)', paddingTop: '10px' }}>
          <span style={{ fontSize: '0.68rem', color: 'var(--text-tertiary)', textTransform: 'uppercase', letterSpacing: '0.5px', fontWeight: 700 }}>
            Popular Delhi Corridors:
          </span>
          <div className="presets-container">
            {PRESETS.map((p, i) => (
              <button
                key={i}
                type="button"
                className="preset-chip"
                onClick={() => handleApplyPreset(p)}
                disabled={loading}
              >
                {p.label}
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
