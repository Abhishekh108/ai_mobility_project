"""
Data preprocessing module for AQI prediction.
Loads the Delhi AQI + Weather CSV, cleans data, engineers features,
and creates PyTorch-ready sliding-window sequences.
"""
import os
import numpy as np
import pandas as pd
from sklearn.preprocessing import MinMaxScaler
import joblib


# Target pollutant columns we want to predict
TARGET_COLS = ['PM2.5', 'PM10', 'NO2', 'O3', 'CO', 'AQI']

# Feature columns for the model input
FEATURE_COLS = [
    'PM2.5', 'PM10', 'NO', 'NO2', 'NOx', 'NH3', 'CO', 'SO2', 'O3',
    'Benzene', 'Toluene', 'Xylene',
    'temperature', 'dew_point', 'humidity', 'wind_direction', 'wind_speed', 'pressure',
    'hour_sin', 'hour_cos', 'dow_sin', 'dow_cos', 'month_sin', 'month_cos'
]

# Representative stations for training (good spatial coverage across Delhi)
REPRESENTATIVE_STATIONS = ['DL001', 'DL002', 'DL010', 'DL014', 'DL026']
# DL001 = Alipur (North), DL002 = Anand Vihar (East), DL010 = Dwarka (West)
# DL014 = ITO (Central), DL026 = Okhla (South)


def load_and_clean(data_path: str, use_all_stations: bool = False) -> pd.DataFrame:
    """Load CSV and perform initial cleaning."""
    print(f"Loading data from {data_path}...")
    df = pd.read_csv(data_path)
    df.columns = df.columns.str.strip()

    # Filter to representative stations unless using all
    if not use_all_stations:
        df = df[df['StationId'].isin(REPRESENTATIVE_STATIONS)].copy()
        print(f"Filtered to {len(REPRESENTATIVE_STATIONS)} stations: {df['StationId'].nunique()} unique")

    # Parse datetime
    df['Datetime'] = pd.to_datetime(df['Datetime'], format='%d-%m-%Y %H:%M', errors='coerce')
    df = df.dropna(subset=['Datetime'])
    df = df.sort_values(['StationId', 'Datetime']).reset_index(drop=True)

    # Rename weather columns for cleanliness
    rename_map = {}
    for col in df.columns:
        if 'temp' in col.lower() and '°' in col or 'temp' in col.lower():
            rename_map[col] = 'temperature'
        elif 'dew' in col.lower():
            rename_map[col] = 'dew_point'
        elif 'humidity' in col.lower():
            rename_map[col] = 'humidity'
        elif 'precipitation' in col.lower():
            rename_map[col] = 'precipitation'
        elif 'direction' in col.lower():
            rename_map[col] = 'wind_direction'
        elif 'wind speed' in col.lower() or 'wind_speed' in col.lower():
            rename_map[col] = 'wind_speed'
        elif 'pressure' in col.lower():
            rename_map[col] = 'pressure'
    df = df.rename(columns=rename_map)

    print(f"Loaded {len(df)} rows, date range: {df['Datetime'].min()} to {df['Datetime'].max()}")
    return df


def engineer_features(df: pd.DataFrame) -> pd.DataFrame:
    """Add cyclical time encodings and fill missing values."""
    # Cyclical time features
    df['hour'] = df['Datetime'].dt.hour
    df['dow'] = df['Datetime'].dt.dayofweek
    df['month'] = df['Datetime'].dt.month

    df['hour_sin'] = np.sin(2 * np.pi * df['hour'] / 24)
    df['hour_cos'] = np.cos(2 * np.pi * df['hour'] / 24)
    df['dow_sin'] = np.sin(2 * np.pi * df['dow'] / 7)
    df['dow_cos'] = np.cos(2 * np.pi * df['dow'] / 7)
    df['month_sin'] = np.sin(2 * np.pi * df['month'] / 12)
    df['month_cos'] = np.cos(2 * np.pi * df['month'] / 12)

    # Forward fill per station, then backfill, then fill remaining with median
    numeric_cols = df.select_dtypes(include=[np.number]).columns
    df[numeric_cols] = df.groupby('StationId')[numeric_cols].transform(
        lambda x: x.ffill().bfill()
    )
    # Final fallback: fill remaining NaN with column median
    for col in numeric_cols:
        median_val = df[col].median()
        df[col] = df[col].fillna(median_val if not np.isnan(median_val) else 0)

    return df


