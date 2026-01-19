/// Custom painter for weather chart.
///
// Time-stamp: <Tuesday 2026-01-14 10:00:00 +1100>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Custom painter for temperature/weather chart.
class WeatherChartPainter extends CustomPainter {
  WeatherChartPainter({
    required this.dailyAverages,
    required this.minValue,
    required this.maxValue,
    required this.color,
  });

  final Map<DateTime, double> dailyAverages;
  final double minValue;
  final double maxValue;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (dailyAverages.isEmpty) return;

    final valueRange = maxValue - minValue;
    if (valueRange == 0) return;

    final entries = dailyAverages.entries.toList();

    // Reserve space for Y-axis labels (40px on left)
    final chartLeft = 40.0;
    final chartWidth = size.width - chartLeft;
    final xStep = chartWidth / (entries.length - 1);

    // Draw Y-axis grid lines and labels
    _drawYAxisAndGrid(canvas, size, chartLeft);

    // Draw smooth curve using cubic Bezier interpolation
    final curvePaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Calculate control points for smooth curve
    final points = <Offset>[];
    for (var i = 0; i < entries.length; i++) {
      final value = entries[i].value;
      final x = chartLeft + (i * xStep);
      final y = size.height - ((value - minValue) / valueRange) * size.height;
      points.add(Offset(x, y));
    }

    // Draw smooth curve using Catmull-Rom spline
    if (points.length >= 2) {
      final path = Path();
      path.moveTo(points[0].dx, points[0].dy);

      if (points.length == 2) {
        // Simple line for 2 points
        path.lineTo(points[1].dx, points[1].dy);
      } else {
        // Catmull-Rom spline for smooth curves
        for (var i = 0; i < points.length - 1; i++) {
          final p0 = i > 0 ? points[i - 1] : points[i];
          final p1 = points[i];
          final p2 = points[i + 1];
          final p3 = i < points.length - 2 ? points[i + 2] : points[i + 1];

          // Calculate control points using Catmull-Rom to Bezier conversion
          final cp1x = p1.dx + (p2.dx - p0.dx) / 6;
          final cp1y = p1.dy + (p2.dy - p0.dy) / 6;
          final cp2x = p2.dx - (p3.dx - p1.dx) / 6;
          final cp2y = p2.dy - (p3.dy - p1.dy) / 6;

          path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
        }
      }

      canvas.drawPath(path, curvePaint);
    }

    // Draw data points
    for (final point in points) {
      canvas.drawCircle(point, 4, pointPaint);
      // Draw white border for better visibility
      canvas.drawCircle(
        point,
        4,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // Draw function info
    _drawFunctionInfo(canvas, size, chartLeft);
  }

  void _drawYAxisAndGrid(Canvas canvas, Size size, double chartLeft) {
    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5
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
      Offset(chartLeft, size.height),
      axisPaint,
    );

    // Draw grid lines and labels
    final startValue = (minValue / niceStep).ceil() * niceStep;
    var currentValue = startValue;

    while (currentValue <= maxValue) {
      final y =
          size.height - ((currentValue - minValue) / valueRange) * size.height;

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
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(chartLeft - textPainter.width - 8, y - textPainter.height / 2),
      );

      currentValue += niceStep;
    }
  }

  void _drawFunctionInfo(Canvas canvas, Size size, double chartLeft) {
    // Draw function info at top-right
    final infoText = 'f(x) = Catmull-Rom spline';
    final textSpan = TextSpan(
      text: infoText,
      style: TextStyle(
        color: Colors.grey[600],
        fontSize: 10,
        fontStyle: FontStyle.italic,
        backgroundColor: Colors.white.withValues(alpha: 0.9),
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();

    // Position at top-right with padding
    textPainter.paint(canvas, Offset(size.width - textPainter.width - 8, 4));
  }

  @override
  bool shouldRepaint(WeatherChartPainter oldDelegate) {
    return dailyAverages != oldDelegate.dailyAverages ||
        minValue != oldDelegate.minValue ||
        maxValue != oldDelegate.maxValue;
  }
}
