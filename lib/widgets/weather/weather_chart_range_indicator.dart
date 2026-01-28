/// Weather chart data range indicator widget.
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

/// Widget displaying the min and max values of the data range with dates.
class WeatherChartRangeIndicator extends StatelessWidget {
  const WeatherChartRangeIndicator({
    required this.dataMin,
    required this.dataMax,
    this.minDate,
    this.maxDate,
    required this.unit,
    required this.icon,
    this.dataType,
    super.key,
  });

  final double dataMin;
  final double dataMax;
  final DateTime? minDate;
  final DateTime? maxDate;
  final String unit;
  final IconData icon;
  final String? dataType;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM');

    // For wind_speed, only show max wind (since it's max + average, not max + min)
    if (dataType == 'wind_speed') {
      return Row(
        children: [
          Icon(icon, size: 16, color: Colors.red[700]),
          const SizedBox(width: 4),
          Text(
            'Max Wind: ${dataMax.toStringAsFixed(1)}$unit',
            style: TextStyle(
              fontSize: 12,
              color: Colors.red[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (maxDate != null) ...[
            const SizedBox(width: 4),
            Text(
              '(${dateFormat.format(maxDate!)})',
              style: TextStyle(fontSize: 10, color: Colors.red[600]),
            ),
          ],
        ],
      );
    }

    // Determine label prefix based on data type
    String getLabel(bool isMax) {
      if (dataType == 'temperature') {
        return isMax ? 'Max Temp' : 'Min Temp';
      } else if (dataType == 'humidity') {
        return isMax ? 'Max Avg' : 'Min Avg';
      } else if (dataType == 'precipitation') {
        return isMax ? 'Max Total' : 'Min Total';
      }
      return isMax ? 'Max' : 'Min';
    }

    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.blue[700]),
        const SizedBox(width: 4),
        Text(
          '${getLabel(false)}: ${dataMin.toStringAsFixed(1)}$unit',
          style: TextStyle(
            fontSize: 12,
            color: Colors.blue[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        if (minDate != null) ...[
          const SizedBox(width: 4),
          Text(
            '(${dateFormat.format(minDate!)})',
            style: TextStyle(fontSize: 10, color: Colors.blue[600]),
          ),
        ],
        const SizedBox(width: 16),
        Icon(icon, size: 16, color: Colors.red[700]),
        const SizedBox(width: 4),
        Text(
          '${getLabel(true)}: ${dataMax.toStringAsFixed(1)}$unit',
          style: TextStyle(
            fontSize: 12,
            color: Colors.red[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        if (maxDate != null) ...[
          const SizedBox(width: 4),
          Text(
            '(${dateFormat.format(maxDate!)})',
            style: TextStyle(fontSize: 10, color: Colors.red[600]),
          ),
        ],
      ],
    );
  }
}
