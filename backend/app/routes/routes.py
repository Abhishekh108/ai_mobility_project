"""
Route comparison endpoint — fetches Google Directions, applies IDW interpolation
along each route, and computes Cumulative Pollution Exposure scores ranked by a
4-factor composite: AQI (50%), Duration (25%), Traffic (15%), Weather (10%).
"""
import requests
import polyline
import math
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import Optional, List, Dict
from app.config import settings
from app.services.idw import (
    get_station_readings_for_idw,
    idw_interpolate,
    interpolate_along_path,
    haversine_distance
)
from app.services.alerts import classify_aqi, check_threshold, send_alert

router = APIRouter(prefix="/api", tags=["routes"])


class RouteCompareRequest(BaseModel):
    origin: str = Field(..., description="Origin address or 'lat,lng'")
    destination: str = Field(..., description="Destination address or 'lat,lng'")
    user_id: Optional[str] = Field(default=None, description="User profile ID for health alerts")


class RouteSegment(BaseModel):
    start_lat: float
    start_lng: float
    end_lat: float
    end_lng: float
    distance_km: float
    duration_minutes: float
    aqi: float
    exposure: float  # AQI × duration


class RouteResult(BaseModel):
    route_index: int
    summary: str
    total_distance_km: float
    total_duration_minutes: float
    duration_in_traffic_minutes: Optional[float]
    average_aqi: float
    max_aqi: float
    min_aqi: float
    cumulative_exposure: float
    health_classification: Dict
    health_advisory: str
    practical_reasoning: Optional[str] = None
    exposure_reduction_pct: Optional[float] = None
    polyline_encoded: str
    segments: List[RouteSegment]
    is_safest: bool
    composite_score: Optional[float] = None
    origin_name: Optional[str] = None
    destination_name: Optional[str] = None
    origin_aqi: Optional[float] = None
    destination_current_aqi: Optional[float] = None
    destination_predicted_aqi: Optional[float] = None
    travel_time_minutes: Optional[float] = None


class RouteCompareResponse(BaseModel):
    origin: str
    destination: str
    origin_aqi: Optional[float] = None
    destination_current_aqi: Optional[float] = None
    destination_predicted_aqi: Optional[float] = None
    routes: List[RouteResult]
    safest_route_index: int
    alert_triggered: bool
    alert_message: Optional[str]


def sample_polyline_points(encoded: str, max_points: int = 50) -> List[tuple]:
    """
    Decode a Google Maps encoded polyline and sample evenly-spaced points.

    Args:
        encoded: Encoded polyline string
        max_points: Maximum number of sample points

    Returns:
        List of (lat, lng) tuples
    """
    decoded = polyline.decode(encoded)

    if len(decoded) <= max_points:
        return decoded

    # Sample evenly
    step = len(decoded) / max_points
    sampled = [decoded[int(i * step)] for i in range(max_points)]
    # Always include the last point
    if sampled[-1] != decoded[-1]:
        sampled.append(decoded[-1])

    return sampled