def create_sequences(df: pd.DataFrame, lookback: int = 24, horizon: int = 24, 
                     scaler_path: str = None, step: int = 4) -> tuple:
    """
    Create sliding-window sequences for LSTM training.
    
    Args:
        df: Preprocessed DataFrame
        lookback: Number of past hours to use as input (default 24h)
        horizon: Number of future hours to predict (default 24h)
        scaler_path: Path to save the fitted scaler
        step: Stride for sequence extraction
    
    Returns:
        X: np.array of shape (n_samples, lookback, n_features)
        y: np.array of shape (n_samples, horizon, n_targets)
        scaler: Fitted MinMaxScaler
        feature_cols: List of feature column names used
        target_cols: List of target column names
    """
    # Ensure all feature columns exist
    available_features = [c for c in FEATURE_COLS if c in df.columns]
    available_targets = [c for c in TARGET_COLS if c in df.columns]

    print(f"Using {len(available_features)} features: {available_features}")
    print(f"Predicting {len(available_targets)} targets: {available_targets}")

    # Fit scaler on all feature + target columns combined
    all_cols = list(set(available_features + available_targets))
    scaler = MinMaxScaler(feature_range=(0, 1))
    df_scaled = df.copy()
    df_scaled[all_cols] = scaler.fit_transform(df[all_cols])

    # Save scaler
    if scaler_path:
        os.makedirs(os.path.dirname(scaler_path), exist_ok=True)
        joblib.dump({
            'scaler': scaler,
            'feature_cols': available_features,
            'target_cols': available_targets,
            'all_cols': all_cols
        }, scaler_path)
        print(f"Scaler saved to {scaler_path}")

    # Create sequences per station
    X_all, y_all = [], []

    for station_id, group in df_scaled.groupby('StationId'):
        group = group.sort_values('Datetime').reset_index(drop=True)
        features = group[available_features].values
        targets = group[available_targets].values

        total_len = lookback + horizon
        if len(group) < total_len:
            print(f"  Skipping station {station_id}: only {len(group)} rows (need {total_len})")
            continue

        n_samples = len(group) - total_len + 1
        for i in range(0, n_samples, step):
            X_all.append(features[i:i + lookback])
            y_all.append(targets[i + lookback:i + total_len])

        print(f"  Station {station_id}: {len(range(0, n_samples, step))} sequences")

    X = np.array(X_all, dtype=np.float32)
    y = np.array(y_all, dtype=np.float32)

    print(f"Total sequences: X={X.shape}, y={y.shape}")
    return X, y, scaler, available_features, available_targets


def prepare_data(data_path: str, scaler_path: str, lookback: int = 24, horizon: int = 24,
                 use_all_stations: bool = False, test_ratio: float = 0.15, val_ratio: float = 0.15,
                 step: int = 4):
    """
    Full preprocessing pipeline.
    
    Returns:
        dict with train/val/test splits and metadata
    """
    df = load_and_clean(data_path, use_all_stations=use_all_stations)
    df = engineer_features(df)
    X, y, scaler, feature_cols, target_cols = create_sequences(
        df, lookback=lookback, horizon=horizon, scaler_path=scaler_path, step=step
    )

    # Time-based split (not random, to prevent data leakage)
    n = len(X)
    train_end = int(n * (1 - test_ratio - val_ratio))
    val_end = int(n * (1 - test_ratio))

    result = {
        'X_train': X[:train_end],
        'y_train': y[:train_end],
        'X_val': X[train_end:val_end],
        'y_val': y[train_end:val_end],
        'X_test': X[val_end:],
        'y_test': y[val_end:],
        'feature_cols': feature_cols,
        'target_cols': target_cols,
        'scaler': scaler,
        'lookback': lookback,
        'horizon': horizon,
    }

    print(f"\nData splits:")
    print(f"  Train: {result['X_train'].shape[0]} samples")
    print(f"  Val:   {result['X_val'].shape[0]} samples")
    print(f"  Test:  {result['X_test'].shape[0]} samples")

    return result


if __name__ == '__main__':
    import argparse

    default_data = os.path.join(
        os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
        'merged_delhi_air_quality_weather.csv'
    )
    default_scaler = os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        'weights',
        'scaler.pkl'
    )

    parser = argparse.ArgumentParser(description="Preprocess Delhi AQI and weather dataset")
    parser.add_argument('--data', type=str, default=default_data, help="Path to CSV dataset")
    parser.add_argument('--scaler', type=str, default=default_scaler, help="Path to save scaler.pkl")
    parser.add_argument('--lookback', type=int, default=24, help="Lookback window in hours")
    parser.add_argument('--horizon', type=int, default=24, help="Forecast horizon in hours")
    parser.add_argument('--step', type=int, default=4, help="Sequence stride step")
    parser.add_argument('--all-stations', action='store_true', help="Use all 28 stations instead of representative 5")

    args = parser.parse_args()

    print("=" * 65)
    print("  Delhi Air Quality & Weather Preprocessing Pipeline")
    print("=" * 65)
    print(f"Dataset path : {args.data}")
    print(f"Scaler output: {args.scaler}")
    print(f"Lookback     : {args.lookback}h")
    print(f"Horizon      : {args.horizon}h")
    print(f"Stride step  : {args.step}")
    print(f"All stations : {args.all_stations}")
    print("-" * 65)

    data = prepare_data(
        data_path=args.data,
        scaler_path=args.scaler,
        lookback=args.lookback,
        horizon=args.horizon,
        use_all_stations=args.all_stations,
        step=args.step
    )

    print("\n[OK] Preprocessing completed successfully!")
    print(f"Input features tensor shape : {data['X_train'].shape}")
    print(f"Target values tensor shape  : {data['y_train'].shape}")
    print(f"Feature columns ({len(data['feature_cols'])}): {data['feature_cols']}")
    print(f"Target columns  ({len(data['target_cols'])}): {data['target_cols']}")
