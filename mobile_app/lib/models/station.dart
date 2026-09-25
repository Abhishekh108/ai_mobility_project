class StationReadings {
  final double? pm25;
  final double? pm10;
  final double? no2;
  final double? o3;
  final double? co;
  final double? so2;

  StationReadings({
    this.pm25,
    this.pm10,
    this.no2,
    this.o3,
    this.co,
    this.so2,
  });

  factory StationReadings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return StationReadings();
    return StationReadings(
      pm25: (json['pm25'] as num?)?.toDouble(),
      pm10: (json['pm10'] as num?)?.toDouble(),
      no2: (json['no2'] as num?)?.toDouble(),
      o3: (json['o3'] as num?)?.toDouble(),
      co: (json['co'] as num?)?.toDouble(),
      so2: (json['so2'] as num?)?.toDouble(),
    );
  }
}

class StationWeather {
  final double? temperature;
  final double? humidity;
  final double? windSpeed;

  StationWeather({
    this.temperature,
    this.humidity,
    this.windSpeed,
  });

  factory StationWeather.fromJson(Map<String, dynamic>? json) {
    if (json == null) return StationWeather();
    return StationWeather(
      temperature: (json['temperature'] as num?)?.toDouble(),
      humidity: (json['humidity'] as num?)?.toDouble(),
      windSpeed: (json['wind_speed'] as num?)?.toDouble(),
    );
  }
}

class Station {
  final String stationId;
  final String stationName;
  final double latitude;
  final double longitude;
  final double? aqi;
  final String? aqiBucket;
  final StationReadings readings;
  final StationWeather weather;
  final String? updatedAt;

  Station({
    required this.stationId,
    required this.stationName,
    required this.latitude,
    required this.longitude,
    this.aqi,
    this.aqiBucket,
    required this.readings,
    required this.weather,
    this.updatedAt,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      stationId: json['station_id'] ?? '',
      stationName: json['station_name'] ?? 'Unknown Station',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 28.6139,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 77.2090,
      aqi: (json['aqi'] as num?)?.toDouble(),
      aqiBucket: json['aqi_bucket'],
      readings: StationReadings.fromJson(json['readings'] as Map<String, dynamic>?),
      weather: StationWeather.fromJson(json['weather'] as Map<String, dynamic>?),
      updatedAt: json['updated_at'],
    );
  }
}
