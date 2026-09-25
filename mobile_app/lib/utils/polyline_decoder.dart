import 'package:latlong2/latlong.dart';

class PolylineDecoder {
  /// Decodes an encoded path string into a sequence of LatLng points.
  /// Uses arithmetic negation instead of bitwise NOT `~` to ensure
  /// 100% correctness across both Dart VM (Android/iOS) and Dart Web (Chrome/Safari),
  /// where dart2js treats `~` as an unsigned 32-bit integer causing coordinates
  /// to explode to 16,000,000+.
  static List<LatLng> decode(String encoded) {
    if (encoded.isEmpty) return const [];
    final points = <LatLng>[];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = ((result & 1) != 0 ? -((result >> 1) + 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = ((result & 1) != 0 ? -((result >> 1) + 1) : (result >> 1));
      lng += dlng;

      final latDeg = lat / 1E5;
      final lngDeg = lng / 1E5;
      if (latDeg >= -90.0 && latDeg <= 90.0 && lngDeg >= -180.0 && lngDeg <= 180.0) {
        points.add(LatLng(latDeg, lngDeg));
      }
    }
    return points;
  }
}

