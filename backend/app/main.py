"""
FastAPI Application Entry Point
AI-Powered Environmental Intelligence System
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.config import settings
from app.database import init_db, seed_stations
from app.routes import predict, stations, profiles, routes
from app.services.alerts import init_firebase


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application startup and shutdown events."""
    # Startup
    print("=" * 60)
    print(f"  {settings.PROJECT_NAME}")
    print(f"  API Version: {settings.API_VERSION}")
    print("=" * 60)

    # Initialize database
    print("\n[1/3] Initializing database...")
    init_db()

    # Seed station data
    print("[2/3] Seeding station data...")
    seed_stations(settings.DATA_PATH)

    # Initialize Firebase (optional)
    print("[3/3] Initializing Firebase...")
    init_firebase()

    print("\n[OK] Server ready!\n")
    
    yield
    
    # Shutdown
    print("Server shutting down...")


# Create FastAPI app
app = FastAPI(
    title=settings.PROJECT_NAME,
    description="AI-powered air quality prediction and smart mobility recommendations for Delhi",
    version=settings.API_VERSION,
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routers
app.include_router(predict.router)
app.include_router(stations.router)
app.include_router(profiles.router)
app.include_router(routes.router)


@app.get("/")
async def root():
    """Health check endpoint."""
    return {
        "service": settings.PROJECT_NAME,
        "version": settings.API_VERSION,
        "status": "running",
        "endpoints": {
            "stations": "/api/stations",
            "predict": "/api/predict",
            "profiles": "/api/profiles",
            "routes": "/api/routes/compare",
            "docs": "/docs"
        }
    }


@app.get("/api/health")
async def health_check():
    """Detailed health check."""
    import os

    model_exists = os.path.exists(settings.MODEL_WEIGHTS_PATH)
    scaler_exists = os.path.exists(settings.SCALER_PATH)

    return {
        "status": "healthy",
        "model_loaded": model_exists,
        "scaler_loaded": scaler_exists,
        "google_maps_configured": bool(settings.GOOGLE_MAPS_API_KEY),
        "firebase_configured": bool(settings.FIREBASE_CREDENTIALS_PATH),
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
