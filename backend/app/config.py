import os
from dotenv import load_dotenv

load_dotenv()

class Settings:
    PROJECT_NAME: str = "AQI Intelligence System"
    API_VERSION: str = "v1"
    
    # Google Maps
    GOOGLE_MAPS_API_KEY: str = os.getenv("GOOGLE_MAPS_API_KEY", "")
    
    # Database
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./aqi_system.db")
    
    # Open-Meteo (free, no key needed)
    OPEN_METEO_AQ_URL: str = "https://air-quality-api.open-meteo.com/v1/air-quality"
    OPEN_METEO_WEATHER_URL: str = "https://api.open-meteo.com/v1/forecast"
    
    # Model paths
    MODEL_WEIGHTS_PATH: str = os.path.join(os.path.dirname(os.path.dirname(__file__)), "ml", "weights", "aqi_lstm.pt")
    SCALER_PATH: str = os.path.join(os.path.dirname(os.path.dirname(__file__)), "ml", "weights", "scaler.pkl")
    
    # Data path
    DATA_PATH: str = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "merged_delhi_air_quality_weather.csv")
    
    # Firebase (optional)
    FIREBASE_CREDENTIALS_PATH: str = os.getenv("FIREBASE_CREDENTIALS_PATH", "")
    
    # CORS
    CORS_ORIGINS: list = ["http://localhost:5173", "http://localhost:3000", "http://127.0.0.1:5173"]
    
    # AQI Health Thresholds per category
    HEALTH_THRESHOLDS: dict = {
        "normal": 300,
        "asthmatic": 150,
        "elderly": 200,
        "children": 150,
    }
    
    # AQI Classification
    AQI_CATEGORIES: list = [
        {"min": 0, "max": 50, "label": "Good", "color": "#009966", "advice": "Air quality is satisfactory. No health risk."},
        {"min": 51, "max": 100, "label": "Satisfactory", "color": "#FFDE33", "advice": "Acceptable quality. Sensitive individuals should limit prolonged outdoor exertion."},
        {"min": 101, "max": 200, "label": "Moderate", "color": "#FF9933", "advice": "May cause breathing discomfort to people with lung/heart disease, children & older adults."},
        {"min": 201, "max": 300, "label": "Poor", "color": "#CC0033", "advice": "May cause breathing discomfort to most people on prolonged exposure."},
        {"min": 301, "max": 400, "label": "Very Poor", "color": "#660099", "advice": "May cause respiratory illness to people on prolonged exposure."},
        {"min": 401, "max": 500, "label": "Severe", "color": "#7E0023", "advice": "May cause severe health impacts. Avoid all outdoor activity."},
    ]

settings = Settings()
