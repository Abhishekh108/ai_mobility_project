import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/station.dart';
import '../models/route_model.dart';
import '../theme/app_theme.dart';
import '../utils/polyline_decoder.dart';
import '../widgets/station_bottom_sheet.dart';

// ─── AQI color helper ─────────────────────────────────────────────────────────
Color _aqiColor(double? aqi) {
  if (aqi == null) return const Color(0xFF94A3B8);
  if (aqi <= 50) return const Color(0xFF059669);
  if (aqi <= 100) return const Color(0xFF10B981);
  if (aqi <= 200) return const Color(0xFFD97706);
  if (aqi <= 300) return const Color(0xFFDC2626);
  if (aqi <= 400) return const Color(0xFF9333EA);
  return const Color(0xFF7E22CE);
}

String _aqiLabel(double? aqi) {
  if (aqi == null) return 'N/A';
  if (aqi <= 50) return 'Good';
  if (aqi <= 100) return 'Satisfactory';
  if (aqi <= 200) return 'Moderate';
  if (aqi <= 300) return 'Poor';
  if (aqi <= 400) return 'Very Poor';
  return 'Severe';
}

// ─── Route color by index ─────────────────────────────────────────────────────
const List<Color> _routeColors = [
  Color(0xFF3B82F6), // blue – active/safest
  Color(0xFFF59E0B), // amber – alt 1
  Color(0xFF8B5CF6), // purple – alt 2
];

class MapScreen extends StatefulWidget {
  final List<Station> stations;
  final Station? selectedStation;
  final Function(Station) onStationSelect;
  final List<RouteItem> routes;
  final int activeRouteIndex;
  final Function(int) onRouteSelect;
  final VoidCallback onNavigateToForecast;
  final VoidCallback onRefresh;
  final bool isLoading;
  final double? spotAQI;
  final LatLng? userLocation;
  final Future<void> Function(String origin, String destination) onSearch;
  final bool loadingRoutes;
  final RouteComparisonResult? lastRouteResult;

