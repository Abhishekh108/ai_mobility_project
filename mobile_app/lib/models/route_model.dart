class RouteSegment {
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;
  final double distanceKm;
  final double durationMinutes;
  final double aqi;
  final double exposure;

  RouteSegment({
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
    required this.distanceKm,
    required this.durationMinutes,
    required this.aqi,
    required this.exposure,
  });

  factory RouteSegment.fromJson(Map<String, dynamic> json) {
    return RouteSegment(
      startLat: (json['start_lat'] as num?)?.toDouble() ?? 0.0,
      startLng: (json['start_lng'] as num?)?.toDouble() ?? 0.0,
      endLat: (json['end_lat'] as num?)?.toDouble() ?? 0.0,
      endLng: (json['end_lng'] as num?)?.toDouble() ?? 0.0,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      durationMinutes: (json['duration_minutes'] as num?)?.toDouble() ?? 0.0,
      aqi: (json['aqi'] as num?)?.toDouble() ?? 0.0,
      exposure: (json['exposure'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class HealthClassification {
  final String label;
  final String color;
  final String? advisory;

  HealthClassification({
    required this.label,
    required this.color,
    this.advisory,
  });

  factory HealthClassification.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return HealthClassification(label: 'Moderate', color: '#eab308');
    }
    return HealthClassification(
      label: json['label'] ?? json['category'] ?? 'Moderate',
      color: json['color'] ?? '#eab308',
      advisory: json['advisory'] ?? json['description'],
    );
  }
}

class RouteItem {
  final int routeIndex;
  final String summary;
  final double totalDistanceKm;
  final double totalDurationMinutes;
  final double? durationInTrafficMinutes;
  final double averageAqi;
  final double maxAqi;
  final double minAqi;
  final double cumulativeExposure;
  final HealthClassification healthClassification;
  final String healthAdvisory;
  final String? practicalReasoning;
  final double? exposureReductionPct;
  final String polylineEncoded;
  final List<RouteSegment> segments;
  final bool isSafest;
  final double? compositeScore;

  RouteItem({
    required this.routeIndex,
    required this.summary,
    required this.totalDistanceKm,
    required this.totalDurationMinutes,
    this.durationInTrafficMinutes,
    required this.averageAqi,
    required this.maxAqi,
    required this.minAqi,
    required this.cumulativeExposure,
    required this.healthClassification,
    required this.healthAdvisory,
    this.practicalReasoning,
    this.exposureReductionPct,
    required this.polylineEncoded,
    required this.segments,
    required this.isSafest,
    this.compositeScore,
  });

  factory RouteItem.fromJson(Map<String, dynamic> json) {
    final segsList = (json['segments'] as List?) ?? [];
    return RouteItem(
      routeIndex: json['route_index'] ?? 0,
      summary: json['summary'] ?? 'Standard Route',
      totalDistanceKm: (json['total_distance_km'] as num?)?.toDouble() ?? 0.0,
      totalDurationMinutes: (json['total_duration_minutes'] as num?)?.toDouble() ?? 0.0,
      durationInTrafficMinutes: (json['duration_in_traffic_minutes'] as num?)?.toDouble(),
      averageAqi: (json['average_aqi'] as num?)?.toDouble() ?? 0.0,
      maxAqi: (json['max_aqi'] as num?)?.toDouble() ?? 0.0,
      minAqi: (json['min_aqi'] as num?)?.toDouble() ?? 0.0,
      cumulativeExposure: (json['cumulative_exposure'] as num?)?.toDouble() ?? 0.0,
      healthClassification: HealthClassification.fromJson(json['health_classification'] as Map<String, dynamic>?),
      healthAdvisory: json['health_advisory'] ?? 'Exercise standard caution during commute.',
      practicalReasoning: json['practical_reasoning'],
      exposureReductionPct: (json['exposure_reduction_pct'] as num?)?.toDouble(),
      polylineEncoded: json['polyline_encoded'] ?? '',
      segments: segsList.map((s) => RouteSegment.fromJson(s as Map<String, dynamic>)).toList(),
      isSafest: json['is_safest'] == true,
      compositeScore: (json['composite_score'] as num?)?.toDouble(),
    );
  }
}

class RouteComparisonResult {
  final String origin;
  final String destination;
  final double? originAqi;
  final double? destCurrentAqi;
  final double? destPredictedAqi;
  final int safestRouteIndex;
  final List<RouteItem> routes;
  final bool alertTriggered;
  final String? alertMessage;

  RouteComparisonResult({
    required this.origin,
    required this.destination,
    this.originAqi,
    this.destCurrentAqi,
    this.destPredictedAqi,
    required this.safestRouteIndex,
    required this.routes,
    this.alertTriggered = false,
    this.alertMessage,
  });

  factory RouteComparisonResult.fromJson(Map<String, dynamic> json) {
    final rList = (json['routes'] as List?) ?? [];
    return RouteComparisonResult(
      origin: json['origin'] ?? '',
      destination: json['destination'] ?? '',
      originAqi: (json['origin_aqi'] as num?)?.toDouble(),
      destCurrentAqi: (json['destination_current_aqi'] as num?)?.toDouble(),
      destPredictedAqi: (json['destination_predicted_aqi'] as num?)?.toDouble(),
      safestRouteIndex: json['safest_route_index'] ?? 0,
      routes: rList.map((r) => RouteItem.fromJson(r as Map<String, dynamic>)).toList(),
      alertTriggered: json['alert_triggered'] == true,
      alertMessage: json['alert_message'],
    );
  }
}
