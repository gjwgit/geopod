/// Custom painter for dual-line weather chart (e.g., max/min temperature).
///
// Time-stamp: <Sunday 2026-01-26 10:00:00 +1100>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'dart:math';

import 'package:flutter/material.dart';

/// Custom painter for temperature chart with max and min lines.
class WeatherChartDualPainter extends CustomPainter {
  WeatherChartDualPainter({
    required this.dailyMaxValues,
    required this.dailyMinValues,
    required this.minValue,
    required this.maxValue,
    required this.maxColor,
    required this.minColor,
  });

  final Map<DateTime, double> dailyMaxValues;
  final Map<DateTime, double> dailyMinValues;
  final double minValue;
  final double maxValue;
  final Color maxColor;
  final Color minColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (dailyMaxValues.isEmpty || dailyMinValues.isEmpty) return;

    final valueRange = maxValue - minValue;
    if (valueRange == 0) return;

    final maxEntries = dailyMaxValues.entries.toList();
    final minEntries = dailyMinValues.entries.toList();

    // Reserve space for Y-axis labels (40px on left)
    final chartLeft = 40.0;
    final chartWidth = size.width - chartLeft;
    final xStep = chartWidth / (maxEntries.length - 1);

    // Draw Y-axis grid lines and labels
    _drawYAxisAndGrid(canvas, size, chartLeft);

    // Reserve space for X-axis labels at bottom
    final chartHeight = size.height - 20; // Reserve 20px for X-axis labels

    // Draw max temperature line
    _drawCurveLine(
      canvas,
      maxEntries,
      chartLeft,
      chartHeight,
      xStep,
      maxColor,
      valueRange,
    );

    // Draw min temperature line
    _drawCurveLine(
      canvas,
      minEntries,
      chartLeft,
      chartHeight,
      xStep,
      minColor,
      valueRange,
    );

    // Draw points for both lines
    _drawPoints(
      canvas,
      maxEntries,
      chartLeft,
      chartHeight,
      xStep,
      maxColor,
      valueRange,
    );
    _drawPoints(
      canvas,
      minEntries,
      chartLeft,
      chartHeight,
      xStep,
      minColor,
      valueRange,
    );

