import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/station.dart';
import '../models/route_model.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'map_screen.dart';
import 'route_search_screen.dart';
import 'forecast_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final ApiService _api = ApiService();

  int _currentTabIndex = 0;
  List<Station> _stations = [];
  Station? _selectedStation;
  List<RouteItem> _routes = [];
  int _activeRouteIndex = 0;
  RouteComparisonResult? _lastRouteResult;
  bool _loadingRoutes = false;
  bool _loadingStations = true;
  double? _spotAQI;
  LatLng? _userLocation;

  UserProfile _userProfile = UserProfile(
    id: 'user_default',
    name: 'Delhi Commuter',
    healthCategory: HealthCategory.normal,
    customThreshold: 250,
    effectiveThreshold: 250,
  );

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _loadingStations = true);
    try {
      final stations = await _api.getStations();
      setState(() {
        _stations = stations;
        if (stations.isNotEmpty) {
          _selectedStation = stations.firstWhere(
            (s) => s.stationId == 'DL014', // Default to central Anand Vihar or CP
            orElse: () => stations.first,
          );
        }
        _loadingStations = false;
      });

      // Run default route evaluation for Delhi commuters
      _evaluateRoutes(
        'Connaught Place, New Delhi',
        'Indira Gandhi International Airport (T3), Delhi',
      );

      // Perform default central Delhi spot AQI check
      _checkPosition(28.6139, 77.2090);
    } catch (e) {
      setState(() => _loadingStations = false);
    }
  }

  Future<void> _checkPosition(double lat, double lng) async {
    try {
      final res = await _api.checkPositionAQI(lat, lng, userId: _userProfile.id);
      final aqi = (res['interpolated']?['aqi'] as num?)?.toDouble();
      setState(() {
        _spotAQI = aqi;
        _userLocation = LatLng(lat, lng);
      });
    } catch (_) {}
  }

  Future<void> _evaluateRoutes(String origin, String dest) async {
    setState(() => _loadingRoutes = true);
    try {
      final res = await _api.compareRoutes(origin, dest, userId: _userProfile.id);
      setState(() {
        _lastRouteResult = res;
        _routes = res.routes;
        _activeRouteIndex = res.safestRouteIndex;
        _loadingRoutes = false;
      });
    } catch (e) {
      setState(() => _loadingRoutes = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Route calculation error: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      RouteSearchScreen(
        routes: _routes,
        activeRouteIndex: _activeRouteIndex,
        onSelectRoute: (idx) {
          setState(() => _activeRouteIndex = idx);
        },
        onSearch: _evaluateRoutes,
        isLoading: _loadingRoutes,
        lastResult: _lastRouteResult,
        stations: _stations,
        onNavigateToFullMap: () => setState(() => _currentTabIndex = 1),
      ),
      MapScreen(
        stations: _stations,
        selectedStation: _selectedStation,
        onStationSelect: (st) => setState(() => _selectedStation = st),
        routes: _routes,
        activeRouteIndex: _activeRouteIndex,
        onRouteSelect: (idx) => setState(() => _activeRouteIndex = idx),
        onNavigateToForecast: () => setState(() => _currentTabIndex = 2),
        onRefresh: _loadInitialData,
        onSearch: _evaluateRoutes,
        isLoading: _loadingStations,
        loadingRoutes: _loadingRoutes,
        spotAQI: _spotAQI,
        userLocation: _userLocation,
        lastRouteResult: _lastRouteResult,
      ),
      ForecastScreen(
        stations: _stations,
        selectedStation: _selectedStation,
        onStationSelect: (st) => setState(() => _selectedStation = st),
      ),
      ProfileScreen(
        profile: _userProfile,
        onProfileUpdate: (updated) => setState(() => _userProfile = updated),
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentTabIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (idx) => setState(() => _currentTabIndex = idx),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.alt_route_outlined),
            activeIcon: Icon(Icons.alt_route),
            label: 'Route Optimizer',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Live Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights_outlined),
            activeIcon: Icon(Icons.insights),
            label: 'AI Forecast',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Health Profile',
          ),
        ],
      ),
    );
  }
}
