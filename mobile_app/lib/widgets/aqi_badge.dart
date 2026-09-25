import 'package:flutter/material.dart';
import '../theme/aqi_colors.dart';

class AQIBadge extends StatelessWidget {
  final double? aqi;
  final bool showLabel;
  final double size;

  const AQIBadge({
    super.key,
    required this.aqi,
    this.showLabel = true,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final color = AQIColors.getColor(aqi);
    final label = AQIColors.getLabel(aqi);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size * 0.25,
        vertical: size * 0.15,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size * 0.22,
            height: size * 0.22,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: 4),
              ],
            ),
          ),
          SizedBox(width: size * 0.18),
          Text(
            aqi != null ? aqi!.round().toString() : '—',
            style: TextStyle(
              color: color,
              fontSize: size * 0.42,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          if (showLabel) ...[
            SizedBox(width: size * 0.15),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: size * 0.28,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
