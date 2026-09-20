import React, { useState, useCallback, useEffect, useRef, memo } from 'react';
import { GoogleMap, useJsApiLoader, Marker, TrafficLayer, InfoWindow } from '@react-google-maps/api';
import TopTripHeading from './TopTripHeading';

const GOOGLE_MAPS_API_KEY = import.meta.env.VITE_GOOGLE_MAPS_API_KEY;

const MAP_CONTAINER_STYLE = { width: '100%', height: '100%' };
const DELHI_CENTER = { lat: 28.6139, lng: 77.2090 };

const GOOGLE_MAPS_LIGHT_STYLE = [
  { featureType: 'poi', elementType: 'all', stylers: [{ visibility: 'off' }] },
  { featureType: 'transit.station', elementType: 'all', stylers: [{ visibility: 'off' }] },
  { featureType: 'water', elementType: 'geometry', stylers: [{ color: '#d8eafb' }] },
  { featureType: 'poi.park', elementType: 'geometry', stylers: [{ color: '#e2f4e8' }, { visibility: 'on' }] },
  { featureType: 'landscape', elementType: 'geometry', stylers: [{ color: '#f8fafc' }] },
  { featureType: 'road', elementType: 'geometry', stylers: [{ color: '#ffffff' }] },
  { featureType: 'road.highway', elementType: 'geometry.fill', stylers: [{ color: '#fef08a' }] },
  { featureType: 'road.highway', elementType: 'geometry.stroke', stylers: [{ color: '#facc15' }] },
  { featureType: 'road', elementType: 'geometry.stroke', stylers: [{ color: '#e2e8f0' }] },
  { featureType: 'road', elementType: 'labels.text.fill', stylers: [{ color: '#64748b' }] },
];

const GOOGLE_MAPS_DARK_STYLE = [
  { elementType: 'geometry', stylers: [{ color: '#131b29' }] },
  { elementType: 'labels.text.stroke', stylers: [{ color: '#131b29' }] },
  { elementType: 'labels.text.fill', stylers: [{ color: '#94a3b8' }] },
  { featureType: 'administrative.locality', elementType: 'labels.text.fill', stylers: [{ color: '#f1f5f9' }] },
  { featureType: 'poi', stylers: [{ visibility: 'off' }] },
  { featureType: 'road', elementType: 'geometry', stylers: [{ color: '#1e293b' }] },
  { featureType: 'road', elementType: 'geometry.stroke', stylers: [{ color: '#0f172a' }] },
  { featureType: 'road', elementType: 'labels.text.fill', stylers: [{ color: '#94a3b8' }] },
  { featureType: 'road.highway', elementType: 'geometry', stylers: [{ color: '#293548' }] },
  { featureType: 'road.highway', elementType: 'geometry.stroke', stylers: [{ color: '#1e293b' }] },
  { featureType: 'road.highway', elementType: 'labels.text.fill', stylers: [{ color: '#f8fafc' }] },
  { featureType: 'transit', stylers: [{ visibility: 'off' }] },
  { featureType: 'water', elementType: 'geometry', stylers: [{ color: '#090e17' }] },
  { featureType: 'water', elementType: 'labels.text.fill', stylers: [{ color: '#334155' }] },
  { featureType: 'water', elementType: 'labels.text.stroke', stylers: [{ color: '#090e17' }] },
  { featureType: 'poi.park', elementType: 'geometry', stylers: [{ color: '#0d231a' }, { visibility: 'on' }] },
];

function decodePolyline(encoded) {
  if (!encoded) return [];
  const poly = [];
  let index = 0, len = encoded.length, lat = 0, lng = 0;
  while (index < len) {
    let b, shift = 0, result = 0;
    do { b = encoded.charCodeAt(index++) - 63; result |= (b & 0x1f) << shift; shift += 5; } while (b >= 0x20);
    lat += ((result & 1) ? ~(result >> 1) : (result >> 1));
    shift = 0; result = 0;
    do { b = encoded.charCodeAt(index++) - 63; result |= (b & 0x1f) << shift; shift += 5; } while (b >= 0x20);
    lng += ((result & 1) ? ~(result >> 1) : (result >> 1));
    poly.push({ lat: lat / 1e5, lng: lng / 1e5 });
  }
  return poly;
}

