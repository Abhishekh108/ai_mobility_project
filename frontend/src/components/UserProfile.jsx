import React, { useState, useEffect } from 'react';
import { createProfile, updateProfile, getUserAlerts } from '../services/api';
import { requestNotificationPermission } from '../services/firebase';

const CATEGORIES = [
  { id: 'normal', icon: '🏃', label: 'Healthy Adult', defaultThreshold: 300, desc: 'Alerts at Severe (>300)' },
  { id: 'asthmatic', icon: '🫁', label: 'Asthmatic / Respiratory', defaultThreshold: 150, desc: 'Sensitive: Alerts at Moderate (>150)' },
  { id: 'elderly', icon: '👵', label: 'Senior Citizen (65+)', defaultThreshold: 200, desc: 'Vulnerable: Alerts at Poor (>200)' },
  { id: 'children', icon: '👶', label: 'Child / Infant', defaultThreshold: 150, desc: 'Vulnerable: Alerts at Moderate (>150)' },
];

export default function UserProfile({ profile, onProfileUpdate, onClose }) {
  const [name, setName] = useState(profile?.name || 'Delhi Commuter');
  const [category, setCategory] = useState(profile?.health_category || 'normal');
  const [customThreshold, setCustomThreshold] = useState(profile?.custom_threshold || 200);
  const [useCustom, setUseCustom] = useState(Boolean(profile?.custom_threshold));
  const [notificationsEnabled, setNotificationsEnabled] = useState(Boolean(profile?.fcm_token));
  const [alerts, setAlerts] = useState([]);
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState('');

  // Fetch recent alerts when user profile exists
  useEffect(() => {
    if (profile?.id) {
      getUserAlerts(profile.id)
        .then((res) => setAlerts(res.data || []))
        .catch((err) => console.error('Error fetching alerts:', err));
    }
  }, [profile]);

  const handleSave = async (e) => {
    e.preventDefault();
    setSaving(true);
    setMsg('');

    try {
      let fcmToken = profile?.fcm_token || null;
      if (notificationsEnabled && !fcmToken) {
        fcmToken = await requestNotificationPermission();
      }

      const payload = {
        name,
        health_category: category,
        custom_threshold: useCustom ? Number(customThreshold) : null,
        fcm_token: fcmToken,
      };

      let res;
      if (profile?.id) {
        res = await updateProfile(profile.id, payload);
      } else {
        res = await createProfile(payload);
      }

      onProfileUpdate(res.data);
      setMsg('Preferences updated successfully!');
      setTimeout(() => {
        setMsg('');
        if (onClose) onClose();
      }, 1000);
    } catch (err) {
      console.error('Error saving profile:', err);
      setMsg('Failed to update profile.');
    } finally {
      setSaving(false);
    }
  };

  const handleEnablePush = async () => {
    const token = await requestNotificationPermission();
    if (token) {
      setNotificationsEnabled(true);
      setMsg('Push notifications enabled!');
      setTimeout(() => setMsg(''), 3000);
    }
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-dialog" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <div className="modal-title">
            <span>🛡️</span>
            <span>Health Profile & Sensitivity Thresholds</span>
          </div>
          {onClose && (
            <button onClick={onClose} className="modal-close-btn" title="Close Profile Dialog">
              ✕
            </button>
          )}
        </div>

        <div className="modal-body">
          <form onSubmit={handleSave} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
            <div>
              <label style={{ display: 'block', fontSize: '0.78rem', fontWeight: 700, color: 'var(--text-secondary)', marginBottom: '6px' }}>
                Commuter Profile Name
              </label>
              <input
                type="text"
                className="journey-input"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="e.g. Delhi Commuter"
                required
              />
            </div>

            <div>
              <label style={{ display: 'block', fontSize: '0.78rem', fontWeight: 700, color: 'var(--text-secondary)', marginBottom: '6px' }}>
                Health Persona
              </label>
              <div className="persona-cards-grid">
                {CATEGORIES.map((c) => (
                  <div
                    key={c.id}
                    className={`persona-card ${category === c.id ? 'selected' : ''}`}
                    onClick={() => {
                      setCategory(c.id);
                      if (!useCustom) {
                        setCustomThreshold(c.defaultThreshold);
                      }
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                      <span style={{ fontSize: '1.1rem' }}>{c.icon}</span>
                      <span className="persona-card-title">{c.label}</span>
                    </div>
                    <span className="persona-card-desc">{c.desc}</span>
                  </div>
                ))}
              </div>
            </div>

            {/* Custom Threshold Toggle */}
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '8px 0' }}>
              <span style={{ fontSize: '0.82rem', fontWeight: 600, color: 'var(--text-secondary)' }}>
                Override Custom AQI Trigger
              </span>
              <label className="toggle">
                <input
                  type="checkbox"
                  checked={useCustom}
                  onChange={(e) => setUseCustom(e.target.checked)}
                />
                <span className="toggle-slider"></span>
              </label>
            </div>

            {useCustom && (
              <div style={{ padding: '10px 14px', background: 'var(--bg-tertiary)', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-subtle)' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.78rem', marginBottom: '6px' }}>
                  <span style={{ color: 'var(--text-secondary)' }}>Alert when local AQI exceeds:</span>
                  <span style={{ fontWeight: 800, color: 'var(--accent-amber)', fontFamily: 'var(--font-mono)' }}>
                    {customThreshold} AQI
                  </span>
                </div>
                <input
                  type="range"
                  min="50"
                  max="450"
                  step="10"
                  value={customThreshold}
                  onChange={(e) => setCustomThreshold(e.target.value)}
                  style={{ width: '100%', accentColor: 'var(--brand-primary)', cursor: 'pointer' }}
                />
              </div>
            )}

            {/* Push Notifications Card */}
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                padding: '12px',
                background: 'var(--bg-tertiary)',
                borderRadius: 'var(--radius-sm)',
                border: '1px solid var(--border-subtle)',
              }}
            >
              <div>
                <div style={{ fontSize: '0.82rem', fontWeight: 700, color: 'var(--text-primary)' }}>
                  Push Notifications (FCM)
                </div>
                <div style={{ fontSize: '0.72rem', color: 'var(--text-tertiary)' }}>
                  Receive real-time mobile/browser alerts on severe exposure
                </div>
              </div>
              <button
                type="button"
                className="btn btn-secondary btn-sm"
                onClick={handleEnablePush}
              >
                {notificationsEnabled ? '✓ Enabled' : 'Enable Push'}
              </button>
            </div>

            {msg && (
              <div style={{ fontSize: '0.82rem', color: 'var(--accent-emerald)', textAlign: 'center', fontWeight: 600 }}>
                {msg}
              </div>
            )}

            <button type="submit" className="btn btn-primary" disabled={saving} style={{ width: '100%', marginTop: '6px' }}>
              {saving ? 'Saving Preferences...' : 'Save Health Profile'}
            </button>
          </form>

          {/* Alert Log */}
          {alerts.length > 0 && (
            <div style={{ marginTop: '10px', borderTop: '1px solid var(--border-subtle)', paddingTop: '10px' }}>
              <div style={{ fontSize: '0.82rem', fontWeight: 700, color: 'var(--text-primary)', marginBottom: '6px' }}>
                Recent Exposure Alerts
              </div>
              <div style={{ maxHeight: '120px', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '6px' }}>
                {alerts.map((a) => (
                  <div
                    key={a.id}
                    style={{
                      fontSize: '0.74rem',
                      padding: '8px 10px',
                      background: 'var(--accent-red-light)',
                      borderLeft: '3px solid var(--accent-red)',
                      borderRadius: 'var(--radius-xs)',
                    }}
                  >
                    <div style={{ fontWeight: 700, color: 'var(--accent-red)' }}>{a.alert_type?.toUpperCase()}</div>
                    <div style={{ color: 'var(--text-secondary)' }}>{a.message}</div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
