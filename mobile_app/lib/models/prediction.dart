class HourlyForecast {
  final int hourAhead;
  final String timestamp;
  final double predictedAqi;
  final String bucket;
  final double? pm25;
  final double? pm10;
  final double? no2;

  HourlyForecast({
    required this.hourAhead,
    required this.timestamp,
    required this.predictedAqi,
    required this.bucket,
    this.pm25,
    this.pm10,
    this.no2,
  });

  factory HourlyForecast.fromJson(Map<String, dynamic> json) {
    return HourlyForecast(
      hourAhead: json['hour_ahead'] ?? json['step'] ?? 0,
      timestamp: json['timestamp'] ?? json['forecast_time'] ?? '',
      predictedAqi: (json['predicted_aqi'] as num?)?.toDouble() ?? 
                    (json['aqi'] as num?)?.toDouble() ?? 0.0,
      bucket: json['bucket'] ?? json['aqi_bucket'] ?? 'Moderate',
      pm25: (json['pm25'] as num?)?.toDouble(),
      pm10: (json['pm10'] as num?)?.toDouble(),
      no2: (json['no2'] as num?)?.toDouble(),
    );
  }
}

class StationPrediction {
  final String stationId;
  final int hoursAhead;
  final List<HourlyForecast> predictions;
  final Map<String, dynamic> healthClassification;
  final Map<String, dynamic> modelInfo;

  StationPrediction({
    required this.stationId,
    required this.hoursAhead,
    required this.predictions,
    required this.healthClassification,
    required this.modelInfo,
  });

  factory StationPrediction.fromJson(Map<String, dynamic> json) {
    final preds = (json['predictions'] as List?) ?? [];
    return StationPrediction(
      stationId: json['station_id'] ?? '',
      hoursAhead: json['hours_ahead'] ?? 24,
      predictions: preds.map((p) => HourlyForecast.fromJson(p as Map<String, dynamic>)).toList(),
      healthClassification: (json['health_classification'] as Map<String, dynamic>?) ?? {},
      modelInfo: (json['model_info'] as Map<String, dynamic>?) ?? {},
    );
  }
}
