import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/station.dart';
import '../models/prediction.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../theme/aqi_colors.dart';
import '../widgets/aqi_badge.dart';
import '../widgets/pollutant_grid.dart';

class ForecastScreen extends StatefulWidget {
  final List<Station> stations;
  final Station? selectedStation;
  final Function(Station) onStationSelect;

  const ForecastScreen({
    super.key,
    required this.stations,
    this.selectedStation,
    required this.onStationSelect,
  });

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  final ApiService _api = ApiService();
  StationPrediction? _prediction;
  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.selectedStation != null) {
      _loadForecast(widget.selectedStation!.stationId);
    } else if (widget.stations.isNotEmpty) {
      _loadForecast(widget.stations.first.stationId);
    }
  }

  @override
  void didUpdateWidget(covariant ForecastScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedStation?.stationId != oldWidget.selectedStation?.stationId &&
        widget.selectedStation != null) {
      _loadForecast(widget.selectedStation!.stationId);
    }
  }

  Future<void> _loadForecast(String stationId) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final pred = await _api.predictAQI(stationId, hoursAhead: 24);
      setState(() {
        _prediction = pred;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = 'Could not load neural forecast: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeStation = widget.selectedStation ??
        (widget.stations.isNotEmpty ? widget.stations.first : null);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.show_chart, color: AppTheme.primary, size: 22),
            SizedBox(width: 8),
            Text('24-Hour Neural LSTM Forecast'),
          ],
        ),
      ),
      body: activeStation == null
          ? const Center(child: Text('No stations available'))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // Station Selector Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Delhi Monitoring Station',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: activeStation.stationId,
                          isExpanded: true,
                          dropdownColor: AppTheme.surface,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primary),
                          items: widget.stations.map((s) {
                            return DropdownMenuItem<String>(
                              value: s.stationId,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      s.stationName,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  AQIBadge(aqi: s.aqi, size: 28, showLabel: false),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val == null) return;
                            final st = widget.stations.firstWhere((s) => s.stationId == val);
                            widget.onStationSelect(st);
                            _loadForecast(st.stationId);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Active Station Overview Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeStation.stationName,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Station ID: ${activeStation.stationId}',
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          AQIBadge(aqi: activeStation.aqi, size: 40),
                        ],
                      ),
                      const SizedBox(height: 14),
                      PollutantGrid(readings: activeStation.readings),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 24-Hour Forecast Chart Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '24-Hour Forecast Trend',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Trained Deep LSTM with Temporal Attention',
                                style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          if (_loading)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      if (_errorMessage != null)
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppTheme.error, fontSize: 12),
                        )
                      else if (_prediction != null && _prediction!.predictions.isNotEmpty)
                        SizedBox(
                          height: 200,
                          child: LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: 50,
                                getDrawingHorizontalLine: (v) => const FlLine(
                                  color: AppTheme.border,
                                  strokeWidth: 0.8,
                                ),
                              ),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 34,
                                    interval: 100,
                                    getTitlesWidget: (val, meta) => Text(
                                      val.toInt().toString(),
                                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                                    ),
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 22,
                                    interval: 4,
                                    getTitlesWidget: (val, meta) => Text(
                                      '+${val.toInt()}h',
                                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                                    ),
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: _prediction!.predictions.map((p) {
                                    return FlSpot(p.hourAhead.toDouble(), p.predictedAqi);
                                  }).toList(),
                                  isCurved: true,
                                  curveSmoothness: 0.35,
                                  color: AppTheme.primary,
                                  barWidth: 3,
                                  isStrokeCapRound: true,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      colors: [
                                        AppTheme.primary.withValues(alpha: 0.35),
                                        AppTheme.primary.withValues(alpha: 0.0),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        const SizedBox(
                          height: 180,
                          child: Center(
                            child: CircularProgressIndicator(color: AppTheme.primary),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Hourly Breakdown List
                if (_prediction != null && _prediction!.predictions.isNotEmpty) ...[
                  const Text(
                    'Hourly Forecast Breakdown',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 95,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _prediction!.predictions.length,
                      itemBuilder: (context, idx) {
                        final h = _prediction!.predictions[idx];
                        final col = AQIColors.getColor(h.predictedAqi);

                        return Container(
                          width: 86,
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '+${h.hourAhead} hrs',
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                h.predictedAqi.round().toString(),
                                style: TextStyle(
                                  color: col,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                h.bucket,
                                style: TextStyle(
                                  color: col,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
