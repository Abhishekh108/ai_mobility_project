"""
Open-Meteo API integration for live weather and air quality data.
Free API, no key required.
"""
import aiohttp
from typing import Dict, Optional
from app.config import settings


async def fetch_live_weather(lat: float, lng: float) -> Optional[Dict]:
    """
    Fetch current weather conditions from Open-Meteo.
    
    Args:
        lat: Latitude
        lng: Longitude
    
    Returns:
        Dict with temperature, humidity, wind, pressure, etc.
    """
    params = {
        'latitude': lat,
        'longitude': lng,
        'current_weather': 'true',
        'hourly': 'temperature_2m,relative_humidity_2m,wind_speed_10m,surface_pressure',
        'timezone': 'Asia/Kolkata',
        'forecast_days': 1
    }

    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(settings.OPEN_METEO_WEATHER_URL, params=params, timeout=aiohttp.ClientTimeout(total=10)) as resp:
                if resp.status == 200:
                    data = await resp.json()
                    current = data.get('current_weather', {})
                    return {
                        'temperature': current.get('temperature'),
                        'wind_speed': current.get('windspeed'),
                        'wind_direction': current.get('winddirection'),
                        'weather_code': current.get('weathercode'),
                        'time': current.get('time'),
                    }
    except Exception as e:
        print(f"Open-Meteo weather API error: {e}")

    return None


async def fetch_live_air_quality(lat: float, lng: float) -> Optional[Dict]:
    """
    Fetch current air quality data from Open-Meteo Air Quality API.
    
    Returns:
        Dict with PM2.5, PM10, NO2, O3, CO, SO2, and European AQI
    """
    params = {
        'latitude': lat,
        'longitude': lng,
        'current': 'pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone,european_aqi',
        'timezone': 'Asia/Kolkata'
    }

    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(settings.OPEN_METEO_AQ_URL, params=params, timeout=aiohttp.ClientTimeout(total=10)) as resp:
                if resp.status == 200:
                    data = await resp.json()
                    current = data.get('current', {})
                    return {
                        'pm25': current.get('pm2_5'),
                        'pm10': current.get('pm10'),
                        'no2': current.get('nitrogen_dioxide'),
                        'o3': current.get('ozone'),
                        'co': current.get('carbon_monoxide'),
                        'so2': current.get('sulphur_dioxide'),
                        'european_aqi': current.get('european_aqi'),
                        'time': current.get('time'),
                    }
    except Exception as e:
        print(f"Open-Meteo AQ API error: {e}")

    return None


async def fetch_forecast_weather(lat: float, lng: float, hours: int = 24) -> Optional[Dict]:
    """
    Fetch hourly weather forecast for the next N hours.
    """
    params = {
        'latitude': lat,
        'longitude': lng,
        'hourly': 'temperature_2m,relative_humidity_2m,dew_point_2m,wind_speed_10m,wind_direction_10m,surface_pressure',
        'timezone': 'Asia/Kolkata',
        'forecast_days': max(1, hours // 24 + 1)
    }

    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(settings.OPEN_METEO_WEATHER_URL, params=params, timeout=aiohttp.ClientTimeout(total=10)) as resp:
                if resp.status == 200:
                    data = await resp.json()
                    hourly = data.get('hourly', {})
                    times = hourly.get('time', [])[:hours]
                    
                    forecast = []
                    for i in range(min(hours, len(times))):
                        forecast.append({
                            'time': times[i],
                            'temperature': hourly.get('temperature_2m', [None])[i] if i < len(hourly.get('temperature_2m', [])) else None,
                            'humidity': hourly.get('relative_humidity_2m', [None])[i] if i < len(hourly.get('relative_humidity_2m', [])) else None,
                            'dew_point': hourly.get('dew_point_2m', [None])[i] if i < len(hourly.get('dew_point_2m', [])) else None,
                            'wind_speed': hourly.get('wind_speed_10m', [None])[i] if i < len(hourly.get('wind_speed_10m', [])) else None,
                            'wind_direction': hourly.get('wind_direction_10m', [None])[i] if i < len(hourly.get('wind_direction_10m', [])) else None,
                            'pressure': hourly.get('surface_pressure', [None])[i] if i < len(hourly.get('surface_pressure', [])) else None,
                        })
                    
                    return {'forecast': forecast}
    except Exception as e:
        print(f"Open-Meteo forecast API error: {e}")

    return None
