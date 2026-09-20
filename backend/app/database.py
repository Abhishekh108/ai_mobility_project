import sqlite3
import os
import json
from datetime import datetime

DB_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "aqi_system.db")


def get_db():
    """Get a database connection."""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    """Initialize database tables."""
    conn = get_db()
    cursor = conn.cursor()

    # User profiles table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS user_profiles (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            health_category TEXT NOT NULL DEFAULT 'normal',
            custom_threshold INTEGER,
            fcm_token TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
    """)

    # Alert history table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS alert_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            alert_type TEXT NOT NULL,
            message TEXT NOT NULL,
            aqi_value REAL,
            location_lat REAL,
            location_lng REAL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES user_profiles(id)
        )
    """)

    # Station latest readings cache
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS station_readings (
            station_id TEXT PRIMARY KEY,
            station_name TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            pm25 REAL,
            pm10 REAL,
            no2 REAL,
            o3 REAL,
            co REAL,
            so2 REAL,
            aqi REAL,
            aqi_bucket TEXT,
            temperature REAL,
            humidity REAL,
            wind_speed REAL,
            updated_at TEXT NOT NULL
        )
    """)

    # Personal Exposure History table (Week 5-6 requirement)
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS exposure_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            origin TEXT NOT NULL,
            destination TEXT NOT NULL,
            route_summary TEXT NOT NULL,
            distance_km REAL NOT NULL,
            duration_minutes REAL NOT NULL,
            average_aqi REAL NOT NULL,
            cumulative_exposure REAL NOT NULL,
            travel_time TEXT,
            created_at TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES user_profiles(id)
        )
    """)

    # Optional column migrations for user_profiles
    try:
        cursor.execute("ALTER TABLE user_profiles ADD COLUMN notification_preferences TEXT DEFAULT '{\"enabled\":true,\"min_severity\":\"moderate\"}'")
    except Exception:
        pass  # Column already exists

    conn.commit()
    conn.close()


def seed_stations(data_path: str):
    """Seed station data from the CSV file."""
    import pandas as pd

    conn = get_db()
    cursor = conn.cursor()

    # Check if stations are already seeded
    cursor.execute("SELECT COUNT(*) FROM station_readings")
    count = cursor.fetchone()[0]
    if count > 0:
        conn.close()
        return

    print("Seeding station data from CSV...")
    # Read just the last record per station for latest readings
    df = pd.read_csv(data_path)
    df.columns = df.columns.str.strip()

    # Get the latest record per station
    stations = df.groupby('StationId').last().reset_index()

    for _, row in stations.iterrows():
        cursor.execute("""
            INSERT OR REPLACE INTO station_readings 
            (station_id, station_name, latitude, longitude, pm25, pm10, no2, o3, co, so2, aqi, aqi_bucket, temperature, humidity, wind_speed, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            row['StationId'],
            row['StationName'],
            row['Latitude'],
            row['Longitude'],
            row.get('PM2.5'),
            row.get('PM10'),
            row.get('NO2'),
            row.get('O3'),
            row.get('CO'),
            row.get('SO2'),
            row.get('AQI'),
            row.get('AQI_Bucket'),
            row.get('temp (°C)', row.get('temp (�C)', None)),
            row.get('Relative Humidity (%)'),
            row.get('Average Wind Speed (km/h)'),
            datetime.now().isoformat()
        ))

    conn.commit()
    conn.close()
    print(f"Seeded {len(stations)} stations.")