    // Draw X-axis labels (dates)
    _drawXAxisLabels(canvas, size, maxEntries, chartLeft, xStep);
  }

  void _drawCurveLine(
    Canvas canvas,
    List<MapEntry<DateTime, double>> entries,
    double chartLeft,
    double chartHeight,
    double xStep,
    Color color,
    double valueRange,
  ) {
    final curvePaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Calculate points
    final points = <Offset>[];
    for (var i = 0; i < entries.length; i++) {
      final value = entries[i].value;
      final x = chartLeft + (i * xStep);
      final y = chartHeight - ((value - minValue) / valueRange) * chartHeight;
      points.add(Offset(x, y));
    }

    // Draw smooth curve
    if (points.length >= 2) {
      final path = Path();
      path.moveTo(points[0].dx, points[0].dy);

      if (points.length == 2) {
        path.lineTo(points[1].dx, points[1].dy);
      } else {
        // Catmull-Rom spline for smooth curves
        for (var i = 0; i < points.length - 1; i++) {
          final p0 = i > 0 ? points[i - 1] : points[i];
          final p1 = points[i];
          final p2 = points[i + 1];
          final p3 = i < points.length - 2 ? points[i + 2] : points[i + 1];

          final cp1x = p1.dx + (p2.dx - p0.dx) / 6;
          final cp1y = p1.dy + (p2.dy - p0.dy) / 6;
          final cp2x = p2.dx - (p3.dx - p1.dx) / 6;
          final cp2y = p2.dy - (p3.dy - p1.dy) / 6;

          path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
        }
      }

      canvas.drawPath(path, curvePaint);
    }
  }

  void _drawPoints(
    Canvas canvas,
    List<MapEntry<DateTime, double>> entries,
    double chartLeft,
    double chartHeight,
    double xStep,
    Color color,
    double valueRange,
  ) {
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (var i = 0; i < entries.length; i++) {
      final value = entries[i].value;
      final x = chartLeft + (i * xStep);
      final y = chartHeight - ((value - minValue) / valueRange) * chartHeight;
      canvas.drawCircle(Offset(x, y), 3, pointPaint);
    }
  }

  void _drawYAxisAndGrid(Canvas canvas, Size size, double chartLeft) {
    final chartHeight = size.height - 20; // Reserve space for X-axis labels
    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final axisPaint = Paint()
      ..color = Colors.grey[600]!
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Calculate nice step size for Y-axis
    final valueRange = maxValue - minValue;
    final rawStep = valueRange / 5; // Aim for ~5 grid lines
    final magnitude = pow(10, (log(rawStep) / ln10).floor()).toDouble();
    final normalizedStep = rawStep / magnitude;

    // Round to nice numbers (1, 2, 5, 10)
    double niceStep;
    if (normalizedStep <= 1) {
      niceStep = magnitude.toDouble();
    } else if (normalizedStep <= 2) {
      niceStep = (2 * magnitude).toDouble();
    } else if (normalizedStep <= 5) {
      niceStep = (5 * magnitude).toDouble();
    } else {
      niceStep = (10 * magnitude).toDouble();
    }

    // Draw Y-axis
    canvas.drawLine(
      Offset(chartLeft, 0),
      Offset(chartLeft, chartHeight),
      axisPaint,
    );

    // Draw grid lines and labels
    final startValue = (minValue / niceStep).ceil() * niceStep;
    var currentValue = startValue;

    while (currentValue <= maxValue) {
      final y =
          chartHeight - ((currentValue - minValue) / valueRange) * chartHeight;

      // Draw grid line
      canvas.drawLine(Offset(chartLeft, y), Offset(size.width, y), gridPaint);

      // Draw tick mark
      canvas.drawLine(
        Offset(chartLeft - 5, y),
        Offset(chartLeft, y),
        axisPaint,
      );

      // Draw label
      final textSpan = TextSpan(
        text: currentValue.toStringAsFixed(1),
        style: TextStyle(color: Colors.grey[700], fontSize: 10),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(chartLeft - textPainter.width - 8, y - textPainter.height / 2),
      );

      currentValue += niceStep;
    }
  }

  void _drawXAxisLabels(
    Canvas canvas,
    Size size,
    List<MapEntry<DateTime, double>> entries,
    double chartLeft,
    double xStep,
  ) {
    final chartHeight = size.height - 20;
    final axisPaint = Paint()
      ..color = Colors.grey[600]!
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw X-axis line
    canvas.drawLine(
      Offset(chartLeft, chartHeight),
      Offset(size.width, chartHeight),
      axisPaint,
    );

    // Calculate label step based on number of points
    // Allow showing 10-14 labels for better readability
    int labelStep;
    if (entries.length <= 14) {
      labelStep = 1; // Show all labels (up to 14)
    } else if (entries.length <= 28) {
      labelStep = 2; // Show every 2nd label (~7-14 labels)
    } else if (entries.length <= 42) {
      labelStep = 3; // Show every 3rd label (~10-14 labels)
    } else {
      // For many points, aim for 10-14 labels
      labelStep = (entries.length / 12).ceil();
    }

    // Draw date labels and tick marks
    for (var i = 0; i < entries.length; i++) {
      final date = entries[i].key;
      final x = chartLeft + (i * xStep);

      // Always draw tick marks for all points
      canvas.drawLine(
        Offset(x, chartHeight),
        Offset(x, chartHeight + 5),
        axisPaint,
      );

      // Only draw labels at intervals
      if (i % labelStep == 0 || i == entries.length - 1) {
        // Format date as MM/DD
        final dateText = '${date.month}/${date.day}';
        final textSpan = TextSpan(
          text: dateText,
          style: TextStyle(color: Colors.grey[700], fontSize: 9),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        // Draw label centered under the tick, with rotation for better fit
        canvas.save();
        canvas.translate(x, chartHeight + 8);
        canvas.rotate(-0.3); // Slight rotation for better readability
        textPainter.paint(canvas, Offset(-textPainter.width / 2, 0));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(WeatherChartDualPainter oldDelegate) {
    return dailyMaxValues != oldDelegate.dailyMaxValues ||
        dailyMinValues != oldDelegate.dailyMinValues ||
        minValue != oldDelegate.minValue ||
        maxValue != oldDelegate.maxValue;
  }
}
