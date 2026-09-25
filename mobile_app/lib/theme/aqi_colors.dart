import 'package:flutter/material.dart';

class AQIColors {
  static const Color good = Color(0xFF10B981); // 0-50
  static const Color satisfactory = Color(0xFF84CC16); // 51-100
  static const Color moderate = Color(0xFFEAB308); // 101-200
  static const Color poor = Color(0xFFF97316); // 201-300
  static const Color veryPoor = Color(0xFFEF4444); // 301-400
  static const Color severe = Color(0xFF991B1B); // 401+

  static Color getColor(double? aqi) {
    if (aqi == null) return const Color(0xFF94A3B8);
    if (aqi <= 50) return good;
    if (aqi <= 100) return satisfactory;
    if (aqi <= 200) return moderate;
    if (aqi <= 300) return poor;
    if (aqi <= 400) return veryPoor;
    return severe;
  }

  static String getLabel(double? aqi) {
    if (aqi == null) return 'No Data';
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Satisfactory';
    if (aqi <= 200) return 'Moderate';
    if (aqi <= 300) return 'Poor';
    if (aqi <= 400) return 'Very Poor';
    return 'Severe';
  }

  static String getAdvisory(double? aqi) {
    if (aqi == null) return 'Air quality data currently unavailable.';
    if (aqi <= 50) return 'Minimal impact. Ideal for outdoor activity and commute.';
    if (aqi <= 100) return 'Minor breathing discomfort to sensitive people.';
    if (aqi <= 200) return 'Breathing discomfort to people with lungs, asthma, and heart diseases.';
    if (aqi <= 300) return 'Breathing discomfort to most people on prolonged exposure. Wear a mask.';
    if (aqi <= 400) return 'Respiratory illness on prolonged exposure. Avoid prolonged outdoor exertion.';
    return 'Severe health impact. Healthy people affected; serious impacts on vulnerable groups. Stay indoors!';
  }
}
