import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../data/delhi_locations.dart';
import '../models/route_model.dart';
import '../models/station.dart';
import '../theme/app_theme.dart';
import '../utils/polyline_decoder.dart';
import '../widgets/route_card.dart';

class RouteSearchScreen extends StatefulWidget {
  final List<RouteItem> routes;
  final int activeRouteIndex;
  final Function(int) onSelectRoute;
  final Future<void> Function(String origin, String destination) onSearch;
  final bool isLoading;
  final RouteComparisonResult? lastResult;
  final List<Station> stations;
  final VoidCallback? onNavigateToFullMap;

  const RouteSearchScreen({
    super.key,
    required this.routes,
    required this.activeRouteIndex,
    required this.onSelectRoute,
    required this.onSearch,
    this.isLoading = false,
    this.lastResult,
    this.stations = const [],
    this.onNavigateToFullMap,
  });

  @override
  State<RouteSearchScreen> createState() => _RouteSearchScreenState();
}

class _RouteSearchScreenState extends State<RouteSearchScreen> {
  final TextEditingController _originController =
      TextEditingController(text: 'Connaught Place, New Delhi');
  final TextEditingController _destController =
      TextEditingController(text: 'Indira Gandhi International Airport (T3), Delhi');

  final MapController _mapController = MapController();
  static const LatLng _delhiCenter = LatLng(28.6139, 77.2090);

  double _currentZoom = 11.2;
  bool _showStations = false;

  // ── Corridor color palette (matches web app) ─────────────────────────────
  static const List<Color> _corridorColors = [
    Color(0xFF3B82F6), // Blue  – Safest / Primary
    Color(0xFFF59E0B), // Amber – Alternative 2
    Color(0xFF8B5CF6), // Purple– Alternative 3
  ];

  static const List<String> _corridorIcons = ['🌿', '⚡', '🚗'];

  final List<Map<String, String>> _presets = [
    {
      'title': 'CP ➔ IGI Airport (T3)',
      'from': 'Connaught Place, New Delhi',
      'to': 'Indira Gandhi International Airport (T3), Delhi',
    },
    {
      'title': 'Anand Vihar ➔ Cyber City',
      'from': 'Anand Vihar ISBT & Railway Station, Delhi',
      'to': 'DLF Cyber City, Gurugram',
    },
    {
      'title': 'Noida Sec 62 ➔ CP',
      'from': 'Noida Sector 62 (Electronic City)',
      'to': 'Connaught Place, New Delhi',
    },
    {
      'title': 'Rohini ➔ Nehru Place',
      'from': 'Rohini Sector 10, Delhi',
      'to': 'Nehru Place, New Delhi',
    },
    {
      'title': 'Dwarka ➔ Akshardham',
      'from': 'Dwarka Sector 21 (Metro Interchange), Delhi',
      'to': 'Akshardham Temple, Delhi',
    },
  ];

  @override
  void dispose() {
    _originController.dispose();
    _destController.dispose();
    super.dispose();
  }

  // ── Submit search ─────────────────────────────────────────────────────────
  void _submit() {
    final origin = _originController.text.trim();
    final dest = _destController.text.trim();
    if (origin.isEmpty || dest.isEmpty) return;
    widget.onSearch(origin, dest);
  }

  void _swapInputs() {
    final temp = _originController.text;
    _originController.text = _destController.text;
    _destController.text = temp;
  }