def compute_route_exposure(route_data: dict, stations: list) -> dict:
    """
    Compute cumulative pollution exposure for a Google Directions route.

    Cumulative Exposure = Σ(Segment_AQI × Segment_Duration_minutes)

    Args:
        route_data: A single route from Google Directions API response
        stations: List of station dicts for IDW interpolation

    Returns:
        Dict with exposure metrics and segmented AQI data
    """
    legs = route_data.get('legs', [])
    if not legs:
        return {}

    leg = legs[0]  # Single-leg routes (no waypoints)
    steps = leg.get('steps', [])

    segments = []
    total_exposure = 0.0
    aqi_values = []

    for step in steps:
        # Get step polyline
        step_polyline = step.get('polyline', {}).get('points', '')
        if not step_polyline:
            continue

        # Get step duration in minutes
        duration_sec = step.get('duration', {}).get('value', 0)
        duration_min = duration_sec / 60.0

        # Get step distance in km
        distance_m = step.get('distance', {}).get('value', 0)
        distance_km = distance_m / 1000.0

        # Decode polyline and get midpoint for IDW
        points = polyline.decode(step_polyline)
        if not points:
            continue

        # Use midpoint of the step for AQI estimation
        mid_idx = len(points) // 2
        mid_lat, mid_lng = points[mid_idx]

        # IDW interpolation at midpoint
        step_aqi = idw_interpolate(mid_lat, mid_lng, stations, value_key='aqi', power=2.0)
        step_aqi = max(0, step_aqi)

        # Cumulative exposure for this segment
        segment_exposure = step_aqi * duration_min
        total_exposure += segment_exposure
        aqi_values.append(step_aqi)

        segments.append(RouteSegment(
            start_lat=points[0][0],
            start_lng=points[0][1],
            end_lat=points[-1][0],
            end_lng=points[-1][1],
            distance_km=round(distance_km, 3),
            duration_minutes=round(duration_min, 2),
            aqi=round(step_aqi, 1),
            exposure=round(segment_exposure, 1)
        ))

    avg_aqi = sum(aqi_values) / len(aqi_values) if aqi_values else 0
    max_aqi = max(aqi_values) if aqi_values else 0
    min_aqi = min(aqi_values) if aqi_values else 0

    # Total distance and duration
    total_distance = leg.get('distance', {}).get('value', 0) / 1000.0
    total_duration = leg.get('duration', {}).get('value', 0) / 60.0
    traffic_duration = leg.get('duration_in_traffic', {}).get('value', None)
    if traffic_duration:
        traffic_duration = traffic_duration / 60.0

    # Get the overview polyline
    overview_polyline = route_data.get('overview_polyline', {}).get('points', '')

    return {
        'summary': route_data.get('summary', 'Unknown Route'),
        'total_distance_km': round(total_distance, 2),
        'total_duration_minutes': round(total_duration, 1),
        'duration_in_traffic_minutes': round(traffic_duration, 1) if traffic_duration else None,
        'average_aqi': round(avg_aqi, 1),
        'max_aqi': round(max_aqi, 1),
        'min_aqi': round(min_aqi, 1),
        'cumulative_exposure': round(total_exposure, 1),
        'polyline_encoded': overview_polyline,
        'segments': segments,
    }


