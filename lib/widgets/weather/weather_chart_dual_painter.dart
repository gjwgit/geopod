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
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    );

    // Draw 5 horizontal grid lines with labels
    for (var i = 0; i <= 4; i++) {
      final y = (size.height - 20) * i / 4;
      canvas.drawLine(Offset(chartLeft, y), Offset(size.width, y), gridPaint);

      // Y-axis label (reverse order: top = max, bottom = min)
      final value = maxValue - ((maxValue - minValue) * i / 4);
      textPainter.text = TextSpan(
        text: value.toStringAsFixed(1),
        style: const TextStyle(color: Colors.grey, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(chartLeft - textPainter.width - 5, y - 6),
      );
    }
  }

  void _drawXAxisLabels(
    Canvas canvas,
    Size size,
    List<MapEntry<DateTime, double>> entries,
    double chartLeft,
    double xStep,
  ) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Show max 7 labels evenly distributed
    final labelCount = min(7, entries.length);
    final labelStep = entries.length > 1
        ? (entries.length - 1) / (labelCount - 1)
        : 1;

    for (var i = 0; i < labelCount; i++) {
      final index = (i * labelStep).round().clamp(0, entries.length - 1);
      final date = entries[index].key;
      final x = chartLeft + (index * xStep);

      textPainter.text = TextSpan(
        text: '${date.month}/${date.day}',
        style: const TextStyle(color: Colors.grey, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height - 15),
      );
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
