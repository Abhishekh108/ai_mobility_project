import 'package:flutter/material.dart';
import '../models/station.dart';
import '../theme/app_theme.dart';

class PollutantGrid extends StatelessWidget {
  final StationReadings readings;

  const PollutantGrid({super.key, required this.readings});

  Widget _buildItem(String label, double? val, String unit, double safeLimit) {
    final hasVal = val != null && !val.isNaN;
    final isElevated = hasVal && val > safeLimit;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isElevated ? AppTheme.warning.withValues(alpha: 0.5) : AppTheme.border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isElevated)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'High',
                    style: TextStyle(
                      color: AppTheme.warning,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                hasVal ? val.toStringAsFixed(1) : '—',
                style: TextStyle(
                  color: isElevated ? AppTheme.warning : AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.35,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildItem('PM2.5', readings.pm25, 'µg/m³', 60.0),
        _buildItem('PM10', readings.pm10, 'µg/m³', 100.0),
        _buildItem('NO₂', readings.no2, 'µg/m³', 80.0),
        _buildItem('SO₂', readings.so2, 'µg/m³', 80.0),
        _buildItem('CO', readings.co, 'mg/m³', 2.0),
        _buildItem('O₃', readings.o3, 'µg/m³', 100.0),
      ],
    );
  }
}