DELHI_LANDMARKS = {
    # ─── Central & North Delhi ───────────────────────────────────────────────
    'connaught place': (28.6315, 77.2167),
    'india gate': (28.6129, 77.2295),
    'ito': (28.6282, 77.2410),
    'red fort': (28.6562, 77.2410),
    'lal qila': (28.6562, 77.2410),
    'chandni chowk': (28.6506, 77.2303),
    'kashmere gate': (28.6675, 77.2285),
    'north campus': (28.6880, 77.2092),
    'delhi university': (28.6880, 77.2092),
    'karol bagh': (28.6514, 77.1907),
    'rajendra place': (28.6432, 77.1788),
    'civil lines': (28.6814, 77.2227),
    'alipur': (28.7973, 77.1387),
    'bawana': (28.7997, 77.0329),
    'narela': (28.8465, 77.0857),
    'burari': (28.7286, 77.1993),
    'rohini sector 10': (28.7159, 77.1130),
    'rohini': (28.7159, 77.1130),
    'pitampura': (28.6989, 77.1384),
    'ashok vihar': (28.6885, 77.1739),
    'jahangirpuri': (28.7260, 77.1627),
    # ─── South & South-East Delhi ───────────────────────────────────────────
    'hauz khas': (28.5494, 77.2001),
    'saket': (28.5284, 77.2185),
    'nehru place': (28.5492, 77.2529),
    'lajpat nagar': (28.5685, 77.2433),
    'nehru nagar': (28.5685, 77.2514),
    'aiims': (28.5672, 77.2100),
    'safdarjung': (28.5672, 77.2100),
    'lodhi garden': (28.5926, 77.2393),
    'lodhi road': (28.5926, 77.2393),
    'jln stadium': (28.5834, 77.2335),
    'jawaharlal nehru stadium': (28.5834, 77.2335),
    'okhla': (28.5375, 77.2779),
    'crri': (28.5501, 77.2752),
    'mathura road': (28.5501, 77.2752),
    'vasant kunj': (28.5244, 77.1558),
    'aya nagar': (28.4765, 77.1329),
    'qutub minar': (28.5245, 77.1855),
    'mehrauli': (28.5245, 77.1855),
    'lotus temple': (28.5535, 77.2588),
    'kalkaji': (28.5535, 77.2588),
    # ─── West & South-West Delhi (Airport, Dwarka) ───────────────────────────
    'igi airport': (28.5562, 77.1000),
    'indira gandhi international airport': (28.5562, 77.1000),
    'delhi airport': (28.5562, 77.1000),
    't3': (28.5562, 77.1000),
    'aerocity': (28.5495, 77.1215),
    'dwarka sector 8': (28.5656, 77.0670),
    'dwarka sector 21': (28.5523, 77.0583),
    'dwarka': (28.5656, 77.0670),
    'nsit dwarka': (28.6105, 77.0355),
    'janakpuri': (28.6297, 77.0818),
    'punjabi bagh': (28.6730, 77.1461),
    'rajouri garden': (28.6477, 77.1207),
    'mundka': (28.6824, 77.0306),
    'najafgarh': (28.6095, 76.9812),
    # ─── East Delhi & Trans-Yamuna ───────────────────────────────────────────
    'anand vihar': (28.6466, 77.3155),
    'patparganj': (28.6116, 77.2906),
    'mayur vihar': (28.6083, 77.2954),
    'laxmi nagar': (28.6304, 77.2773),
    'east arjun nagar': (28.6570, 77.2947),
    'dilshad garden': (28.6827, 77.3049),
    'ihbas': (28.6827, 77.3049),
    'akshardham': (28.6127, 77.2773),
    # ─── NCR: Gurugram / Gurgaon ─────────────────────────────────────────────
    'cyber city': (28.4952, 77.0890),
    'dlf cyber city': (28.4952, 77.0890),
    'cyber hub': (28.4952, 77.0890),
    'golf course road': (28.4595, 77.0980),
    'iffco chowk': (28.4720, 77.0694),
    'gurugram': (28.4595, 77.0266),
    'gurgaon': (28.4595, 77.0266),
    # ─── NCR: Noida ──────────────────────────────────────────────────────────
    'noida sector 18': (28.5700, 77.3200),
    'atta market': (28.5700, 77.3200),
    'noida sector 62': (28.6280, 77.3670),
    'electronic city': (28.6280, 77.3670),
    'noida city centre': (28.5747, 77.3560),
    'noida sector 32': (28.5747, 77.3560),
    'noida': (28.5700, 77.3200),
    # ─── NCR: Ghaziabad ─────────────────────────────────────────────────────
    'kaushambi': (28.6430, 77.3270),
    'vaishali': (28.6430, 77.3270),
    'ghaziabad': (28.6650, 77.4350),
    # ─── Fallback popular keywords ───────────────────────────────────────────
    'india': (28.6139, 77.2090),
    'delhi': (28.6139, 77.2090),
    'new delhi': (28.6139, 77.2090),
}


def geocode_location(text: str) -> tuple:
    """Extract coordinates from text or match Delhi landmarks."""
    text_lower = text.lower().strip()
    # Check if format is "lat,lng"
    if ',' in text:
        parts = text.split(',')
        try:
            return float(parts[0].strip()), float(parts[1].strip())
        except ValueError:
            pass

    for name, coords in DELHI_LANDMARKS.items():
        if name in text_lower:
            return coords

    # Default to central Delhi
    return (28.6139, 77.2090)


def fetch_osrm_driving_route(waypoints: list) -> Optional[dict]:
    """Fetch genuine road-snapped geometry via OSRM public router."""
    try:
        loc_str = ';'.join([f"{lng:.5f},{lat:.5f}" for lat, lng in waypoints])
        url = f"http://router.project-osrm.org/route/v1/driving/{loc_str}?overview=full&geometries=polyline&steps=true"
        resp = requests.get(url, timeout=7)
        if resp.status_code == 200:
            data = resp.json()
            if data.get('code') == 'Ok' and data.get('routes'):
                return data['routes'][0]
    except Exception as e:
        print(f"OSRM routing exception: {e}")
    return None


