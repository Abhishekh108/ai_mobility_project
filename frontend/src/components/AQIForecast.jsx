import React, { useState, useEffect, useMemo } from 'react';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  Filler
} from 'chart.js';
import { Line } from 'react-chartjs-2';
import { predictAQI } from '../services/api';

ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  Filler
);

export default function AQIForecast({ station, onClose }) {
  const [forecastData, setForecastData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [hoursAhead, setHoursAhead] = useState(24);

  useEffect(() => {
    if (!station?.station_id) return;

    let isMounted = true;
    setLoading(true);
    setError(null);

    predictAQI(station.station_id, hoursAhead)
      .then((res) => {
        if (isMounted) {
          setForecastData(res.data);
          setLoading(false);
        }
      })
      .catch((err) => {
        if (isMounted) {
          console.error('Forecast error:', err);
          setError(err.response?.data?.detail || 'Failed to generate neural forecast');
          setLoading(false);
        }
      });

    return () => {
      isMounted = false;
    };
  }, [station, hoursAhead]);

  // Compute key forecast stats (Peak, Lowest)
  const stats = useMemo(() => {
    if (!forecastData?.predictions || forecastData.predictions.length === 0) return null;
    const aqiVals = forecastData.predictions.map((p) => p.AQI || 0);
    const maxVal = Math.max(...aqiVals);
    const minVal = Math.min(...aqiVals);
    const maxHour = forecastData.predictions.find((p) => p.AQI === maxVal)?.hour;
    return { maxVal: Math.round(maxVal), minVal: Math.round(minVal), maxHour };
  }, [forecastData]);

  if (!station) return null;

  const chartLabels = forecastData?.predictions?.map((p) => `+${p.hour}h`) || [];
  const aqiValues = forecastData?.predictions?.map((p) => p.AQI) || [];
  const pm25Values = forecastData?.predictions?.map((p) => p['PM2.5']) || [];
  const pm10Values = forecastData?.predictions?.map((p) => p.PM10) || [];

  const chartData = {
    labels: chartLabels,
    datasets: [
      {
        label: 'Overall AQI',
        data: aqiValues,
        borderColor: '#38bdf8',
        backgroundColor: 'rgba(56, 189, 248, 0.12)',
        borderWidth: 2.5,
        fill: true,
        tension: 0.35,
        pointRadius: 2,
        pointHoverRadius: 5,
      },
      {
        label: 'PM2.5 (µg/m³)',
        data: pm25Values,
        borderColor: '#f59e0b',
        borderWidth: 1.5,
        borderDash: [4, 4],
        pointRadius: 0,
        tension: 0.3,
      },
      {
        label: 'PM10 (µg/m³)',
        data: pm10Values,
        borderColor: '#a855f7',
        borderWidth: 1.5,
        pointRadius: 0,
        tension: 0.3,
      },
    ],
  };

  const chartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        position: 'top',
        labels: {
          boxWidth: 10,
          font: { family: 'Plus Jakarta Sans', size: 11 },
          color: '#94a3b8',
        },
      },
      tooltip: {
        backgroundColor: 'rgba(15, 23, 42, 0.92)',
        titleFont: { family: 'Plus Jakarta Sans', size: 12, weight: 'bold' },
        bodyFont: { family: 'JetBrains Mono', size: 11 },
        padding: 10,
        cornerRadius: 8,
      },
    },
    scales: {
      x: {
        grid: { color: 'rgba(148, 163, 184, 0.1)' },
        ticks: { color: '#94a3b8', font: { size: 10 } },
      },
      y: {
        grid: { color: 'rgba(148, 163, 184, 0.1)' },
        ticks: { color: '#94a3b8', font: { size: 10 } },
      },
    },
  };

  return (
    <div className="glass-card" style={{ marginTop: '8px' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '10px' }}>
        <div>
          <div style={{ fontSize: '0.88rem', fontWeight: 800, color: 'var(--text-primary)' }}>
            Neural LSTM Forecast ({station.station_name})
          </div>
          <div style={{ fontSize: '0.7rem', color: 'var(--text-tertiary)' }}>
            Bi-directional Recurrent Air Quality Model
          </div>
        </div>
        {onClose && (
          <button
            onClick={onClose}
            className="btn btn-secondary btn-icon"
            style={{ width: '26px', height: '26px', fontSize: '0.8rem' }}
            title="Close Forecast"
          >
            ✕
          </button>
        )}
      </div>

      {/* Time Horizon Selector */}
      <div className="tabs" style={{ marginBottom: '10px' }}>
        {[6, 12, 24].map((h) => (
          <button
            key={h}
            type="button"
            className={`tab ${hoursAhead === h ? 'active' : ''}`}
            onClick={() => setHoursAhead(h)}
          >
            +{h} Hours
          </button>
        ))}
      </div>

      {loading ? (
        <div style={{ padding: '30px', textAlign: 'center', color: 'var(--text-tertiary)' }}>
          <div className="loading-spinner" style={{ borderTopColor: 'var(--brand-primary)', marginBottom: '8px' }} />
          <div style={{ fontSize: '0.78rem' }}>Generating neural trajectory...</div>
        </div>
      ) : error ? (
        <div style={{ padding: '16px', textAlign: 'center', color: 'var(--accent-red)', fontSize: '0.78rem' }}>
          {error}
        </div>
      ) : (
        <>
          {/* Top Quick Stats Strip */}
          {stats && (
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px', marginBottom: '10px' }}>
              <div style={{ padding: '6px 10px', background: 'var(--bg-tertiary)', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-subtle)' }}>
                <div style={{ fontSize: '0.65rem', color: 'var(--text-tertiary)', textTransform: 'uppercase', fontWeight: 700 }}>
                  Peak In Horizon
                </div>
                <div style={{ fontSize: '0.86rem', fontWeight: 800, color: 'var(--accent-red)' }}>
                  {stats.maxVal} AQI <span style={{ fontSize: '0.7rem', fontWeight: 500, color: 'var(--text-tertiary)' }}>(at +{stats.maxHour}h)</span>
                </div>
              </div>

              <div style={{ padding: '6px 10px', background: 'var(--bg-tertiary)', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-subtle)' }}>
                <div style={{ fontSize: '0.65rem', color: 'var(--text-tertiary)', textTransform: 'uppercase', fontWeight: 700 }}>
                  Lowest Exposure
                </div>
                <div style={{ fontSize: '0.86rem', fontWeight: 800, color: 'var(--accent-emerald)' }}>
                  {stats.minVal} AQI
                </div>
              </div>
            </div>
          )}

          {/* Chart Canvas */}
          <div style={{ height: '180px', width: '100%' }}>
            <Line data={chartData} options={chartOptions} />
          </div>
        </>
      )}
    </div>
  );
}
