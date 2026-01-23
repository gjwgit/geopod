/// Weather detail builders for weather dialog.
///
// Time-stamp: <Tuesday 2026-01-14 10:00:00 +1100>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.
///
/// Authors: Miduo

library;

import 'package:flutter/material.dart';

import '../../models/weather_data.dart';

/// Build a generic weather detail row.
Widget buildWeatherDetail({
  required IconData icon,
  required String label,
  required String value,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 24, color: Colors.grey[600]),
        const SizedBox(width: 16),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

/// Build wind direction detail with tooltip.
Widget buildWindDirectionDetail(WeatherData weather) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(Icons.navigation, size: 24, color: Colors.grey[600]),
        const SizedBox(width: 16),
        const Expanded(
          child: Text('Wind Direction', style: TextStyle(fontSize: 15)),
        ),
        Tooltip(
          message:
              '''Wind Direction: ${weather.windDirectionFullName}
Angle: ${weather.windDirection}° (clockwise from North)
Wind is blowing FROM the ${weather.windDirectionFullName.toLowerCase()}
Arrow shows where wind is blowing TO''',
          child: Row(
            children: [
              Text(
                weather.windDirectionArrow,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                weather.windDirectionDescription,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.info_outline, size: 16, color: Colors.grey[500]),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Build precipitation detail with hourly/daily toggle.
Widget buildPrecipitationDetail({
  required WeatherData weather,
  required bool showDailyPrecipitation,
  required VoidCallback onToggle,
}) {
  // API returns precipitation for the past hour (mm)
  // User can toggle to see today's accumulated total
  final precipValue = showDailyPrecipitation
      ? (weather.todayTotalPrecipitation ??
            weather.precipitation) // Today's total accumulated
      : weather.precipitation; // Past hour
  final unit = showDailyPrecipitation ? 'mm' : 'mm';

  return InkWell(
    onTap: onToggle,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.umbrella, size: 24, color: Colors.grey[600]),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [
                Text(
                  showDailyPrecipitation
                      ? 'Precipitation (Today Total)'
                      : 'Precipitation (Past Hour)',
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(width: 8),
                Icon(Icons.swap_horiz, size: 16, color: Colors.grey[400]),
              ],
            ),
          ),
          Text(
            '${precipValue.toStringAsFixed(1)} $unit',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

/// Build data type selector (temperature, humidity, wind, rain).
Widget buildDataTypeSelector({
  required String selectedDataType,
  required void Function(String) onSelectionChanged,
}) {
  return SegmentedButton<String>(
    segments: const [
      ButtonSegment<String>(
        value: 'temperature',
        label: Text('Temp'),
        icon: Icon(Icons.thermostat, size: 16),
      ),
      ButtonSegment<String>(
        value: 'humidity',
        label: Text('Humidity'),
        icon: Icon(Icons.water_drop, size: 16),
      ),
      ButtonSegment<String>(
        value: 'wind_speed',
        label: Text('Wind'),
        icon: Icon(Icons.air, size: 16),
      ),
      ButtonSegment<String>(
        value: 'precipitation',
        label: Text('Rain'),
        icon: Icon(Icons.umbrella, size: 16),
      ),
    ],
    selected: {selectedDataType},
    onSelectionChanged: (Set<String> newSelection) {
      onSelectionChanged(newSelection.first);
    },
  );
}