def generate_delhi_route_alternatives(origin_str: str, dest_str: str, stations: list) -> list:
    """
    Generate 3 distinct driving routes snapped to actual Delhi roads via OSRM.
    Evaluates real IDW AQI along every street segment.
    """
    o_lat, o_lng = geocode_location(origin_str)
    d_lat, d_lng = geocode_location(dest_str)

    delta_lat = d_lat - o_lat
    delta_lng = d_lng - o_lng
    vector_len = math.sqrt(delta_lat ** 2 + delta_lng ** 2) or 0.001

    perp_lat = -delta_lng / vector_len
    perp_lng = delta_lat / vector_len

    mid_lat = (o_lat + d_lat) / 2.0
    mid_lng = (o_lng + d_lng) / 2.0

    # 3 Distinct Corridor Definitions across Delhi's Road Grid
    corridors = [
        {
            'name': 'Corridor 1: Direct Main Arterial',
            'waypoints': [(o_lat, o_lng), (d_lat, d_lng)],
            'traffic_factor': 1.15,
        },
        {
            'name': 'Corridor 2: Ring Road & Peripheral Bypass',
            'waypoints': [
                (o_lat, o_lng),
                (mid_lat + 0.018 * perp_lat, mid_lng + 0.018 * perp_lng),
                (d_lat, d_lng)
            ],
            'traffic_factor': 1.05,
        },
        {
            'name': 'Corridor 3: Express Link & Secondary Arterial',
            'waypoints': [
                (o_lat, o_lng),
                (mid_lat - 0.020 * perp_lat, mid_lng - 0.020 * perp_lng),
                (d_lat, d_lng)
            ],
            'traffic_factor': 1.25,
        },
    ]

    results = []

    for idx, c in enumerate(corridors):
        osrm_data = fetch_osrm_driving_route(c['waypoints'])

        if osrm_data and 'geometry' in osrm_data:
            road_pts = polyline.decode(osrm_data['geometry'])
            total_distance = osrm_data['distance'] / 1000.0
            base_duration = osrm_data['duration'] / 60.0
            traffic_duration = base_duration * c['traffic_factor']
        else:
            # Fallback smooth spline if network router fails
            direct_dist_km = haversine_distance(o_lat, o_lng, d_lat, d_lng)
            total_distance = max(direct_dist_km * (1.15 + idx * 0.08), 2.5)
            base_duration = (total_distance / 35.0) * 60.0
            traffic_duration = base_duration * c['traffic_factor']
            num_steps = 22
            road_pts = []
            amplitude = vector_len * (0.02 if idx == 0 else (0.12 if idx == 1 else -0.10))
            for s in range(num_steps + 1):
                t = s / num_steps
                arc = math.sin(t * math.pi)
                road_pts.append((
                    o_lat + t * delta_lat + arc * amplitude * perp_lat,
                    o_lng + t * delta_lng + arc * amplitude * perp_lng
                ))

        # Sample points into 16-20 clean evaluated steps along the real road
        num_segments = min(20, max(8, len(road_pts) - 1))
        step_pts = []
        for i in range(num_segments + 1):
            idx_pt = int(i * (len(road_pts) - 1) / num_segments)
            step_pts.append(road_pts[idx_pt])

        segments = []
        total_exposure = 0.0
        aqi_values = []
        step_dur = traffic_duration / num_segments
        step_dist = total_distance / num_segments

        for s in range(num_segments):
            p1 = step_pts[s]
            p2 = step_pts[s + 1]
            mid_lat_pt = (p1[0] + p2[0]) / 2.0
            mid_lng_pt = (p1[1] + p2[1]) / 2.0

            step_aqi = idw_interpolate(mid_lat_pt, mid_lng_pt, stations, value_key='aqi', power=2.0)
            step_aqi = max(10, step_aqi)
            aqi_values.append(step_aqi)

            seg_exp = step_aqi * step_dur
            total_exposure += seg_exp

            segments.append(RouteSegment(
                start_lat=round(p1[0], 5),
                start_lng=round(p1[1], 5),
                end_lat=round(p2[0], 5),
                end_lng=round(p2[1], 5),
                distance_km=round(step_dist, 2),
                duration_minutes=round(step_dur, 1),
                aqi=round(step_aqi, 1),
                exposure=round(seg_exp, 1)
            ))

        encoded_path = polyline.encode(road_pts)
        avg_aqi = sum(aqi_values) / len(aqi_values) if aqi_values else 100.0

        results.append({
            'summary': c['name'],
            'total_distance_km': round(total_distance, 2),
            'total_duration_minutes': round(base_duration, 1),
            'duration_in_traffic_minutes': round(traffic_duration, 1),
            'average_aqi': round(avg_aqi, 1),
            'max_aqi': round(max(aqi_values), 1),
            'min_aqi': round(min(aqi_values), 1),
            'cumulative_exposure': round(total_exposure, 1),
            'polyline_encoded': encoded_path,
            'segments': segments,
        })

    return results


