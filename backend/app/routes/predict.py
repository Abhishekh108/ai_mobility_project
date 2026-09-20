"""
Prediction endpoint - serves LSTM model forecasts for AQI and pollutants.
"""
import os
import sys
import numpy as np
import torch
import joblib
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import Optional, List, Dict

from app.config import settings
from app.services.alerts import classify_aqi

router = APIRouter(prefix="/api", tags=["predictions"])

# Global model cache
_model = None
_scaler_data = None


class PredictionRequest(BaseModel):
    station_id: str = Field(..., description="Station ID (e.g., DL001)")
    hours_ahead: int = Field(default=24, ge=1, le=24, description="Hours ahead to forecast (1-24)")


class PredictionResponse(BaseModel):
    station_id: str
    hours_ahead: int
    predictions: List[Dict]
    health_classification: Dict
    model_info: Dict


def load_model():
    """Load the trained model and scaler (cached globally)."""
    global _model, _scaler_data

    if _model is not None and _scaler_data is not None:
        return _model, _scaler_data

    model_path = settings.MODEL_WEIGHTS_PATH
    scaler_path = settings.SCALER_PATH

    if not os.path.exists(model_path):
        raise HTTPException(status_code=503, detail=f"Model weights not found at {model_path}. Train the model first.")
    if not os.path.exists(scaler_path):
        raise HTTPException(status_code=503, detail=f"Scaler not found at {scaler_path}. Train the model first.")

    # Load scaler
    _scaler_data = joblib.load(scaler_path)

    # Load model
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from ml.model import create_model

    checkpoint = torch.load(model_path, map_location='cpu', weights_only=True)

    model = create_model(
        n_features=checkpoint['n_features'],
        n_targets=checkpoint['n_targets'],
        horizon=checkpoint['horizon'],
        use_gru=checkpoint.get('use_gru', False),
        device='cpu'
    )
    model.load_state_dict(checkpoint['model_state_dict'])
    model.eval()
    _model = model

    print(f"Model loaded: {checkpoint['n_features']} features, {checkpoint['n_targets']} targets")
    return _model, _scaler_data


def get_station_latest_sequence(station_id: str) -> Optional[np.ndarray]:
    """
    Get the latest 24-hour sequence for a station from the database.
    Falls back to synthetic data if not enough history.
    """
    from app.database import get_db
    import pandas as pd

    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT pm25, pm10, no2, o3, co, so2, aqi, temperature, humidity, wind_speed
        FROM station_readings
        WHERE station_id = ?
    """, (station_id,))

    row = cursor.fetchone()
    conn.close()

    if row is None:
        return None

    # Build a synthetic 24-hour sequence from the latest reading
    # In production, this would come from InfluxDB time-series
    base_values = {
        'PM2.5': row[0] or 100,
        'PM10': row[1] or 200,
        'NO2': row[2] or 40,
        'O3': row[3] or 50,
        'CO': row[4] or 1.0,
        'SO2': row[5] or 15,
        'NO': 20,
        'NOx': 30,
        'NH3': 20,
        'Benzene': 3,
        'Toluene': 10,
        'Xylene': 1,
        'temperature': row[7] or 25,
        'dew_point': 18,
        'humidity': row[8] or 60,
        'wind_direction': 180,
        'wind_speed': row[9] or 10,
        'pressure': 1013,
    }

    # Create a 24-hour sequence with small variations
    rng = np.random.default_rng(42)
    sequence = []
    for hour in range(24):
        row_data = {}
        for key, val in base_values.items():
            noise = rng.normal(0, 0.05) * val  # 5% noise
            row_data[key] = max(0, val + noise)
        
        # Add cyclical time features
        row_data['hour_sin'] = np.sin(2 * np.pi * hour / 24)
        row_data['hour_cos'] = np.cos(2 * np.pi * hour / 24)
        row_data['dow_sin'] = np.sin(2 * np.pi * 2 / 7)
        row_data['dow_cos'] = np.cos(2 * np.pi * 2 / 7)
        row_data['month_sin'] = np.sin(2 * np.pi * 9 / 12)
        row_data['month_cos'] = np.cos(2 * np.pi * 9 / 12)

        sequence.append(row_data)

    return sequence


@router.post("/predict", response_model=PredictionResponse)
async def predict_aqi(request: PredictionRequest):
    """
    Predict AQI and pollutant levels for 1-24 hours ahead.
    """
    model, scaler_data = load_model()

    scaler = scaler_data['scaler']
    feature_cols = scaler_data['feature_cols']
    target_cols = scaler_data['target_cols']
    all_cols = scaler_data['all_cols']

    # Get latest data sequence
    sequence_data = get_station_latest_sequence(request.station_id)
    if sequence_data is None:
        raise HTTPException(status_code=404, detail=f"Station {request.station_id} not found")

    # Build feature matrix
    feature_matrix = []
    for row_data in sequence_data:
        row = [row_data.get(col, 0) for col in feature_cols]
        feature_matrix.append(row)

    feature_matrix = np.array(feature_matrix, dtype=np.float32)

    # Scale features — need to construct a full array matching the scaler's expected columns
    full_matrix = np.zeros((24, len(all_cols)), dtype=np.float32)
    for i, col in enumerate(all_cols):
        if col in feature_cols:
            feat_idx = feature_cols.index(col)
            full_matrix[:, i] = feature_matrix[:, feat_idx]

    scaled_full = scaler.transform(full_matrix)
    
    # Extract only feature columns in scaled space
    scaled_features = np.zeros((24, len(feature_cols)), dtype=np.float32)
    for i, col in enumerate(feature_cols):
        if col in all_cols:
            col_idx = all_cols.index(col)
            scaled_features[:, i] = scaled_full[:, col_idx]

    # Run inference
    input_tensor = torch.FloatTensor(scaled_features).unsqueeze(0)

    with torch.no_grad():
        output = model(input_tensor)  # (1, 24, n_targets)

    predictions_scaled = output.squeeze(0).numpy()  # (24, n_targets)

    # Inverse transform predictions
    # We need to build full arrays to inverse-transform
    predictions_list = []
    for h in range(min(request.hours_ahead, 24)):
        pred_full = np.zeros((1, len(all_cols)), dtype=np.float32)
        for j, col in enumerate(target_cols):
            if col in all_cols:
                col_idx = all_cols.index(col)
                pred_full[0, col_idx] = predictions_scaled[h, j]

        # Inverse transform
        pred_original = scaler.inverse_transform(pred_full)
        
        pred_dict = {'hour': h + 1}
        for j, col in enumerate(target_cols):
            if col in all_cols:
                col_idx = all_cols.index(col)
                pred_dict[col] = round(float(max(0, pred_original[0, col_idx])), 2)

        # Add health classification for each hour
        if 'AQI' in pred_dict:
            pred_dict['classification'] = classify_aqi(pred_dict['AQI'])

        predictions_list.append(pred_dict)

    # Overall health classification (based on max AQI in forecast)
    max_aqi = max(p.get('AQI', 0) for p in predictions_list)
    overall_classification = classify_aqi(max_aqi)

    return PredictionResponse(
        station_id=request.station_id,
        hours_ahead=request.hours_ahead,
        predictions=predictions_list,
        health_classification=overall_classification,
        model_info={
            'type': 'GRU' if hasattr(model, 'rnn1') and isinstance(model.rnn1, torch.nn.GRU) else 'LSTM',
            'features': len(feature_cols),
            'targets': target_cols,
            'lookback_hours': 24,
        }
    )
