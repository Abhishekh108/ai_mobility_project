import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/station.dart';
import '../models/route_model.dart';
import '../models/prediction.dart';
import '../models/user_profile.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const String _prefKeyBaseUrl = 'api_custom_base_url';

  // Default to 127.0.0.1 for Web/Desktop, 10.0.2.2 for Android emulator
  String _currentBaseUrl = kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';
  bool _initialized = false;

  String get baseUrl => _currentBaseUrl;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKeyBaseUrl);
      if (saved != null && saved.isNotEmpty) {
        _currentBaseUrl = saved;
      }
    } catch (_) {}
    _initialized = true;
  }

  Future<void> setBaseUrl(String url) async {
    _currentBaseUrl = url.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyBaseUrl, _currentBaseUrl);
    } catch (_) {}
  }

  String _getAlternateUrl(String url) {
    if (url.contains(':8000')) {
      return url.replaceAll(':8000', ':8001');
    } else if (url.contains(':8001')) {
      return url.replaceAll(':8001', ':8000');
    }
    return url;
  }

  Future<http.Response> _executeWithFallback(
    Future<http.Response> Function(String base) requestFn,
  ) async {
    await init();
    try {
      final res = await requestFn(_currentBaseUrl).timeout(const Duration(seconds: 12));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return res;
      }
      throw Exception('Server returned ${res.statusCode}: ${res.body}');
    } catch (e) {
      // Try alternate port (e.g. 8000 <-> 8001)
      final altBase = _getAlternateUrl(_currentBaseUrl);
      if (altBase != _currentBaseUrl) {
        try {
          final res = await requestFn(altBase).timeout(const Duration(seconds: 12));
          if (res.statusCode >= 200 && res.statusCode < 300) {
            _currentBaseUrl = altBase; // switch active base
            return res;
          }
        } catch (_) {}
      }
      rethrow;
    }
  }

  // --- API Endpoints ---

  /// List all 28 Delhi CPCB monitoring stations
  Future<List<Station>> getStations() async {
    final res = await _executeWithFallback((base) {
      return http.get(Uri.parse('$base/api/stations'));
    });
    final List list = jsonDecode(res.body);
    return list.map((item) => Station.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// Get single station info
  Future<Station> getStation(String stationId) async {
    final res = await _executeWithFallback((base) {
      return http.get(Uri.parse('$base/api/stations/$stationId'));
    });
    return Station.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Fetch 24-hour neural LSTM prediction
  Future<StationPrediction> predictAQI(String stationId, {int hoursAhead = 24}) async {
    final res = await _executeWithFallback((base) {
      return http.post(
        Uri.parse('$base/api/predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'station_id': stationId,
          'hours_ahead': hoursAhead,
        }),
      );
    });
    return StationPrediction.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Compare routes between origin and destination with spatial IDW
  Future<RouteComparisonResult> compareRoutes(
    String origin,
    String destination, {
    String? userId,
  }) async {
    final res = await _executeWithFallback((base) {
      return http.post(
        Uri.parse('$base/api/routes/compare'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'origin': origin,
          'destination': destination,
          if (userId != null) 'user_id': userId,
        }),
      );
    });
    return RouteComparisonResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Real-time spot check at coordinates
  Future<Map<String, dynamic>> checkPositionAQI(
    double lat,
    double lng, {
    String? userId,
  }) async {
    final res = await _executeWithFallback((base) {
      final userParam = userId != null ? '&user_id=$userId' : '';
      return http.post(
        Uri.parse('$base/api/routes/check-position?lat=$lat&lng=$lng$userParam'),
      );
    });
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Create commuter profile
  Future<UserProfile> createProfile(Map<String, dynamic> data) async {
    final res = await _executeWithFallback((base) {
      return http.post(
        Uri.parse('$base/api/profiles'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
    });
    return UserProfile.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Check server health
  Future<bool> checkHealth() async {
    try {
      final res = await _executeWithFallback((base) {
        return http.get(Uri.parse('$base/api/health'));
      });
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