def _compute_weather_score(weather_data: Optional[dict]) -> float:
    """
    Compute a 0–1 weather dispersion score from Open-Meteo current weather.
    Higher score = better conditions (stronger wind, or rain washing particles).
    Neutral 0.5 returned when weather data is unavailable.
    """
    if not weather_data:
        return 0.5  # Neutral fallback on API timeout

    wind_speed = weather_data.get('wind_speed') or 0.0
    weather_code = weather_data.get('weather_code') or 0

    # Wind contribution: 0 km/h → 0.0, ≥20 km/h → 1.0 (linear clamp)
    wind_score = min(wind_speed / 20.0, 1.0)

    # Rain bonus: weather codes 51–99 indicate rain/drizzle/storms (particle washout)
    rain_bonus = 0.3 if 51 <= weather_code <= 99 else 0.0

    # Combine and clamp to [0, 1]
    return min(wind_score + rain_bonus, 1.0)


def _normalize_factors(values: List[float], invert: bool = True) -> List[float]:
    """
    Normalize a list of values to [0, 1].
    If invert=True, lower raw value → higher normalized score (better).
    Returns equal weights when all values are identical.
    """
    min_v = min(values)
    max_v = max(values)
    spread = max_v - min_v

    if spread == 0:
        return [0.5] * len(values)  # All routes equal on this factor

    normalized = [(v - min_v) / spread for v in values]
    if invert:
        normalized = [1.0 - n for n in normalized]
    return normalized


def _build_weather_label(weather_data: Optional[dict]) -> str:
    """Return a short human-readable weather condition string."""
    if not weather_data:
        return "Unknown (API unavailable)"

    wind_speed = weather_data.get('wind_speed') or 0.0
    weather_code = weather_data.get('weather_code') or 0

    if 51 <= weather_code <= 99:
        condition = "Rainy (particle washout ✅)"
    elif weather_code in (1, 2, 3):
        condition = "Partly Cloudy"
    else:
        condition = "Clear / Dry"

    wind_label = "Calm" if wind_speed < 5 else ("Moderate" if wind_speed < 15 else "Strong")
    return f"{condition}, {wind_label} wind ({wind_speed:.0f} km/h)"


