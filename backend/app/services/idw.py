"""
Inverse Distance Weighting (IDW) spatial interpolation service.
Estimates AQI at arbitrary coordinates using known station readings.

Formula: AQI(x) = Σ(AQI_i / d_i^p) / Σ(1 / d_i^p)
where d_i is the distance from point x to station i, and p is the power parameter.
"""
import math
from typing import List, Dict, Optional, Tuple
import sqlite3
import os

# Earth radius in km for Haversine calculation
EARTH_RADIUS_KM = 6371.0


def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Calculate the great-circle distance between two points on Earth.
    
    Returns:
        Distance in kilometers
    """
    lat1_r, lat2_r = math.radians(lat1), math.radians(lat2)
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)

    a = (math.sin(dlat / 2) ** 2 +
         math.cos(lat1_r) * math.cos(lat2_r) * math.sin(dlon / 2) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

    return EARTH_RADIUS_KM * c


def idw_interpolate(target_lat: float, target_lng: float,
                    stations: List[Dict], value_key: str = 'aqi',
                    power: float = 2.0, min_distance: float = 0.01) -> float:
    """
    Perform IDW interpolation for a single target point.
    
    Args:
        target_lat: Latitude of the point to estimate
        target_lng: Longitude of the point to estimate
        stations: List of station dicts with keys: latitude, longitude, and the value_key
        value_key: Key in station dict containing the value to interpolate (default 'aqi')
        power: Distance weighting power (default 2.0)
        min_distance: Minimum distance in km to avoid division by near-zero (default 0.01)
    
    Returns:
        Interpolated value at the target point
    """
    if not stations:
        return 0.0

    numerator = 0.0
    denominator = 0.0

    for station in stations:
        value = station.get(value_key)
        if value is None or math.isnan(value):
            continue

        dist = haversine_distance(target_lat, target_lng,
                                  station['latitude'], station['longitude'])

        # If the target point is essentially at a station, return that station's value
        if dist < min_distance:
            return float(value)

        weight = 1.0 / (dist ** power)
        numerator += weight * value
        denominator += weight

    if denominator == 0:
        return 0.0

    return numerator / denominator


def idw_interpolate_multi(target_lat: float, target_lng: float,
                          stations: List[Dict],
                          value_keys: List[str] = None,
                          power: float = 2.0) -> Dict[str, float]:
    """
    Perform IDW interpolation for multiple pollutant values at once.
    
    Args:
        target_lat: Target latitude
        target_lng: Target longitude
        stations: List of station dicts
        value_keys: List of pollutant keys to interpolate
        power: IDW power parameter
    
    Returns:
        Dict mapping each value_key to its interpolated value
    """
    if value_keys is None:
        value_keys = ['aqi', 'pm25', 'pm10', 'no2', 'o3', 'co', 'so2']

    result = {}
    for key in value_keys:
        result[key] = idw_interpolate(target_lat, target_lng, stations, value_key=key, power=power)

    return result


def interpolate_along_path(path_points: List[Tuple[float, float]],
                           stations: List[Dict],
                           power: float = 2.0) -> List[Dict]:
    """
    Estimate AQI along a sequence of path coordinates.
    
    Args:
        path_points: List of (lat, lng) tuples along the route
        stations: List of station dicts with readings
        power: IDW power parameter
    
    Returns:
        List of dicts with lat, lng, and interpolated pollutant values
    """
    results = []
    for lat, lng in path_points:
        values = idw_interpolate_multi(lat, lng, stations, power=power)
        values['latitude'] = lat
        values['longitude'] = lng
        results.append(values)

    return results


def get_station_readings_for_idw() -> List[Dict]:
    """
    Fetch current station readings from the database for IDW calculation.
    
    Returns:
        List of station dicts with coordinates and latest readings
    """
    from app.database import get_db

    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT station_id, station_name, latitude, longitude,
               pm25, pm10, no2, o3, co, so2, aqi
        FROM station_readings
        WHERE aqi IS NOT NULL
    """)
    
    stations = []
    for row in cursor.fetchall():
        stations.append({
            'station_id': row[0],
            'station_name': row[1],
            'latitude': row[2],
            'longitude': row[3],
            'pm25': row[4],
            'pm10': row[5],
            'no2': row[6],
            'o3': row[7],
            'co': row[8],
            'so2': row[9],
            'aqi': row[10],
        })

    conn.close()
    return stations
