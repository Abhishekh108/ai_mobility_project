"""
LSTM/GRU model architecture for multi-output AQI forecasting.
Predicts PM2.5, PM10, NO2, O3, CO, and AQI for 1-24 hours ahead.
"""
import torch
import torch.nn as nn


class AQIForecaster(nn.Module):
    """
    Multi-output LSTM model for air quality forecasting.
    
    Architecture:
        Input (n_features) → LSTM(128) → Dropout → LSTM(64) → Dropout → FC → Output (n_targets × horizon)
    
    The model takes a lookback window of historical readings and outputs
    predictions for multiple pollutant targets across a forecast horizon.
    """

    def __init__(self, n_features: int, n_targets: int, horizon: int = 24,
                 hidden_size_1: int = 128, hidden_size_2: int = 64,
                 dropout: float = 0.2, use_gru: bool = False):
        super(AQIForecaster, self).__init__()

        self.n_targets = n_targets
        self.horizon = horizon
        self.hidden_size_1 = hidden_size_1
        self.hidden_size_2 = hidden_size_2

        RNNLayer = nn.GRU if use_gru else nn.LSTM

        # First recurrent layer
        self.rnn1 = RNNLayer(
            input_size=n_features,
            hidden_size=hidden_size_1,
            batch_first=True,
            num_layers=1
        )
        self.dropout1 = nn.Dropout(dropout)

        # Second recurrent layer
        self.rnn2 = RNNLayer(
            input_size=hidden_size_1,
            hidden_size=hidden_size_2,
            batch_first=True,
            num_layers=1
        )
        self.dropout2 = nn.Dropout(dropout)

        # Fully connected output layers
        self.fc1 = nn.Linear(hidden_size_2, 128)
        self.relu = nn.ReLU()
        self.fc2 = nn.Linear(128, n_targets * horizon)

    def forward(self, x):
        """
        Forward pass.
        
        Args:
            x: Tensor of shape (batch_size, lookback, n_features)
        
        Returns:
            Tensor of shape (batch_size, horizon, n_targets)
        """
        # First LSTM/GRU layer
        out, _ = self.rnn1(x)
        out = self.dropout1(out)

        # Second LSTM/GRU layer
        out, _ = self.rnn2(out)
        out = self.dropout2(out)

        # Take the last time step output
        out = out[:, -1, :]  # (batch_size, hidden_size_2)

        # Fully connected layers
        out = self.fc1(out)
        out = self.relu(out)
        out = self.fc2(out)  # (batch_size, n_targets * horizon)

        # Reshape to (batch_size, horizon, n_targets)
        out = out.view(-1, self.horizon, self.n_targets)

        return out


class WeightedMSELoss(nn.Module):
    """
    Weighted MSE loss that gives higher importance to AQI prediction.
    The last target column (AQI) gets 2x weight.
    """

    def __init__(self, n_targets: int, aqi_weight: float = 2.0):
        super(WeightedMSELoss, self).__init__()
        weights = torch.ones(n_targets)
        weights[-1] = aqi_weight  # AQI is the last target
        self.register_buffer('weights', weights)

    def forward(self, predictions, targets):
        """
        Args:
            predictions: (batch_size, horizon, n_targets)
            targets: (batch_size, horizon, n_targets)
        """
        mse = (predictions - targets) ** 2  # (batch, horizon, targets)
        weighted_mse = mse * self.weights.unsqueeze(0).unsqueeze(0)
        return weighted_mse.mean()


def create_model(n_features: int, n_targets: int, horizon: int = 24,
                 use_gru: bool = False, device: str = 'cpu') -> AQIForecaster:
    """Factory function to create and initialize the model."""
    model = AQIForecaster(
        n_features=n_features,
        n_targets=n_targets,
        horizon=horizon,
        hidden_size_1=128,
        hidden_size_2=64,
        dropout=0.2,
        use_gru=use_gru
    ).to(device)

    # Initialize weights
    for name, param in model.named_parameters():
        if 'weight_ih' in name:
            nn.init.xavier_uniform_(param)
        elif 'weight_hh' in name:
            nn.init.orthogonal_(param)
        elif 'bias' in name:
            nn.init.zeros_(param)

    total_params = sum(p.numel() for p in model.parameters())
    trainable_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
    print(f"Model created: {total_params:,} total params, {trainable_params:,} trainable")
    
    return model
