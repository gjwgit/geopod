/// Daily weather data card widget.
///
// Time-stamp: <Friday 2026-01-24 10:00:00 +1100>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import 'weather_chart_config.dart';
import 'weather_chart_helpers.dart';

/// A card widget displaying daily weather data summary.
class WeatherDataCard extends StatelessWidget {
  const WeatherDataCard({
    required this.date,
    required this.avgValue,
    required this.dayMin,
    required this.dayMax,
    required this.dataMin,
    required this.dataMax,
    required this.dataType,
    this.precipitationHours,
    this.isToday = false,
    super.key,
  });

  final DateTime date;
  final double avgValue;
  final double dayMin;
  final double dayMax;
  final double dataMin;
  final double dataMax;
  final String dataType;
  final int? precipitationHours;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: dailyCardWidth,
      margin: const EdgeInsets.only(right: dailyCardSpacing),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      decoration: BoxDecoration(
        color: isToday
            ? Theme.of(context).colorScheme.primaryContainer
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: isToday
            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            DateFormat('MMM').format(date),
            style: TextStyle(fontSize: 9, color: Colors.grey[600]),
          ),
          Text(
            DateFormat('dd').format(date),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${avgValue.toStringAsFixed(1)}${getDataUnit(dataType)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: getValueColor(avgValue, dataMin, dataMax),
            ),
          ),
          const SizedBox(height: 2),
          // Show min/max or hours for precipitation
          if (dataType == 'precipitation') ...[
            // For precipitation: show hours with rain
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time, size: 10, color: Colors.grey[600]),
                const SizedBox(width: 2),
                Text(
                  '${precipitationHours ?? 0}h',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            // Show max hourly rate
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'max ',
                  style: TextStyle(fontSize: 8, color: Colors.grey[600]),
                ),
                Text(
                  '${dayMax.toStringAsFixed(1)}mm/h',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ),
          ] else ...[
            // For other data types: show min/max
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'min ',
                  style: TextStyle(fontSize: 8, color: Colors.grey[600]),
                ),
                Text(
                  dayMin.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'max ',
                  style: TextStyle(fontSize: 8, color: Colors.grey[600]),
                ),
                Text(
                  dayMax.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ),
          ],
          if (isToday)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Today',
                style: TextStyle(
                  fontSize: 8,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
