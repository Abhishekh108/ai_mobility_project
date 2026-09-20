"""
Station endpoints — list all monitoring stations, get details and latest readings.
"""
from fastapi import APIRouter, HTTPException
from typing import List, Dict, Optional
from app.database import get_db
from app.services.alerts import classify_aqi

router = APIRouter(prefix="/api", tags=["stations"])


@router.get("/stations", response_model=List[Dict])
async def list_stations():
    """
    Get all 28 Delhi monitoring stations with their latest readings.
    """
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT station_id, station_name, latitude, longitude,
               pm25, pm10, no2, o3, co, so2, aqi, aqi_bucket,
               temperature, humidity, wind_speed, updated_at
        FROM station_readings
        ORDER BY station_id
    """)

    stations = []
    for row in cursor.fetchall():
        aqi_val = row[10]
        classification = classify_aqi(aqi_val) if aqi_val else None

        stations.append({
            'station_id': row[0],
            'station_name': row[1],
            'latitude': row[2],
            'longitude': row[3],
            'readings': {
                'pm25': row[4],
                'pm10': row[5],
                'no2': row[6],
                'o3': row[7],
                'co': row[8],
                'so2': row[9],
            },
            'aqi': aqi_val,
            'aqi_bucket': row[11],
            'classification': classification,
            'weather': {
                'temperature': row[12],
                'humidity': row[13],
                'wind_speed': row[14],
            },
            'updated_at': row[15]
        })

    conn.close()
    return stations


@router.get("/stations/{station_id}")
async def get_station(station_id: str):
    """
    Get detailed info for a single station.
    """
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT station_id, station_name, latitude, longitude,
               pm25, pm10, no2, o3, co, so2, aqi, aqi_bucket,
               temperature, humidity, wind_speed, updated_at
        FROM station_readings
        WHERE station_id = ?
    """, (station_id.upper(),))

    row = cursor.fetchone()
    conn.close()

    if row is None:
        raise HTTPException(status_code=404, detail=f"Station {station_id} not found")

    aqi_val = row[10]
    classification = classify_aqi(aqi_val) if aqi_val else None

    return {
        'station_id': row[0],
        'station_name': row[1],
        'latitude': row[2],
        'longitude': row[3],
        'readings': {
            'pm25': row[4],
            'pm10': row[5],
            'no2': row[6],
            'o3': row[7],
            'co': row[8],
            'so2': row[9],
        },
        'aqi': aqi_val,
        'aqi_bucket': row[11],
        'classification': classification,
        'weather': {
            'temperature': row[12],
            'humidity': row[13],
            'wind_speed': row[14],
        },
        'updated_at': row[15]
    }


@router.get("/stations/{station_id}/live")
async def get_station_live(station_id: str):
    """
    Get live air quality and weather from Open-Meteo for a station's coordinates.
    """
    from app.services.open_meteo import fetch_live_air_quality, fetch_live_weather

    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("SELECT latitude, longitude, station_name FROM station_readings WHERE station_id = ?", 
                   (station_id.upper(),))
    row = cursor.fetchone()
    conn.close()

    if row is None:
        raise HTTPException(status_code=404, detail=f"Station {station_id} not found")

    lat, lng, name = row[0], row[1], row[2]

    weather = await fetch_live_weather(lat, lng)
    air_quality = await fetch_live_air_quality(lat, lng)

    return {
        'station_id': station_id,
        'station_name': name,
        'latitude': lat,
        'longitude': lng,
        'live_weather': weather,
        'live_air_quality': air_quality
    }
