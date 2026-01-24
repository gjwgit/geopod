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

/// Widget displaying the min and max values of the data range.
class WeatherChartRangeIndicator extends StatelessWidget {
  const WeatherChartRangeIndicator({
    required this.dataMin,
    required this.dataMax,
    required this.unit,
    required this.icon,
    super.key,
  });

  final double dataMin;
  final double dataMax;
  final String unit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.blue[700]),
        const SizedBox(width: 4),
        Text(
          'Min: ${dataMin.toStringAsFixed(1)}$unit',
          style: TextStyle(fontSize: 12, color: Colors.blue[700]),
        ),
        const SizedBox(width: 16),
        Icon(icon, size: 16, color: Colors.red[700]),
        const SizedBox(width: 4),
        Text(
          'Max: ${dataMax.toStringAsFixed(1)}$unit',
          style: TextStyle(fontSize: 12, color: Colors.red[700]),
        ),
      ],
    );
  }
}