  // ── Show location picker dialog ───────────────────────────────────────────
  Future<void> _showLocationPicker({required bool isOrigin}) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LocationPickerSheet(stations: widget.stations),
    );
    if (result != null && result.isNotEmpty) {
      setState(() {
        if (isOrigin) {
          _originController.text = result;
        } else {
          _destController.text = result;
        }
      });
    }
  }

  // ── Fit map camera to route bounding box ─────────────────────────────────
  void _fitRoute(List<LatLng> pts) {
    if (pts.isEmpty) return;
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    // Generous 20% padding on each side
    final padLat = (maxLat - minLat).abs() * 0.20;
    final padLng = (maxLng - minLng).abs() * 0.20;
    final south = (minLat - padLat).clamp(-85.0, 85.0);
    final north = (maxLat + padLat).clamp(-85.0, 85.0);
    final west = (minLng - padLng).clamp(-180.0, 180.0);
    final east = (maxLng + padLng).clamp(-180.0, 180.0);
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(
            LatLng(south, west),
            LatLng(north, east),
          ),
          padding: const EdgeInsets.all(24),
        ),
      );
    } catch (_) {}
  }

  // ── Select a corridor and zoom map to it ─────────────────────────────────
  void _selectCorridorAndZoom(int idx) {
    widget.onSelectRoute(idx);
    if (idx < widget.routes.length &&
        widget.routes[idx].polylineEncoded.isNotEmpty) {
      final pts = PolylineDecoder.decode(widget.routes[idx].polylineEncoded);
      if (pts.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitRoute(pts));
      }
    }
  }

  // ── Build polylines: inactive FIRST (bottom), active LAST (top) ──────────
  List<Polyline> _buildPolylines() {
    final result = <Polyline>[];
    // Draw inactive routes first (they go underneath)
    for (int i = 0; i < widget.routes.length; i++) {
      if (i == widget.activeRouteIndex) continue;
      final r = widget.routes[i];
      if (r.polylineEncoded.isEmpty) continue;
      final pts = PolylineDecoder.decode(r.polylineEncoded);
      if (pts.isEmpty) continue;
      final color = _corridorColors[i % _corridorColors.length];
      result.add(Polyline(
        points: pts,
        strokeWidth: 3.0,
        color: color.withValues(alpha: 0.40),
        pattern: StrokePattern.dashed(segments: const [8.0, 6.0]),
      ));
    }
    // Draw active route on top with bold styling
    if (widget.routes.isNotEmpty) {
      final i = widget.activeRouteIndex.clamp(0, widget.routes.length - 1);
      final r = widget.routes[i];
      if (r.polylineEncoded.isNotEmpty) {
        final pts = PolylineDecoder.decode(r.polylineEncoded);
        if (pts.isNotEmpty) {
          final color = _corridorColors[i % _corridorColors.length];
          // Dark shadow / casing
          result.add(Polyline(
            points: pts,
            strokeWidth: 9.5,
            color: Colors.black.withValues(alpha: 0.50),
          ));
          // Vibrant active line
          result.add(Polyline(
            points: pts,
            strokeWidth: 6.5,
            color: color,
          ));
        }
      }
    }
    return result;
  }

  // ── Extract origin and destination from active route ─────────────────────
  (LatLng?, LatLng?) _getODPoints() {
    if (widget.routes.isEmpty) return (null, null);
    final idx = widget.activeRouteIndex.clamp(0, widget.routes.length - 1);
    final r = widget.routes[idx];
    if (r.polylineEncoded.isEmpty) return (null, null);
    final pts = PolylineDecoder.decode(r.polylineEncoded);
    if (pts.isEmpty) return (null, null);
    return (pts.first, pts.last);
  }

  Color _aqiColor(double? aqi) {
    if (aqi == null) return const Color(0xFF94A3B8);
    if (aqi <= 50) return const Color(0xFF059669);
    if (aqi <= 100) return const Color(0xFF10B981);
    if (aqi <= 200) return const Color(0xFFD97706);
    if (aqi <= 300) return const Color(0xFFDC2626);
    if (aqi <= 400) return const Color(0xFF9333EA);
    return const Color(0xFF7E22CE);
  }

  @override
  Widget build(BuildContext context) {
    final (originPt, destPt) = _getODPoints();
    final hasRoutes = widget.routes.isNotEmpty;

    // Auto-fit camera when routes arrive for the first time
    if (hasRoutes) {
      final r = widget.routes[widget.activeRouteIndex.clamp(0, widget.routes.length - 1)];
      if (r.polylineEncoded.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fitRoute(PolylineDecoder.decode(r.polylineEncoded));
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.alt_route, color: AppTheme.primary, size: 24),
            SizedBox(width: 10),
            Text(
              'Intelligent Route Optimizer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textSecondary),
            tooltip: 'Reload Cleanest Route',
            onPressed: widget.isLoading ? null : _submit,
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // ═══════════════════════════════════════════════════════════════
            // SEARCH BOX CARD WITH DROPDOWN PICKER
            // ═══════════════════════════════════════════════════════════════
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Connector dots
                      const Column(
                        children: [
                          Icon(Icons.circle, color: Color(0xFF10B981), size: 14),
                          SizedBox(
                            height: 36,
                            child: VerticalDivider(color: AppTheme.border, thickness: 2),
                          ),
                          Icon(Icons.location_on, color: Color(0xFFEF4444), size: 18),
                        ],
                      ),
                      const SizedBox(width: 12),

                      // Input fields
                      Expanded(
                        child: Column(
                          children: [
                            // ORIGIN INPUT with dropdown button
                            _buildLocationInput(
                              controller: _originController,
                              label: 'Origin',
                              isOrigin: true,
                            ),
                            const SizedBox(height: 10),
                            // DESTINATION INPUT with dropdown button
                            _buildLocationInput(
                              controller: _destController,
                              label: 'Destination',
                              isOrigin: false,
                            ),
                          ],
                        ),
                      ),

                      // Swap Button
                      IconButton(
                        icon: const Icon(Icons.swap_vert,
                            color: AppTheme.textSecondary, size: 26),
                        onPressed: _swapInputs,
                        tooltip: 'Swap locations',
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // SUBMIT BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: widget.isLoading ? null : _submit,
                      icon: widget.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.search, color: Colors.black, size: 20),
                      label: Text(
                        widget.isLoading
                            ? 'Calculating Spatial Exposure...'
                            : 'Find Cleanest Route',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ═══════════════════════════════════════════════════════════════
            // DELHI NCR QUICK PRESETS
            // ═══════════════════════════════════════════════════════════════
            const Text(
              'Delhi NCR Quick Presets',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _presets.map((p) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      backgroundColor: AppTheme.surfaceLight,
                      side: const BorderSide(color: AppTheme.border),
                      label: Text(
                        p['title']!,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _originController.text = p['from']!;
                          _destController.text = p['to']!;
                        });
                        widget.onSearch(p['from']!, p['to']!);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // ─── ORIGIN & DEST PREDICTED AQI ROW ─────────────────────────
            if (widget.lastResult != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Origin AQI: ${widget.lastResult!.originAqi?.round() ?? '—'}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Dest Predicted: ${widget.lastResult!.destPredictedAqi?.round() ?? '—'}',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ═══════════════════════════════════════════════════════════════
            // CORRIDOR SELECTOR TABS (above the map)
            // ═══════════════════════════════════════════════════════════════
            if (hasRoutes) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(widget.routes.length, (i) {
                    final r = widget.routes[i];
                    final isActive = i == widget.activeRouteIndex;
                    final color = _corridorColors[i % _corridorColors.length];
                    final timeMins = (r.durationInTrafficMinutes ??
                        r.totalDurationMinutes)
                        .round();
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => _selectCorridorAndZoom(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isActive
                                ? color.withValues(alpha: 0.18)
                                : AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isActive ? color : AppTheme.border,
                              width: isActive ? 2.0 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_corridorIcons[i % _corridorIcons.length],
                                      style: const TextStyle(fontSize: 13)),
                                  const SizedBox(width: 5),
                                  Text(
                                    i == 0 && r.isSafest
                                        ? 'Cleanest'
                                        : 'Corridor ${i + 1}',
                                    style: TextStyle(
                                      color: isActive ? color : AppTheme.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _miniPill('$timeMins min',
                                      isActive ? color : AppTheme.textMuted),
                                  const SizedBox(width: 4),
                                  _miniPill(
                                      'AQI ${r.averageAqi.round()}',
                                      _aqiColor(r.averageAqi)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // ═══════════════════════════════════════════════════════════════
            // INTERACTIVE MAP WITH 3 SUGGESTED PATHS & ZOOM CONTROLS
            // ═══════════════════════════════════════════════════════════════
            Container(
              height: 320,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border, width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _delhiCenter,
                      initialZoom: _currentZoom,
                      minZoom: 8.0,
                      maxZoom: 18.0,
                      onPositionChanged: (pos, _) {
                        _currentZoom = pos.zoom;
                      },
                    ),
                    children: [
                      // OSM base tile layer
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.aimobility.app',
                        maxZoom: 19,
                      ),

                      // Polylines: inactive first, active on top
                      PolylineLayer(polylines: _buildPolylines()),

                      // Markers
                      MarkerLayer(
                        markers: [
                          // AQI Station Dots (toggleable)
                          if (_showStations)
                            ...widget.stations.map((s) {
                              final color = _aqiColor(s.aqi);
                              return Marker(
                                point: LatLng(s.latitude, s.longitude),
                                width: 34,
                                height: 34,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.black87, width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.5),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      s.aqi != null
                                          ? s.aqi!.round().toString()
                                          : '—',
                                      style: TextStyle(
                                        color: (s.aqi ?? 0) > 150
                                            ? Colors.white
                                            : Colors.black87,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),

                          // Origin Marker — Green 'A' circle
                          if (originPt != null)
                            Marker(
                              point: originPt,
                              width: 34,
                              height: 34,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Color(0x6610B981), blurRadius: 10),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    'A',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // Destination Marker — Red pin
                          if (destPt != null)
                            Marker(
                              point: destPt,
                              width: 34,
                              height: 42,
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on,
                                      color: Color(0xFFEF4444), size: 34),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),

                  // ─── TOP-LEFT: AQI Stations toggle ───────────────────────
                  Positioned(
                    top: 10,
                    left: 10,
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _showStations = !_showStations),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.surface.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 6),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showStations
                                  ? Icons.location_on
                                  : Icons.location_off,
                              size: 16,
                              color: _showStations
                                  ? AppTheme.primary
                                  : AppTheme.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _showStations
                                  ? 'Hide AQI Stations'
                                  : 'Show AQI Stations',
                              style: TextStyle(
                                color: _showStations
                                    ? AppTheme.primary
                                    : AppTheme.textPrimary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ─── TOP-RIGHT: Zoom Controls ─────────────────────────────
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Column(
                      children: [
                        _mapBtn(
                          icon: Icons.add,
                          tooltip: 'Zoom In',
                          onTap: () {
                            final z = (_currentZoom + 1).clamp(8.0, 18.0);
                            _mapController.move(
                                _mapController.camera.center, z);
                            setState(() => _currentZoom = z);
                          },
                        ),
                        const SizedBox(height: 6),
                        _mapBtn(
                          icon: Icons.remove,
                          tooltip: 'Zoom Out',
                          onTap: () {
                            final z = (_currentZoom - 1).clamp(8.0, 18.0);
                            _mapController.move(
                                _mapController.camera.center, z);
                            setState(() => _currentZoom = z);
                          },
                        ),
                        const SizedBox(height: 6),
                        _mapBtn(
                          icon: Icons.my_location,
                          tooltip: 'Recenter Delhi',
                          onTap: () {
                            _mapController.move(_delhiCenter, 11.2);
                            setState(() => _currentZoom = 11.2);
                          },
                        ),
                        if (hasRoutes) ...[
                          const SizedBox(height: 6),
                          _mapBtn(
                            icon: Icons.fit_screen,
                            tooltip: 'Fit Route',
                            onTap: () {
                              final idx = widget.activeRouteIndex
                                  .clamp(0, widget.routes.length - 1);
                              final pts = PolylineDecoder.decode(
                                  widget.routes[idx].polylineEncoded);
                              _fitRoute(pts);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ─── BOTTOM: Path indicator badge ─────────────────────────
                  if (hasRoutes)
                    Positioned(
                      bottom: 8,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.surface.withValues(alpha: 0.90),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _corridorColors[
                                    widget.activeRouteIndex %
                                        _corridorColors.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Showing: Path ${widget.activeRouteIndex + 1} of ${widget.routes.length}',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ═══════════════════════════════════════════════════════════════
            // EVALUATED CORRIDORS LIST (The 3 Routes)
            // ═══════════════════════════════════════════════════════════════
            if (widget.routes.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Evaluated Corridors',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${widget.routes.length} routes ranked',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...List.generate(widget.routes.length, (idx) {
                final r = widget.routes[idx];
                final isSel = idx == widget.activeRouteIndex;
                return RouteCard(
                  route: r,
                  isSelected: isSel,
                  onSelect: () => _selectCorridorAndZoom(idx),
                );
              }),
            ] else if (!widget.isLoading) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Column(
                    children: [
                      Icon(Icons.directions_outlined,
                          size: 48, color: AppTheme.textMuted),
                      SizedBox(height: 12),
                      Text(
                        'Search routes to evaluate pollution exposure',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Location input field with dropdown button ─────────────────────────────
  Widget _buildLocationInput({
    required TextEditingController controller,
    required String label,
    required bool isOrigin,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 13.5,
          fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(color: AppTheme.textMuted, fontSize: 12),
        isDense: true,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear,
                    size: 16, color: AppTheme.textMuted),
                onPressed: () {
                  controller.clear();
                  setState(() {});
                },
              ),
            // Dropdown arrow – opens the picker
            IconButton(
              icon: const Icon(Icons.arrow_drop_down,
                  size: 22, color: AppTheme.textSecondary),
              tooltip: 'Browse Delhi NCR locations',
              onPressed: () =>
                  _showLocationPicker(isOrigin: isOrigin),
            ),
          ],
        ),
      ),
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _submit(),
    );
  }

  // ── Small colored pill badge ──────────────────────────────────────────────
  Widget _miniPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }

  // ── Map control button ────────────────────────────────────────────────────
  Widget _mapBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 4)
            ],
          ),
          child: Icon(icon, size: 18, color: AppTheme.textPrimary),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LOCATION PICKER BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════════
class _LocationPickerSheet extends StatefulWidget {
  final List<Station> stations;
  const _LocationPickerSheet({required this.stations});

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  // Tab: 0 = Delhi NCR locations, 1 = AQI Stations
  int _tab = 0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<DelhiLocation> get _filteredLocations {
    final q = _query.toLowerCase();
    if (q.isEmpty) return delhiLocations;
    return delhiLocations
        .where((l) =>
            l.name.toLowerCase().contains(q) ||
            l.area.toLowerCase().contains(q) ||
            l.category.toLowerCase().contains(q))
        .toList();
  }

  List<Station> get _filteredStations {
    final q = _query.toLowerCase();
    if (q.isEmpty) return widget.stations;
    return widget.stations
        .where((s) =>
            s.stationName.toLowerCase().contains(q) ||
            s.stationId.toLowerCase().contains(q))
        .toList();
  }

  Color _aqiColor(double? aqi) {
    if (aqi == null) return const Color(0xFF94A3B8);
    if (aqi <= 50) return const Color(0xFF059669);
    if (aqi <= 100) return const Color(0xFF10B981);
    if (aqi <= 200) return const Color(0xFFD97706);
    if (aqi <= 300) return const Color(0xFFDC2626);
    if (aqi <= 400) return const Color(0xFF9333EA);
    return const Color(0xFF7E22CE);
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return Container(
      height: screenH * 0.82,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ─── Handle bar
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ─── Title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.location_on, color: AppTheme.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Select Location',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          // ─── Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                _tabBtn('Delhi NCR Locations', 0),
                const SizedBox(width: 8),
                _tabBtn('AQI Stations', 1),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ─── Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: _tab == 0
                    ? 'Search place, area or type...'
                    : 'Search station name or area...',
                hintStyle:
                    const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search,
                    color: AppTheme.textMuted, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            size: 16, color: AppTheme.textMuted),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),

          // ─── List
          Expanded(
            child: _tab == 0 ? _buildLocationsList() : _buildStationsList(),
          ),
        ],
      ),
    );
  }

  Widget _tabBtn(String label, int idx) {
    final isActive = _tab == idx;
    return GestureDetector(
      onTap: () => setState(() {
        _tab = idx;
        _query = '';
        _searchCtrl.clear();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primary.withValues(alpha: 0.15)
              : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? AppTheme.primary : AppTheme.border,
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AppTheme.primary : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildLocationsList() {
    final items = _filteredLocations;
    if (items.isEmpty) {
      return const Center(
        child: Text('No locations found',
            style: TextStyle(color: AppTheme.textMuted)),
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppTheme.border),
      itemBuilder: (ctx, i) {
        final loc = items[i];
        return ListTile(
          dense: true,
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border),
            ),
            child: const Icon(Icons.place,
                color: Color(0xFF10B981), size: 18),
          ),
          title: Text(
            loc.name,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '${loc.area} • ${loc.category}',
            style: const TextStyle(
                color: AppTheme.textMuted, fontSize: 11),
          ),
          onTap: () => Navigator.pop(ctx, loc.name),
        );
      },
    );
  }

  Widget _buildStationsList() {
    final items = _filteredStations;
    if (items.isEmpty) {
      return const Center(
        child: Text('No stations found',
            style: TextStyle(color: AppTheme.textMuted)),
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppTheme.border),
      itemBuilder: (ctx, i) {
        final s = items[i];
        final color = _aqiColor(s.aqi);
        return ListTile(
          dense: true,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black26, width: 1.5),
            ),
            child: Center(
              child: Text(
                s.aqi != null ? s.aqi!.round().toString() : '—',
                style: TextStyle(
                  color: (s.aqi ?? 0) > 150 ? Colors.white : Colors.black87,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          title: Text(
            s.stationName,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '${s.aqiBucket ?? s.stationId} • ${s.latitude.toStringAsFixed(3)}, ${s.longitude.toStringAsFixed(3)}',
            style: const TextStyle(
                color: AppTheme.textMuted, fontSize: 11),
          ),
          // Return coord string for station selection
          onTap: () => Navigator.pop(
              ctx, '${s.latitude},${s.longitude}'),
        );
      },
    );
  }
}
