import 'package:flutter/material.dart';
import '../models/route_model.dart';
import '../theme/app_theme.dart';
import '../theme/aqi_colors.dart';
import 'aqi_badge.dart';

class RouteCard extends StatelessWidget {
  final RouteItem route;
  final bool isSelected;
  final VoidCallback onSelect;

  const RouteCard({
    super.key,
    required this.route,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final aqiColor = AQIColors.getColor(route.averageAqi);

    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.surfaceLight : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (route.isSafest ? AppTheme.primary : AppTheme.accent)
                : AppTheme.border,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (route.isSafest ? AppTheme.primary : AppTheme.accent)
                        .withValues(alpha: 0.2),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Badges & Route Index
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (route.isSafest)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.primary, width: 1),
                        ),
                        child: const Row(
                          children: [
                            Text('🌿 ', style: TextStyle(fontSize: 12)),
                            Text(
                              'Cleanest Corridor',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(
                          'Route ${route.routeIndex + 1}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (route.exposureReductionPct != null && route.exposureReductionPct! > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '-${route.exposureReductionPct!.round()}% Exposure',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                AQIBadge(aqi: route.averageAqi, size: 36, showLabel: false),
              ],
            ),
            const SizedBox(height: 10),

            // Route Summary
            Text(
              route.summary.isNotEmpty ? route.summary : 'Delhi Transit Corridor',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),

            // Metric Row: Time, Distance, Exposure
            Row(
              children: [
                Expanded(
                  child: _metricColumn(
                    'Time',
                    '${(route.durationInTrafficMinutes ?? route.totalDurationMinutes).round()} min',
                    Icons.timer_outlined,
                  ),
                ),
                Container(width: 1, height: 32, color: AppTheme.border),
                Expanded(
                  child: _metricColumn(
                    'Distance',
                    '${route.totalDistanceKm.toStringAsFixed(1)} km',
                    Icons.directions_car_outlined,
                  ),
                ),
                Container(width: 1, height: 32, color: AppTheme.border),
                Expanded(
                  child: _metricColumn(
                    'Avg AQI',
                    route.averageAqi.round().toString(),
                    Icons.air_outlined,
                    valueColor: aqiColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Advisory / Reasoning Snippet
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      route.practicalReasoning ?? route.healthAdvisory,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricColumn(String label, String value, IconData icon, {Color? valueColor}) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: AppTheme.textMuted),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
