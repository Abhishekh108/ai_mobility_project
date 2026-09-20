"""
Alert service for Firebase Cloud Messaging (FCM) push notifications.
Falls back to in-memory alert storage when Firebase credentials are not configured.
"""
import json
from datetime import datetime
from typing import Dict, Optional, List
from app.config import settings
from app.database import get_db

# Firebase initialization (optional)
_firebase_initialized = False

def init_firebase():
    """Initialize Firebase Admin SDK if credentials are available."""
    global _firebase_initialized
    if _firebase_initialized:
        return True
    
    if settings.FIREBASE_CREDENTIALS_PATH:
        try:
            import firebase_admin
            from firebase_admin import credentials
            cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
            firebase_admin.initialize_app(cred)
            _firebase_initialized = True
            print("Firebase Admin SDK initialized.")
            return True
        except Exception as e:
            print(f"Firebase initialization failed: {e}")
    
    print("Firebase not configured - using local alert storage only.")
    return False


def classify_aqi(aqi_value: float) -> Dict:
    """Classify AQI value into a health category with advisory."""
    for cat in settings.AQI_CATEGORIES:
        if cat['min'] <= aqi_value <= cat['max']:
            return {
                'label': cat['label'],
                'color': cat['color'],
                'advice': cat['advice']
            }
    
    # Above 500
    return {
        'label': 'Hazardous',
        'color': '#7E0023',
        'advice': 'Health emergency. Stay indoors with air purifier.'
    }


def check_threshold(aqi_value: float, health_category: str, custom_threshold: Optional[int] = None) -> bool:
    """
    Check if AQI exceeds the threshold for a given health category.
    
    Returns:
        True if alert should be triggered
    """
    threshold = custom_threshold or settings.HEALTH_THRESHOLDS.get(health_category, 300)
    return aqi_value > threshold


async def send_alert(user_id: str, fcm_token: Optional[str], 
                     alert_type: str, aqi_value: float,
                     message: str, lat: float = None, lng: float = None) -> Dict:
    """
    Send an alert notification. Uses FCM if available, otherwise stores locally.
    
    Args:
        user_id: User profile ID
        fcm_token: Firebase Cloud Messaging token (optional)
        alert_type: Type of alert ('route_warning', 'live_position', 'forecast')
        aqi_value: Current AQI value
        message: Alert message text
        lat: Location latitude (optional)
        lng: Location longitude (optional)
    
    Returns:
        Dict with alert status and details
    """
    alert_data = {
        'user_id': user_id,
        'alert_type': alert_type,
        'aqi_value': aqi_value,
        'message': message,
        'location_lat': lat,
        'location_lng': lng,
        'created_at': datetime.now().isoformat(),
        'delivered_via': 'local'
    }

    # Try FCM delivery
    if fcm_token and _firebase_initialized:
        try:
            from firebase_admin import messaging
            fcm_message = messaging.Message(
                notification=messaging.Notification(
                    title='⚠️ AQI Alert - Health Warning',
                    body=message,
                ),
                data={
                    'alert_type': alert_type,
                    'aqi_value': str(aqi_value),
                    'lat': str(lat or ''),
                    'lng': str(lng or ''),
                },
                token=fcm_token,
                android=messaging.AndroidConfig(
                    priority='high',
                    notification=messaging.AndroidNotification(
                        icon='warning',
                        color='#CC0033'
                    )
                ),
                webpush=messaging.WebpushConfig(
                    notification=messaging.WebpushNotification(
                        icon='/alert-icon.png',
                        badge='/badge-icon.png'
                    )
                )
            )
            response = messaging.send(fcm_message)
            alert_data['delivered_via'] = 'fcm'
            alert_data['fcm_response'] = response
            print(f"FCM alert sent: {response}")
        except Exception as e:
            print(f"FCM send failed: {e}")
            alert_data['delivered_via'] = 'local_fallback'

    # Store alert in database
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO alert_history (user_id, alert_type, message, aqi_value, location_lat, location_lng, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    """, (user_id, alert_type, message, aqi_value, lat, lng, alert_data['created_at']))
    conn.commit()
    alert_data['alert_id'] = cursor.lastrowid
    conn.close()

    return alert_data


def get_user_alerts(user_id: str, limit: int = 20) -> List[Dict]:
    """Get recent alerts for a user."""
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT id, alert_type, message, aqi_value, location_lat, location_lng, created_at
        FROM alert_history
        WHERE user_id = ?
        ORDER BY created_at DESC
        LIMIT ?
    """, (user_id, limit))

    alerts = []
    for row in cursor.fetchall():
        alerts.append({
            'id': row[0],
            'alert_type': row[1],
            'message': row[2],
            'aqi_value': row[3],
            'location_lat': row[4],
            'location_lng': row[5],
            'created_at': row[6]
        })

    conn.close()
    return alerts