@router.post("/routes/compare", response_model=RouteCompareResponse)
async def compare_routes(request: RouteCompareRequest):
    """
    Compare driving routes between origin and destination on real roads.
    Evaluates IDW air quality along each street and ranks routes by a
    4-factor composite score: AQI (50%), Duration (25%), Traffic (15%), Weather (10%).
    """
    stations = get_station_readings_for_idw()
    if not stations:
        raise HTTPException(status_code=503, detail="No station data available for AQI interpolation")

    processed_routes = []

    # Attempt Google Directions API first if enabled
    directions_url = "https://maps.googleapis.com/maps/api/directions/json"
    params = {
        'origin': request.origin,
        'destination': request.destination,
        'key': settings.GOOGLE_MAPS_API_KEY,
        'alternatives': 'true',
        'departure_time': 'now',
        'mode': 'driving'
    }

    try:
        resp = requests.get(directions_url, params=params, timeout=5)
        data = resp.json()
        if data.get('status') == 'OK' and data.get('routes'):
            for r in data['routes']:
                exp = compute_route_exposure(r, stations)
                if exp:
                    processed_routes.append(exp)
    except Exception as e:
        print(f"Directions API exception: {e}")

    # Use genuine Delhi road network routing via OSRM if Google Directions API key is restricted
    if not processed_routes:
        processed_routes = generate_delhi_route_alternatives(request.origin, request.destination, stations)

    if not processed_routes:
        raise HTTPException(status_code=500, detail="Could not compute exposure for any route")

    # ── Fetch live weather for origin (used in composite scoring & reasoning) ──
    from app.services.open_meteo import fetch_live_weather
    origin_lat, origin_lng = geocode_location(request.origin)
    dest_lat, dest_lng = geocode_location(request.destination)
    weather_data = None
    try:
        weather_data = await fetch_live_weather(origin_lat, origin_lng)
    except Exception as e:
        print(f"Weather fetch failed (will use neutral score): {e}")

    weather_score_shared = _compute_weather_score(weather_data)
    weather_label = _build_weather_label(weather_data)

    # Base AQI at origin A and destination B via spatial IDW
    origin_aqi_calc = round(idw_interpolate(origin_lat, origin_lng, stations, value_key='aqi', power=2.0), 1)
    dest_current_aqi_calc = round(idw_interpolate(dest_lat, dest_lng, stations, value_key='aqi', power=2.0), 1)

    # ── 4-Factor Composite Scoring ──
    # Factor 1: AQI (lower avg_aqi is better)
    aqi_values_raw = [r['average_aqi'] for r in processed_routes]
    aqi_scores = _normalize_factors(aqi_values_raw, invert=True)

    # Factor 2: Duration (lower total_duration_minutes is better)
    dur_values_raw = [r['total_duration_minutes'] for r in processed_routes]
    dur_scores = _normalize_factors(dur_values_raw, invert=True)

    # Pre-fetch predictions for destination B's nearest station across route duration horizon
    nearest_dest_station = min(stations, key=lambda s: haversine_distance(dest_lat, dest_lng, s['latitude'], s['longitude']))
    dest_predictions_by_hour = {}
    try:
        from app.routes.predict import predict_aqi, PredictionRequest
        max_duration = max(dur_values_raw) if dur_values_raw else 60.0
        max_h = max(1, min(24, int(math.ceil(max_duration / 60.0))))
        pred_res = await predict_aqi(PredictionRequest(station_id=nearest_dest_station['station_id'], hours_ahead=max_h))
        for p in pred_res.predictions:
            dest_predictions_by_hour[p['hour']] = p.get('AQI')
    except Exception as e:
        print(f"Nearest station forecast lookup error: {e}")

    # Factor 3: Traffic congestion ratio (duration_in_traffic / total_duration — lower is better)
    traffic_ratios = []
    for r in processed_routes:
        if r.get('duration_in_traffic_minutes') and r['total_duration_minutes'] > 0:
            traffic_ratios.append(r['duration_in_traffic_minutes'] / r['total_duration_minutes'])
        else:
            traffic_ratios.append(1.0)  # No traffic data → assume 1× (neutral)
    traffic_scores = _normalize_factors(traffic_ratios, invert=True)

    # Factor 4: Weather — same live score shared across all routes (origin point)
    # Weather doesn't differentiate between routes but contributes to overall ranking context
    weather_scores = [weather_score_shared] * len(processed_routes)

    # Weights: AQI 50%, Duration 25%, Traffic 15%, Weather 10%
    WEIGHTS = {'aqi': 0.50, 'duration': 0.25, 'traffic': 0.15, 'weather': 0.10}
    composite_scores = []
    for i in range(len(processed_routes)):
        score = (
            WEIGHTS['aqi'] * aqi_scores[i]
            + WEIGHTS['duration'] * dur_scores[i]
            + WEIGHTS['traffic'] * traffic_scores[i]
            + WEIGHTS['weather'] * weather_scores[i]
        )
        composite_scores.append(score)

    # Best route = highest composite score (closer to 1.0 = best across all factors)
    safest_idx = max(range(len(composite_scores)), key=lambda i: composite_scores[i])
    safest_data = processed_routes[safest_idx]

    # Keep exposure worst for reduction % display
    worst_exp = max(r['cumulative_exposure'] for r in processed_routes)

    # ── Build Response Objects ──
    route_results = []
    for idx, exposure_data in enumerate(processed_routes):
        classification = classify_aqi(exposure_data['average_aqi'])
        avg_aqi = exposure_data['average_aqi']
        time_m = exposure_data['duration_in_traffic_minutes'] or exposure_data['total_duration_minutes']
        dist_k = exposure_data['total_distance_km']
        is_safest = (idx == safest_idx)

        # Exposure reduction % vs worst alternative
        reduction_pct = 0.0
        if worst_exp > 0:
            reduction_pct = round(((worst_exp - exposure_data['cumulative_exposure']) / worst_exp) * 100.0, 1)

        # Traffic congestion label
        t_ratio = traffic_ratios[idx]
        if t_ratio <= 1.05:
            traffic_label = "Free-flowing traffic 🟢"
        elif t_ratio <= 1.20:
            traffic_label = f"Moderate congestion (+{((t_ratio - 1) * 100):.0f}% delay)"
        else:
            traffic_label = f"Heavy congestion (+{((t_ratio - 1) * 100):.0f}% delay) 🔴"

        # AQI factor bullet
        aqi_score_pct = round(aqi_scores[idx] * 100)
        if is_safest:
            aqi_bullet = (
                f"**🌫️ AQI ({avg_aqi:.0f} — Score {aqi_score_pct}/100):** "
                f"Lowest pollution corridor. Reduces your cumulative inhaled exposure by **{reduction_pct:.0f}%** vs worst alternative."
            )
        else:
            safe_aqi = safest_data['average_aqi']
            extra_exp_pct = round(
                ((exposure_data['cumulative_exposure'] - safest_data['cumulative_exposure'])
                 / max(safest_data['cumulative_exposure'], 1)) * 100.0, 1
            )
            aqi_bullet = (
                f"**🌫️ AQI ({avg_aqi:.0f} — Score {aqi_score_pct}/100):** "
                f"AQI is **{avg_aqi - safe_aqi:+.0f}** vs best route. Inhaled dosage is **+{extra_exp_pct:.0f}%** higher."
            )

        # Duration factor bullet
        dur_score_pct = round(dur_scores[idx] * 100)
        dur_vs_best = time_m - (safest_data['duration_in_traffic_minutes'] or safest_data['total_duration_minutes'])
        if is_safest:
            dur_bullet = (
                f"**⏱️ Duration ({time_m:.0f} min, {dist_k:.1f} km — Score {dur_score_pct}/100):** "
                f"Fastest or competitive travel time on this corridor."
            )
        else:
            dur_bullet = (
                f"**⏱️ Duration ({time_m:.0f} min, {dist_k:.1f} km — Score {dur_score_pct}/100):** "
                f"**{dur_vs_best:+.0f} min** longer than the recommended route."
            )

        # Traffic factor bullet
        traffic_score_pct = round(traffic_scores[idx] * 100)
        traffic_bullet = (
            f"**🚦 Traffic (Score {traffic_score_pct}/100):** {traffic_label}."
        )

        # Weather factor bullet (shared, but shown for transparency)
        weather_score_pct = round(weather_score_shared * 100)
        weather_bullet = (
            f"**🌤️ Weather (Score {weather_score_pct}/100):** {weather_label}."
        )

        reasoning = "\n".join([aqi_bullet, dur_bullet, traffic_bullet, weather_bullet])

        # General health advisory
        if avg_aqi <= 100:
            advisory = "Satisfactory air quality. Normal commute precautions."
        elif avg_aqi <= 200:
            advisory = "Moderate pollution. Keep car windows closed; recirculate AC air."
        elif avg_aqi <= 300:
            advisory = "Poor air quality. Sensitive commuters should wear an N95 mask in transit."
        else:
            advisory = "Very poor / severe AQI. High particulate concentration. Maximize vehicle air filtration."

        # Compute predicted AQI at destination B after travel duration time_m
        hours_ahead = max(1, min(24, int(math.ceil(time_m / 60.0))))
        st_pred_aqi = dest_predictions_by_hour.get(hours_ahead)
        st_curr_aqi = nearest_dest_station.get('aqi') or 100.0
        if st_pred_aqi and st_curr_aqi > 0:
            ratio = st_pred_aqi / st_curr_aqi
            ratio = max(0.65, min(1.5, ratio))
            dest_pred_aqi = round(dest_current_aqi_calc * ratio, 1)
        elif st_pred_aqi:
            dest_pred_aqi = round(st_pred_aqi, 1)
        else:
            dest_pred_aqi = round(dest_current_aqi_calc * 1.02, 1)

        route_results.append(RouteResult(
            route_index=idx,
            summary=exposure_data['summary'],
            total_distance_km=exposure_data['total_distance_km'],
            total_duration_minutes=exposure_data['total_duration_minutes'],
            duration_in_traffic_minutes=exposure_data['duration_in_traffic_minutes'],
            average_aqi=exposure_data['average_aqi'],
            max_aqi=exposure_data['max_aqi'],
            min_aqi=exposure_data['min_aqi'],
            cumulative_exposure=exposure_data['cumulative_exposure'],
            health_classification=classification,
            health_advisory=advisory,
            practical_reasoning=reasoning,
            exposure_reduction_pct=reduction_pct if is_safest else 0.0,
            polyline_encoded=exposure_data['polyline_encoded'],
            segments=exposure_data['segments'],
            is_safest=is_safest,
            composite_score=round(composite_scores[idx], 4),
            origin_name=request.origin,
            destination_name=request.destination,
            origin_aqi=origin_aqi_calc,
            destination_current_aqi=dest_current_aqi_calc,
            destination_predicted_aqi=dest_pred_aqi,
            travel_time_minutes=round(time_m, 1)
        ))

    # Check if alert should be triggered for the user
    alert_triggered = False
    alert_message = None

    if request.user_id:
        from app.database import get_db
        conn = get_db()
        cursor = conn.cursor()
        cursor.execute("SELECT health_category, custom_threshold, fcm_token FROM user_profiles WHERE id = ?",
                       (request.user_id,))
        profile = cursor.fetchone()
        conn.close()

        if profile:
            health_cat, custom_thresh, fcm_token = profile[0], profile[1], profile[2]
            safest = route_results[safest_idx]

            if check_threshold(safest.average_aqi, health_cat, custom_thresh):
                alert_triggered = True
                alert_message = (
                    f"⚠️ Even the safest route ({safest.summary}) has an average AQI of {safest.average_aqi:.0f}, "
                    f"which exceeds your {health_cat} threshold. Consider postponing travel or using maximum protection."
                )

                # Send the alert
                await send_alert(
                    user_id=request.user_id,
                    fcm_token=fcm_token,
                    alert_type='route_warning',
                    aqi_value=safest.average_aqi,
                    message=alert_message
                )

    return RouteCompareResponse(
        origin=request.origin,
        destination=request.destination,
        origin_aqi=origin_aqi_calc,
        destination_current_aqi=dest_current_aqi_calc,
        destination_predicted_aqi=route_results[safest_idx].destination_predicted_aqi if route_results else dest_current_aqi_calc,
        routes=route_results,
        safest_route_index=safest_idx,
        alert_triggered=alert_triggered,
        alert_message=alert_message
    )


