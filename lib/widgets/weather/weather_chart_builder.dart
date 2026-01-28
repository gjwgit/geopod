/// Chart widget builders for weather data visualization.
///
// Time-stamp: <Sunday 2026-01-26 12:00:00 +1100>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';

import 'weather_chart_dual_painter.dart';
import 'weather_chart_painter.dart';

/// Build a dual-line chart widget.
Widget buildDualLineChart({
  required Map<DateTime, double> chartMaxData,
  required Map<DateTime, double> chartMinData,
  required double dataMin,
  required double dataMax,
  required String dataType,
}) {
  // Handle flat data: if max == min for all points, don't draw chart
  final allFlat =
      chartMaxData.values.every((v) => v == dataMax) &&
      chartMinData.values.every((v) => v == dataMin) &&
      dataMax == dataMin;

  if (allFlat) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Text(
          'No variation in data',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ),
    );
  }

  return SizedBox(
    height: 200,
    child: CustomPaint(
      painter: WeatherChartDualPainter(
        dailyMaxValues: chartMaxData,
        dailyMinValues: chartMinData,
        minValue: dataMin,
        maxValue: dataMax,
        maxColor: Colors.red,
        minColor: Colors.blue,
      ),
      size: const Size(double.infinity, 200),
    ),
  );
}

/// Build a simple single-line chart widget.
Widget buildSimpleChart({
  required Map<DateTime, double> chartData,
  required double dataMin,
  required double dataMax,
  required String dataType,
}) {
  // Determine color based on data type
  Color lineColor = Colors.blue; // Default color
  if (dataType == 'humidity') {
    lineColor = Colors.red; // Red for humidity
  } else if (dataType == 'precipitation') {
    lineColor = Colors.blue; // Blue for precipitation
  }

  return SizedBox(
    height: 200,
    child: CustomPaint(
      painter: WeatherChartPainter(
        dailyAverages: chartData,
        minValue: dataMin,
        maxValue: dataMax,
        color: lineColor,
      ),
      size: const Size(double.infinity, 200),
    ),
  );
}