function getAQIColor(aqi) {
  if (!aqi || isNaN(aqi)) return '#94a3b8';
  if (aqi <= 50) return '#059669';
  if (aqi <= 100) return '#10b981';
  if (aqi <= 200) return '#d97706';
  if (aqi <= 300) return '#dc2626';
  if (aqi <= 400) return '#9333ea';
  return '#7e22ce';
}

function MapView({
  stations = [],
  _selectedStation,
  onSelectStation,
  routes = [],
  safestIndex = 0,
  activeRouteIndex = 0,
  onSelectRoute,
  showTraffic = false,
  userLocation = null,
  onMapClick = null,
  routeMeta = null,
  onQuickSearch = null,
  avgDelhiAQI = 0,
  theme = 'light',
}) {
  const { isLoaded, loadError } = useJsApiLoader({
    id: 'google-map-script',
    googleMapsApiKey: GOOGLE_MAPS_API_KEY,
  });

  const [map, setMap] = useState(null);
  const [activeInfoWindow, setActiveInfoWindow] = useState(null);
  const [showStations, setShowStations] = useState(false);

  // Direct Google Maps API refs for crisp polylines
  const outlineRef = useRef(null);
  const blueRef = useRef(null);

  const onLoad = useCallback((m) => setMap(m), []);
  const onUnmount = useCallback(() => setMap(null), []);

  // Update route polylines whenever map, routes, or active route changes
  useEffect(() => {
    if (!map || !window.google) return;

    const path = decodePolyline(routes[activeRouteIndex]?.polyline_encoded ?? '');

    if (!outlineRef.current) {
      outlineRef.current = new window.google.maps.Polyline({
        map, path,
        strokeColor: theme === 'dark' ? '#090d16' : '#ffffff',
        strokeOpacity: 0.9, strokeWeight: 8,
        zIndex: 28, clickable: false,
      });
      blueRef.current = new window.google.maps.Polyline({
        map, path,
        strokeColor: '#3b82f6', strokeOpacity: 1.0, strokeWeight: 5,
        zIndex: 30, clickable: false,
        icons: [{
          icon: {
            path: window.google.maps.SymbolPath.FORWARD_OPEN_ARROW,
            scale: 3, strokeColor: '#ffffff', strokeWeight: 2, fillOpacity: 0,
          },
          offset: '30px', repeat: '80px',
        }],
      });
    } else {
      outlineRef.current.setOptions({ strokeColor: theme === 'dark' ? '#090d16' : '#ffffff' });
      outlineRef.current.setPath(path);
      blueRef.current.setPath(path);
    }

    if (path.length > 0) {
      const bounds = new window.google.maps.LatLngBounds();
      path.forEach((p) => bounds.extend(p));
      map.fitBounds(bounds, { top: 80, right: 80, bottom: 80, left: 450 });
    }
  }, [map, routes, activeRouteIndex, theme]);

  // Clean overlays if routes cleared
  useEffect(() => {
    if (routes.length === 0) {
      outlineRef.current?.setPath([]);
      blueRef.current?.setPath([]);
    }
  }, [routes]);

  // Clean on unmount
  useEffect(() => {
    return () => {
      outlineRef.current?.setMap(null);
      blueRef.current?.setMap(null);
      outlineRef.current = null;
      blueRef.current = null;
    };
  }, []);

  const handleRecenter = () => {
    if (!map) return;
    map.panTo(userLocation || DELHI_CENTER);
    map.setZoom(11);
  };

  if (loadError) return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', color: 'var(--accent-red)' }}>
      <h3>Google Maps Connection Error</h3>
      <p style={{ color: 'var(--text-tertiary)' }}>Please check internet access and GOOGLE_MAPS_API_KEY configuration.</p>
    </div>
  );

  if (!isLoaded) return (
    <div style={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '12px' }}>
      <div className="loading-spinner" style={{ borderTopColor: 'var(--brand-primary)', width: '22px', height: '22px' }} />
      <span style={{ color: 'var(--text-secondary)', fontWeight: 600 }}>Initializing Environmental Spatial Map...</span>
    </div>
  );

  // Origin / Destination coordinates
  let originPoint = null, destPoint = null;
  if (routes.length > 0) {
    const pts = decodePolyline(routes[activeRouteIndex]?.polyline_encoded ?? '');
    if (pts.length > 0) {
      originPoint = pts[0];
      destPoint = pts[pts.length - 1];
    }
  }

  const isSafestActive = activeRouteIndex === safestIndex;

  return (
    <div className="map-container">
      {/* Floating Top Trip HUD */}
      <TopTripHeading
        routes={routes}
        activeRouteIndex={activeRouteIndex}
        safestIndex={safestIndex}
        onSelectRoute={onSelectRoute}
        routeMeta={routeMeta}
        onQuickSearch={onQuickSearch}
        avgDelhiAQI={avgDelhiAQI}
      />

      {/* Floating Map Action Controls (Top Right) */}
      <div className="map-floating-controls">
        <button
          type="button"
          onClick={() => setShowStations((s) => !s)}
          className={`map-control-btn ${showStations ? 'active' : ''}`}
          title="Toggle Delhi Monitoring Station Markers"
        >
          <span>📍</span>
          <span>{showStations ? 'AQI Stations: Active' : 'Show AQI Stations'}</span>
        </button>

        <button
          type="button"
          onClick={handleRecenter}
          className="map-control-btn"
          title="Recenter Map on Delhi"
        >
          <span>🔄</span>
          <span>Recenter Delhi</span>
        </button>
      </div>

      {/* Bottom Right Floating AQI Spectrum Legend */}
      <div className="map-aqi-legend">
        <div className="legend-title">
          <span>CPCB Air Quality Index</span>
          <span>(AQI)</span>
        </div>
        <div className="legend-bar">
          <div className="legend-segment" style={{ backgroundColor: '#059669' }} title="Good (0-50)" />
          <div className="legend-segment" style={{ backgroundColor: '#10b981' }} title="Satisfactory (51-100)" />
          <div className="legend-segment" style={{ backgroundColor: '#d97706' }} title="Moderate (101-200)" />
          <div className="legend-segment" style={{ backgroundColor: '#dc2626' }} title="Poor (201-300)" />
          <div className="legend-segment" style={{ backgroundColor: '#9333ea' }} title="Very Poor (301-400)" />
          <div className="legend-segment" style={{ backgroundColor: '#7e22ce' }} title="Severe (400+)" />
        </div>
        <div className="legend-labels">
          <span>0 (Good)</span>
          <span>100</span>
          <span>200</span>
          <span>300</span>
          <span>400+</span>
        </div>
      </div>

      {/* Google Map Canvas */}
      <GoogleMap
        mapContainerStyle={MAP_CONTAINER_STYLE}
        center={userLocation || DELHI_CENTER}
        zoom={11}
        onLoad={onLoad}
        onUnmount={onUnmount}
        onClick={(e) => {
          if (onMapClick && e.latLng) {
            onMapClick({ lat: e.latLng.lat(), lng: e.latLng.lng() });
          }
        }}
        options={{
          styles: theme === 'dark' ? GOOGLE_MAPS_DARK_STYLE : GOOGLE_MAPS_LIGHT_STYLE,
          disableDefaultUI: false,
          zoomControl: true,
          mapTypeControl: false,
          streetViewControl: false,
          fullscreenControl: false,
        }}
      >
        {showTraffic && <TrafficLayer />}

        {userLocation && (
          <Marker
            position={{ lat: userLocation.lat, lng: userLocation.lng }}
            title="Your Current Location"
            icon={{
              path: window.google?.maps?.SymbolPath?.CIRCLE || 0,
              scale: 8,
              fillColor: '#3b82f6',
              fillOpacity: 1,
              strokeColor: '#ffffff',
              strokeWeight: 2.5,
            }}
          />
        )}

        {originPoint && (
          <Marker
            position={originPoint}
            title="Starting Point (Origin A)"
            icon={{
              path: window.google?.maps?.SymbolPath?.CIRCLE || 0,
              scale: 7,
              fillColor: '#10b981',
              fillOpacity: 1,
              strokeColor: '#ffffff',
              strokeWeight: 2,
            }}
          />
        )}

        {destPoint && (
          <>
            {isSafestActive && (
              <Marker
                position={destPoint}
                zIndex={5}
                icon={{
                  path: window.google?.maps?.SymbolPath?.CIRCLE || 0,
                  scale: 16,
                  fillColor: '#10b981',
                  fillOpacity: 0.22,
                  strokeColor: '#10b981',
                  strokeWeight: 2,
                  strokeOpacity: 0.8,
                }}
              />
            )}
            <Marker
              position={destPoint}
              title="Destination (Point B)"
              zIndex={10}
              icon={{
                path: 'M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z',
                fillColor: '#ef4444',
                fillOpacity: 1,
                strokeColor: '#ffffff',
                strokeWeight: 1.5,
                scale: 1.35,
                anchor: window.google ? new window.google.maps.Point(12, 22) : undefined,
              }}
            />
          </>
        )}

        {showStations && stations.map((st) => (
          <Marker
            key={st.station_id}
            position={{ lat: st.latitude, lng: st.longitude }}
            title={`${st.station_name} (AQI: ${Math.round(st.aqi || 0)})`}
            icon={{
              path: window.google?.maps?.SymbolPath?.CIRCLE || 0,
              scale: 5.5,
              fillColor: getAQIColor(st.aqi),
              fillOpacity: 0.95,
              strokeColor: '#ffffff',
              strokeWeight: 1.5,
            }}
            onClick={() => {
              setActiveInfoWindow(st);
              if (onSelectStation) onSelectStation(st);
            }}
          />
        ))}

        {activeInfoWindow && (
          <InfoWindow
            position={{ lat: activeInfoWindow.latitude, lng: activeInfoWindow.longitude }}
            onCloseClick={() => setActiveInfoWindow(null)}
          >
            <div style={{ color: '#0f172a', padding: '6px', maxWidth: '240px', fontFamily: 'var(--font-sans)' }}>
              <div style={{ fontWeight: 800, fontSize: '0.92rem', marginBottom: '4px' }}>
                {activeInfoWindow.station_name}
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '8px' }}>
                <span style={{
                  backgroundColor: getAQIColor(activeInfoWindow.aqi),
                  color: '#fff',
                  padding: '2px 8px',
                  borderRadius: '12px',
                  fontWeight: 800,
                  fontSize: '0.8rem',
                }}>
                  AQI: {Math.round(activeInfoWindow.aqi || 0)}
                </span>
                <span style={{ fontSize: '0.75rem', color: '#64748b' }}>
                  {activeInfoWindow.classification?.label || 'Live Monitoring'}
                </span>
              </div>
              <button
                onClick={() => {
                  if (onSelectStation) onSelectStation(activeInfoWindow);
                }}
                className="btn btn-primary btn-sm"
                style={{ width: '100%', fontSize: '0.74rem' }}
              >
                View 24h AI Forecast
              </button>
            </div>
          </InfoWindow>
        )}
      </GoogleMap>
    </div>
  );
}

export default memo(MapView);