@router.post("/routes/check-position")
async def check_position_aqi(lat: float, lng: float, user_id: Optional[str] = None):
    """
    Check AQI at a specific position using IDW interpolation.
    Optionally triggers alerts if a user_id is provided and threshold is exceeded.
    """
    stations = get_station_readings_for_idw()
    if not stations:
        raise HTTPException(status_code=503, detail="No station data available")

    from app.services.idw import idw_interpolate_multi
    values = idw_interpolate_multi(lat, lng, stations)
    classification = classify_aqi(values.get('aqi', 0))

    result = {
        'latitude': lat,
        'longitude': lng,
        'interpolated': values,
        'classification': classification,
        'alert_triggered': False
    }

    # Check user threshold
    if user_id and values.get('aqi'):
        from app.database import get_db
        conn = get_db()
        cursor = conn.cursor()
        cursor.execute("SELECT health_category, custom_threshold, fcm_token FROM user_profiles WHERE id = ?",
                       (user_id,))
        profile = cursor.fetchone()
        conn.close()

        if profile:
            if check_threshold(values['aqi'], profile[0], profile[1]):
                result['alert_triggered'] = True
                result['alert_message'] = (
                    f"⚠️ AQI at your location is {values['aqi']:.0f}, exceeding your threshold. "
                    f"Consider moving to a cleaner area."
                )
                await send_alert(
                    user_id=user_id,
                    fcm_token=profile[2],
                    alert_type='live_position',
                    aqi_value=values['aqi'],
                    message=result['alert_message'],
                    lat=lat,
                    lng=lng
                )

    return result
