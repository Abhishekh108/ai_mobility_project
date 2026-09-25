import 'package:flutter/material.dart';
import '../models/station.dart';
import '../theme/app_theme.dart';
import '../theme/aqi_colors.dart';
import 'aqi_badge.dart';
import 'pollutant_grid.dart';

class StationBottomSheet extends StatelessWidget {
  final Station station;
  final VoidCallback onForecastPressed;

  const StationBottomSheet({
    super.key,
    required this.station,
    required this.onForecastPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppTheme.border, width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Station Title & AQI
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.stationName,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Station ID: ${station.stationId} • Delhi CPCB',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              AQIBadge(aqi: station.aqi, size: 42),
            ],
          ),
          const SizedBox(height: 14),

          // Weather telemetry chip row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _weatherItem(
                  '${station.weather.temperature?.toStringAsFixed(1) ?? '—'}°C',
                  'Temp',
                  Icons.thermostat,
                ),
                Container(width: 1, height: 24, color: AppTheme.border),
                _weatherItem(
                  '${station.weather.humidity?.round() ?? '—'}%',
                  'Humidity',
                  Icons.water_drop_outlined,
                ),
                Container(width: 1, height: 24, color: AppTheme.border),
                _weatherItem(
                  '${station.weather.windSpeed?.toStringAsFixed(1) ?? '—'} km/h',
                  'Wind',
                  Icons.air,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Pollutant breakdown
          const Text(
            'Pollutant Concentrations',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          PollutantGrid(readings: station.readings),
          const SizedBox(height: 16),

          // Advisory message
          Text(
            AQIColors.getAdvisory(station.aqi),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),

          // Forecast Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onForecastPressed();
              },
              icon: const Icon(Icons.show_chart, color: Colors.black),
              label: const Text('View 24-Hour Neural LSTM Forecast'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weatherItem(String value, String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.accent),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
