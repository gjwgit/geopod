/// Helper functions for weather chart data type handling.
///
// Time-stamp: <Tuesday 2026-01-14 10:00:00 +1100>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';

import '../../models/hourly_weather_data.dart';

/// Get data range based on data type.
(double, double) getDataRange(String dataType, HourlyWeatherData data) {
  switch (dataType) {
    case 'humidity':
      return data.getHumidityRange();
    case 'wind_speed':
      return data.getWindSpeedRange();
    case 'precipitation':
      return data.getPrecipitationRange();
    case 'temperature':
    default:
      return data.getTemperatureRange();
  }
}

/// Get daily data based on data type.
Map<DateTime, double> getDailyData(String dataType, HourlyWeatherData data) {
  switch (dataType) {
    case 'humidity':
      return data.getDailyAverageHumidity();
    case 'wind_speed':
      return data.getDailyAverageWindSpeed();
    case 'precipitation':
      return data.getDailyAveragePrecipitation();
    case 'temperature':
    default:
      return data.getDailyAverages();
  }
}

/// Get data title based on data type.
String getDataTitle(String dataType) {
  switch (dataType) {
    case 'humidity':
      return 'Humidity Range';
    case 'wind_speed':
      return 'Wind Speed Range';
    case 'precipitation':
      return 'Precipitation Range';
    case 'temperature':
    default:
      return 'Temperature Range';
  }
}

/// Get data unit based on data type.
String getDataUnit(String dataType) {
  switch (dataType) {
    case 'humidity':
      return '%';
    case 'wind_speed':
      return ' km/h';
    case 'precipitation':
      return ' mm';
    case 'temperature':
    default:
      return '°C';
  }
}

/// Get data icon based on data type.
IconData getDataIcon(String dataType) {
  switch (dataType) {
    case 'humidity':
      return Icons.water_drop;
    case 'wind_speed':
      return Icons.air;
    case 'precipitation':
      return Icons.umbrella;
    case 'temperature':
    default:
      return Icons.thermostat;
  }
}

/// Get color based on value position in range.
Color getValueColor(double value, double min, double max) {
  final range = max - min;
  if (range == 0) return Colors.blue;

  final normalized = (value - min) / range;

  if (normalized < 0.33) {
    return Colors.blue[700]!;
  } else if (normalized < 0.67) {
    return Colors.orange[700]!;
  } else {
    return Colors.red[700]!;
  }
}
