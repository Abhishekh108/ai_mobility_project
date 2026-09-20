"""
Training script for the AQI forecasting LSTM model.
Supports early stopping, learning rate scheduling, and checkpoint saving.
"""
import os
import sys
import time
import numpy as np
import torch
import torch.nn as nn
from torch.utils.data import DataLoader, TensorDataset

# Add project root to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ml.preprocess import prepare_data
from ml.model import create_model, WeightedMSELoss


def train_model(data_path: str, weights_dir: str, epochs: int = 80, batch_size: int = 64,
                lr: float = 1e-3, patience: int = 10, use_gru: bool = False,
                use_all_stations: bool = False):
    """
    Full training pipeline.
    
    Args:
        data_path: Path to the CSV data file
        weights_dir: Directory to save model weights and scaler
        epochs: Maximum training epochs
        batch_size: Training batch size
        lr: Initial learning rate
        patience: Early stopping patience
        use_gru: Whether to use GRU instead of LSTM
        use_all_stations: Whether to train on all 28 stations
    """
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"Using device: {device}")

    # Prepare data
    scaler_path = os.path.join(weights_dir, 'scaler.pkl')
    data = prepare_data(
        data_path=data_path,
        scaler_path=scaler_path,
        lookback=24,
        horizon=24,
        use_all_stations=use_all_stations
    )

    # Create DataLoaders
    train_dataset = TensorDataset(
        torch.FloatTensor(data['X_train']),
        torch.FloatTensor(data['y_train'])
    )
    val_dataset = TensorDataset(
        torch.FloatTensor(data['X_val']),
        torch.FloatTensor(data['y_val'])
    )

    train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True, drop_last=True)
    val_loader = DataLoader(val_dataset, batch_size=batch_size, shuffle=False)

    n_features = data['X_train'].shape[2]
    n_targets = data['y_train'].shape[2]

    print(f"\nModel config: {n_features} features -> {n_targets} targets x 24h horizon")

    # Create model
    model = create_model(
        n_features=n_features,
        n_targets=n_targets,
        horizon=24,
        use_gru=use_gru,
        device=str(device)
    )

    # Loss and optimizer
    criterion = WeightedMSELoss(n_targets=n_targets, aqi_weight=2.0).to(device)
    optimizer = torch.optim.Adam(model.parameters(), lr=lr)
    scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(
        optimizer, mode='min', factor=0.5, patience=5
    )

    # Training loop with early stopping
    best_val_loss = float('inf')
    epochs_no_improve = 0
    best_model_path = os.path.join(weights_dir, 'aqi_lstm.pt')
    os.makedirs(weights_dir, exist_ok=True)

    train_losses = []
    val_losses = []

    print(f"\nStarting training for up to {epochs} epochs...")
    print(f"{'Epoch':>6} | {'Train Loss':>12} | {'Val Loss':>12} | {'LR':>10} | {'Time':>8}")
    print("-" * 60)

    for epoch in range(1, epochs + 1):
        epoch_start = time.time()

        # Training phase
        model.train()
        running_loss = 0.0
        n_batches = 0

        for X_batch, y_batch in train_loader:
            X_batch, y_batch = X_batch.to(device), y_batch.to(device)

            optimizer.zero_grad()
            predictions = model(X_batch)
            loss = criterion(predictions, y_batch)
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)
            optimizer.step()

            running_loss += loss.item()
            n_batches += 1

        train_loss = running_loss / max(n_batches, 1)
        train_losses.append(train_loss)

        # Validation phase
        model.eval()
        val_running_loss = 0.0
        val_batches = 0

        with torch.no_grad():
            for X_batch, y_batch in val_loader:
                X_batch, y_batch = X_batch.to(device), y_batch.to(device)
                predictions = model(X_batch)
                loss = criterion(predictions, y_batch)
                val_running_loss += loss.item()
                val_batches += 1

        val_loss = val_running_loss / max(val_batches, 1)
        val_losses.append(val_loss)

        # Learning rate scheduling
        scheduler.step(val_loss)
        current_lr = optimizer.param_groups[0]['lr']

        elapsed = time.time() - epoch_start
        print(f"{epoch:>6} | {train_loss:>12.6f} | {val_loss:>12.6f} | {current_lr:>10.6f} | {elapsed:>7.1f}s")

        # Early stopping check
        if val_loss < best_val_loss:
            best_val_loss = val_loss
            epochs_no_improve = 0
            # Save best model
            torch.save({
                'model_state_dict': model.state_dict(),
                'n_features': n_features,
                'n_targets': n_targets,
                'horizon': 24,
                'feature_cols': data['feature_cols'],
                'target_cols': data['target_cols'],
                'use_gru': use_gru,
                'best_val_loss': best_val_loss,
                'epoch': epoch,
            }, best_model_path)
            print(f"       [OK] Saved best model (val_loss={best_val_loss:.6f})")
        else:
            epochs_no_improve += 1
            if epochs_no_improve >= patience:
                print(f"\nEarly stopping at epoch {epoch} (no improvement for {patience} epochs)")
                break

    print(f"\nTraining complete! Best validation loss: {best_val_loss:.6f}")
    print(f"Model saved to: {best_model_path}")
    print(f"Scaler saved to: {scaler_path}")

    # Quick test set evaluation
    test_dataset = TensorDataset(
        torch.FloatTensor(data['X_test']),
        torch.FloatTensor(data['y_test'])
    )
    test_loader = DataLoader(test_dataset, batch_size=batch_size, shuffle=False)

    # Load best model for testing
    checkpoint = torch.load(best_model_path, map_location=device, weights_only=True)
    model.load_state_dict(checkpoint['model_state_dict'])
    model.eval()

    test_loss = 0.0
    test_batches = 0
    with torch.no_grad():
        for X_batch, y_batch in test_loader:
            X_batch, y_batch = X_batch.to(device), y_batch.to(device)
            predictions = model(X_batch)
            loss = criterion(predictions, y_batch)
            test_loss += loss.item()
            test_batches += 1

    test_loss = test_loss / max(test_batches, 1)
    print(f"Test loss: {test_loss:.6f}")

    return {
        'train_losses': train_losses,
        'val_losses': val_losses,
        'test_loss': test_loss,
        'best_val_loss': best_val_loss,
        'model_path': best_model_path,
        'scaler_path': scaler_path
    }


if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser(description='Train AQI forecasting model')
    parser.add_argument('--data', type=str, 
                        default=os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 
                                             'merged_delhi_air_quality_weather.csv'),
                        help='Path to CSV data file')
    parser.add_argument('--weights-dir', type=str,
                        default=os.path.join(os.path.dirname(os.path.abspath(__file__)), 'weights'),
                        help='Directory to save model weights')
    parser.add_argument('--epochs', type=int, default=80)
    parser.add_argument('--batch-size', type=int, default=64)
    parser.add_argument('--lr', type=float, default=1e-3)
    parser.add_argument('--patience', type=int, default=10)
    parser.add_argument('--gru', action='store_true', help='Use GRU instead of LSTM')
    parser.add_argument('--all-stations', action='store_true', help='Train on all 28 stations')

    args = parser.parse_args()

    result = train_model(
        data_path=args.data,
        weights_dir=args.weights_dir,
        epochs=args.epochs,
        batch_size=args.batch_size,
        lr=args.lr,
        patience=args.patience,
        use_gru=args.gru,
        use_all_stations=args.all_stations
    )