  const MapScreen({
    super.key,
    required this.stations,
    this.selectedStation,
    required this.onStationSelect,
    required this.routes,
    required this.activeRouteIndex,
    required this.onRouteSelect,
    required this.onNavigateToForecast,
    required this.onRefresh,
    required this.onSearch,
    this.isLoading = false,
    this.loadingRoutes = false,
    this.spotAQI,
    this.userLocation,
    this.lastRouteResult,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  static const LatLng _delhiCenter = LatLng(28.6139, 77.2090);

  bool _showStations = true;
  bool _showSearch = false;
  double _currentZoom = 11.2;

  final _originCtrl = TextEditingController(text: 'Connaught Place, New Delhi');
  final _destCtrl = TextEditingController(
      text: 'Indira Gandhi International Airport (T3), Delhi');

  final List<Map<String, String>> _presets = [
    {'label': 'CP → IGI', 'from': 'Connaught Place, New Delhi', 'to': 'Indira Gandhi International Airport (T3), Delhi'},
    {'label': 'Noida 62 → CP', 'from': 'Noida Sector 62, Uttar Pradesh', 'to': 'Connaught Place, New Delhi'},
    {'label': 'Rohini → Nehru', 'from': 'Rohini, New Delhi', 'to': 'Nehru Place, New Delhi'},
    {'label': 'Dwarka → AKS', 'from': 'Dwarka Sector 21, New Delhi', 'to': 'Akshardham Temple, New Delhi'},
    {'label': 'AV → CyberCity', 'from': 'Anand Vihar, Delhi', 'to': 'Cyber City, Gurugram'},
  ];

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }

  // ── Fit the map to show the selected route ────────────────────────────────
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
    final padLat = (maxLat - minLat).abs() * 0.25;
    final padLng = (maxLng - minLng).abs() * 0.15;
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
          padding: const EdgeInsets.all(32),
        ),
      );
    } catch (_) {}
  }


  void _doSearch() {
    final o = _originCtrl.text.trim();
    final d = _destCtrl.text.trim();
    if (o.isEmpty || d.isEmpty) return;
    setState(() => _showSearch = false);
    widget.onSearch(o, d);
  }

  void _swap() {
    final t = _originCtrl.text;
    _originCtrl.text = _destCtrl.text;
    _destCtrl.text = t;
  }

  // ── Build all polyline layers (inactive first → active on top) ───────────
  List<Polyline> _buildPolylines() {
    final result = <Polyline>[];
    // Draw inactive routes first so they sit underneath
    for (int i = 0; i < widget.routes.length; i++) {
      if (i == widget.activeRouteIndex) continue;
      final r = widget.routes[i];
      if (r.polylineEncoded.isEmpty) continue;
      final pts = PolylineDecoder.decode(r.polylineEncoded);
      if (pts.isEmpty) continue;
      final color = _routeColors[i % _routeColors.length];
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
          final color = _routeColors[i % _routeColors.length];
          // Dark casing / shadow
          result.add(Polyline(
            points: pts,
            strokeWidth: 9.5,
            color: Colors.black.withValues(alpha: 0.45),
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

  // ── Origin / Destination points from active route ─────────────────────────
  (LatLng?, LatLng?) _getODPoints() {
    if (widget.routes.isEmpty) return (null, null);
    final r = widget.routes[widget.activeRouteIndex];
    if (r.polylineEncoded.isEmpty) return (null, null);
    final pts = PolylineDecoder.decode(r.polylineEncoded);
    if (pts.isEmpty) return (null, null);
    return (pts.first, pts.last);
  }

  @override
  Widget build(BuildContext context) {
    final (originPt, destPt) = _getODPoints();
    final hasRoutes = widget.routes.isNotEmpty;

    // auto-fit when routes arrive
    if (hasRoutes) {
      final r = widget.routes[widget.activeRouteIndex];
      if (r.polylineEncoded.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fitRoute(PolylineDecoder.decode(r.polylineEncoded));
        });
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          // ══════════════════════════════════════════════
          //  MAP LAYER
          // ══════════════════════════════════════════════
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _delhiCenter,
              initialZoom: _currentZoom,
              minZoom: 8.0,
              maxZoom: 18.0,
              onPositionChanged: (pos, _) {
                setState(() => _currentZoom = pos.zoom);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.aimobility.app',
                maxZoom: 19,
              ),

              // All route polylines
              PolylineLayer(polylines: _buildPolylines()),

              // Markers layer
              MarkerLayer(
                markers: [
                  // AQI station dots
                  if (_showStations)
                    ...widget.stations.map((s) {
                      final color = _aqiColor(s.aqi);
                      final isSel =
                          widget.selectedStation?.stationId == s.stationId;
                      return Marker(
                        point: LatLng(s.latitude, s.longitude),
                        width: isSel ? 48 : 36,
                        height: isSel ? 48 : 36,
                        child: GestureDetector(
                          onTap: () {
                            widget.onStationSelect(s);
                            _showStationSheet(s);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel ? Colors.white : Colors.black54,
                                width: isSel ? 2.5 : 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.55),
                                  blurRadius: isSel ? 12 : 4,
                                  spreadRadius: isSel ? 2 : 0,
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
                                  fontSize: isSel ? 11 : 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                  // User location
                  if (widget.userLocation != null)
                    Marker(
                      point: widget.userLocation!,
                      width: 22,
                      height: 22,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6),
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white, width: 2.5),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0xFF3B82F6), blurRadius: 10),
                          ],
                        ),
                      ),
                    ),

                  // Origin marker (green dot)
                  if (originPt != null)
                    Marker(
                      point: originPt,
                      width: 28,
                      height: 28,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x6610B981), blurRadius: 8),
                          ],
                        ),
                        child: const Icon(Icons.my_location,
                            color: Colors.white, size: 14),
                      ),
                    ),

                  // Destination marker (red pin)
                  if (destPt != null)
                    Marker(
                      point: destPt,
                      width: 32,
                      height: 40,
                      child: const Column(
                        children: [
                          Icon(Icons.location_on,
                              color: Color(0xFFEF4444), size: 32),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),

          // ══════════════════════════════════════════════
          //  TOP BAR
          // ══════════════════════════════════════════════
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Title chip
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _showSearch = !_showSearch),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.surface.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black26, blurRadius: 8),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search,
                                size: 16, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                hasRoutes
                                    ? '${_originCtrl.text.split(',').first} → ${_destCtrl.text.split(',').first}'
                                    : 'Search cleanest route…',
                                style: TextStyle(
                                  color: hasRoutes
                                      ? AppTheme.textPrimary
                                      : AppTheme.textMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              _showSearch
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 18,
                              color: AppTheme.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // AQI stations toggle
                  _fab(
                    icon: _showStations
                        ? Icons.location_on
                        : Icons.location_off,
                    color: _showStations
                        ? AppTheme.primary
                        : AppTheme.textMuted,
                    tooltip:
                        _showStations ? 'Hide AQI Stations' : 'Show AQI Stations',
                    onTap: () =>
                        setState(() => _showStations = !_showStations),
                  ),

                  const SizedBox(width: 6),
                  // Refresh
                  _fab(
                    icon: Icons.refresh,
                    color: AppTheme.textSecondary,
                    tooltip: 'Refresh',
                    onTap: widget.onRefresh,
                  ),
                ],
              ),
            ),
          ),

          // ══════════════════════════════════════════════
          //  SEARCH DROPDOWN PANEL
          // ══════════════════════════════════════════════
          if (_showSearch)
            Positioned(
              top: MediaQuery.of(context).padding.top + 64,
              left: 12,
              right: 12,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 20),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Origin / Destination inputs
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Dot connector
                          Column(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Container(
                                width: 2,
                                height: 32,
                                color: AppTheme.border,
                              ),
                              const Icon(Icons.location_on,
                                  color: Color(0xFFEF4444), size: 16),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              children: [
                                _searchField(
                                    ctrl: _originCtrl, label: 'Origin'),
                                const SizedBox(height: 8),
                                _searchField(
                                    ctrl: _destCtrl,
                                    label: 'Destination'),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.swap_vert,
                                color: AppTheme.textSecondary),
                            onPressed: _swap,
                            tooltip: 'Swap',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Quick presets
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _presets.map((p) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                backgroundColor: AppTheme.surfaceLight,
                                side: const BorderSide(
                                    color: AppTheme.border),
                                label: Text(
                                  p['label']!,
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 11.5),
                                ),
                                onPressed: () {
                                  _originCtrl.text = p['from']!;
                                  _destCtrl.text = p['to']!;
                                  setState(() => _showSearch = false);
                                  widget.onSearch(p['from']!, p['to']!);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Search button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              widget.loadingRoutes ? null : _doSearch,
                          icon: widget.loadingRoutes
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black),
                                )
                              : const Icon(Icons.search,
                                  color: Colors.black, size: 18),
                          label: Text(
                            widget.loadingRoutes
                                ? 'Calculating routes…'
                                : 'Find Cleanest Route',
                            style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ══════════════════════════════════════════════
          //  LOADING ROUTES OVERLAY
          // ══════════════════════════════════════════════
          if (widget.loadingRoutes)
            Positioned(
              top: MediaQuery.of(context).padding.top + 68,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 12)
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primary),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Calculating Spatial Exposure…',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ══════════════════════════════════════════════
          //  RIGHT-SIDE ZOOM CONTROLS
          // ══════════════════════════════════════════════
          Positioned(
            right: 12,
            bottom: hasRoutes ? 230 : 120,
            child: Column(
              children: [
                _mapBtn(
                  icon: Icons.add,
                  onTap: () {
                    final z = (_currentZoom + 1).clamp(8.0, 18.0);
                    _mapController.move(_mapController.camera.center, z);
                    setState(() => _currentZoom = z);
                  },
                ),
                const SizedBox(height: 6),
                _mapBtn(
                  icon: Icons.remove,
                  onTap: () {
                    final z = (_currentZoom - 1).clamp(8.0, 18.0);
                    _mapController.move(_mapController.camera.center, z);
                    setState(() => _currentZoom = z);
                  },
                ),
                const SizedBox(height: 6),
                _mapBtn(
                  icon: Icons.my_location,
                  onTap: () {
                    _mapController.move(_delhiCenter, 11.2);
                    setState(() => _currentZoom = 11.2);
                  },
                ),
              ],
            ),
          ),

          // ══════════════════════════════════════════════
          //  BOTTOM ROUTE CARDS  (matching web app style)
          // ══════════════════════════════════════════════
          if (hasRoutes)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(
                      top: BorderSide(color: AppTheme.border, width: 1)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black54,
                        blurRadius: 24,
                        offset: Offset(0, -4)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 8),
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Analyzed Corridors (${widget.routes.length})',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Row(
                            children: [
                              Text('🌿 ',
                                  style: TextStyle(fontSize: 12)),
                              Text(
                                'Spatial IDW Optimized',
                                style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Route cards – horizontal scroll
                    SizedBox(
                      height: 140,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: widget.routes.length,
                        itemBuilder: (ctx, i) =>
                            _routeCard(i, widget.routes[i]),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ══════════════════════════════════════════════
          //  AQI LEGEND  (bottom-right, above route panel)
          // ══════════════════════════════════════════════
          if (!hasRoutes)
            Positioned(
              right: 12,
              bottom: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withValues(alpha: 0.93),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'CPCB Air Quality Index',
                      style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Color(0xFF059669),
                        const Color(0xFF10B981),
                        const Color(0xFFD97706),
                        const Color(0xFFDC2626),
                        const Color(0xFF9333EA),
                        const Color(0xFF7E22CE),
                      ]
                          .map((c) => Container(
                                width: 22,
                                height: 8,
                                color: c,
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 3),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('0',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 8)),
                        Text('100',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 8)),
                        Text('200',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 8)),
                        Text('400+',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 8)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Spot AQI badge
          if (widget.spotAQI != null && !hasRoutes)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withValues(alpha: 0.93),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _aqiColor(widget.spotAQI),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Delhi AQI ${widget.spotAQI!.round()} · ${_aqiLabel(widget.spotAQI)}',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Route card widget ──────────────────────────────────────────────────────
  Widget _routeCard(int idx, RouteItem r) {
    final isSafest = r.isSafest;
    final isActive = idx == widget.activeRouteIndex;
    final color = _routeColors[idx % _routeColors.length];
    final timeMins = (r.durationInTrafficMinutes ?? r.totalDurationMinutes)
        .round();

    return GestureDetector(
      onTap: () {
        widget.onRouteSelect(idx);
        // Fit map to newly selected route
        if (r.polylineEncoded.isNotEmpty) {
          _fitRoute(PolylineDecoder.decode(r.polylineEncoded));
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 200,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.12) : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? color : AppTheme.border,
            width: isActive ? 2.0 : 1.0,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                      color: color.withValues(alpha: 0.25), blurRadius: 10)
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Route label row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isSafest ? '🌿 Eco-Shield' : 'Option ${idx + 1}',
                      style: TextStyle(
                        color: isSafest ? const Color(0xFF10B981) : AppTheme.textPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (isActive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Active',
                      style: TextStyle(
                          color: color,
                          fontSize: 9,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),

            // Time + distance
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$timeMins',
                  style: TextStyle(
                    color: isActive ? color : AppTheme.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 3),
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text('min',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11)),
                ),
                const Spacer(),
                Text(
                  '${r.totalDistanceKm.toStringAsFixed(1)} km',
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),

            // AQI and Exposure chips
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _chip(
                    'AQI ${r.averageAqi.round()}',
                    _aqiColor(r.averageAqi).withValues(alpha: 0.18),
                    _aqiColor(r.averageAqi)),
                if (r.exposureReductionPct != null &&
                    r.exposureReductionPct! > 0)
                  _chip('-${r.exposureReductionPct!.round()}% PM2.5',
                      const Color(0x2210B981), const Color(0xFF10B981)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style:
              TextStyle(color: fg, fontSize: 9.5, fontWeight: FontWeight.w700)),
    );
  }

  // ─── Floating action button (top bar) ────────────────────────────────────
  Widget _fab({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.95),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.border),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 6)
            ],
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  // ─── Zoom/center map button ───────────────────────────────────────────────
  Widget _mapBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
        child: Icon(icon, size: 18, color: AppTheme.textPrimary),
      ),
    );
  }

  // ─── Search text field ────────────────────────────────────────────────────
  Widget _searchField(
      {required TextEditingController ctrl, required String label}) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
            color: AppTheme.textMuted, fontSize: 12),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        filled: true,
        fillColor: AppTheme.cardColor,
      ),
    );
  }

  // ─── Station bottom sheet ─────────────────────────────────────────────────
  void _showStationSheet(Station s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StationBottomSheet(
        station: s,
        onForecastPressed: widget.onNavigateToForecast,
      ),
    );
  }
}
