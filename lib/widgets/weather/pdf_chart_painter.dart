/// PDF chart painting functionality.
///
// Time-stamp: <Friday 2026-01-24 10:00:00 +1100>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'weather_chart_sampling.dart';

/// Build line chart for PDF using simple drawing.
pw.Widget buildPdfChart(
  Map<DateTime, double> data,
  double minValue,
  double maxValue,
  String unit,
) {
  if (data.isEmpty) return pw.SizedBox();

  // Always sort entries by date in ascending order for PDF
  // This ensures data points and X-axis labels are properly aligned
  final entries = data.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  final valueRange = maxValue - minValue;

  // For non-negative data (precipitation, wind, humidity), start from 0
  // For temperature, use actual min value
  final effectiveMin = minValue >= 0 ? 0.0 : minValue;

  // Handle flat lines (all same values)
  final effectiveMax = valueRange < 0.01
      ? (minValue == 0 ? 1.0 : minValue * 1.1)
      : maxValue;
  final effectiveRange = effectiveMax - effectiveMin;

  // Sample data for PDF if too many points
  final sampledEntries = entries.length > 20
      ? sampleEntriesForPdf(entries, 20)
      : entries;

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      // Chart area with grid and line
      pw.Container(
        height: 200,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
        ),
        child: pw.Stack(
          children: [
            // Y-axis labels (from bottom to top: min to max)
            pw.Positioned(
              left: 0,
              top: 20,
              bottom: 25,
              child: pw.SizedBox(
                width: 25,
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: List.generate(5, (i) {
                    // Reverse order: i=0 should be max (top), i=4 should be min (bottom)
                    final value = effectiveMin + (effectiveRange * (4 - i) / 4);
                    return pw.Text(
                      value.toStringAsFixed(1),
                      style: const pw.TextStyle(fontSize: 7),
                    );
                  }),
                ),
              ),
            ),
            // Chart with grid and line
            pw.Positioned(
              left: 30,
              top: 20,
              right: 5,
              bottom: 25,
              child: pw.CustomPaint(
                painter: (canvas, size) {
                  final chartWidth = size.x;
                  final chartHeight = size.y;

                  // Draw horizontal grid lines
                  for (var i = 0; i <= 4; i++) {
                    final y = chartHeight * i / 4;
                    canvas
                      ..setStrokeColor(PdfColors.grey300)
                      ..setLineWidth(0.5)
                      ..moveTo(0, y)
                      ..lineTo(chartWidth, y)
                      ..strokePath();
                  }

                  // Draw line chart
                  if (sampledEntries.length >= 2) {
                    final xStep = chartWidth / (sampledEntries.length - 1);

                    canvas
                      ..setStrokeColor(PdfColors.blue700)
                      ..setLineWidth(2);

                    // Calculate points
                    // PDF coordinate system: origin at bottom-left, Y-axis goes upward
                    final points = <PdfPoint>[];
                    for (var i = 0; i < sampledEntries.length; i++) {
                      final x = i * xStep;
                      final normalizedY =
                          (sampledEntries[i].value - effectiveMin) /
                          effectiveRange;
                      // In PDF: y=0 is bottom, y=chartHeight is top
                      final y = normalizedY * chartHeight;
                      points.add(PdfPoint(x, y));
                    }

                    // Draw smooth curve with Catmull-Rom spline
                    canvas.moveTo(points[0].x, points[0].y);

                    if (points.length == 2) {
                      canvas.lineTo(points[1].x, points[1].y);
                    } else {
                      for (var i = 0; i < points.length - 1; i++) {
                        final p0 = i > 0 ? points[i - 1] : points[i];
                        final p1 = points[i];
                        final p2 = points[i + 1];
                        final p3 = i < points.length - 2
                            ? points[i + 2]
                            : points[i + 1];

                        var cp1x = p1.x + (p2.x - p0.x) / 6;
                        var cp1y = p1.y + (p2.y - p0.y) / 6;
                        var cp2x = p2.x - (p3.x - p1.x) / 6;
                        var cp2y = p2.y - (p3.y - p1.y) / 6;

                        // Clamp control points Y to prevent curve going below chartHeight (value < 0)
                        // Important for non-negative values like precipitation and wind speed.
                        // Only apply this clamping when the data domain is non-negative (minValue >= 0)
                        // to avoid distorting curves for data types that can be negative (e.g. temperature).
                        if (minValue >= 0) {
                          if (cp1y > chartHeight) cp1y = chartHeight;
                          if (cp1y < 0) cp1y = 0;
                          if (cp2y > chartHeight) cp2y = chartHeight;
                          if (cp2y < 0) cp2y = 0;
                        }

                        canvas.curveTo(cp1x, cp1y, cp2x, cp2y, p2.x, p2.y);
                      }
                    }

                    canvas.strokePath();

                    // Draw data points
                    for (final point in points) {
                      canvas
                        ..setFillColor(PdfColors.blue700)
                        ..drawEllipse(point.x, point.y, 2.5, 2.5)
                        ..fillPath();
                    }
                  }
                },
              ),
            ),
            // X-axis date labels
            pw.Positioned(
              left: 45,
              right: 5,
              bottom: 0,
              child: pw.SizedBox(
                height: 20,
                child: pw.LayoutBuilder(
                  builder: (context, constraints) {
                    final chartWidth =
                        constraints!.maxWidth; // Use actual available width
                    final labelStep = sampledEntries.length <= 10
                        ? 1
                        : (sampledEntries.length / 7).ceil();
                    final labels = <pw.Widget>[];
                    final xStep = sampledEntries.length > 1
                        ? chartWidth / (sampledEntries.length - 1)
                        : 0.0;

                    for (var i = 0; i < sampledEntries.length; i += labelStep) {
                      final x = i * xStep;
                      // Adjust position to prevent first label from being cut off
                      final labelLeft = i == 0
                          ? 0.0 // First label: align to left edge
                          : (i == sampledEntries.length - 1)
                          ? x -
                                30 // Last label: align to right
                          : x - 15; // Middle labels: center

                      labels.add(
                        pw.Positioned(
                          left: labelLeft.clamp(0.0, chartWidth - 30),
                          child: pw.Text(
                            DateFormat('MM/dd').format(sampledEntries[i].key),
                            style: const pw.TextStyle(fontSize: 7),
                          ),
                        ),
                      );
                    }
                    // Always show the last label
                    if (sampledEntries.length > 1 &&
                        (sampledEntries.length - 1) % labelStep != 0) {
                      final lastIndex = sampledEntries.length - 1;
                      final x = lastIndex * xStep;
                      labels.add(
                        pw.Positioned(
                          left: (x - 30).clamp(0.0, chartWidth - 30),
                          child: pw.Text(
                            DateFormat(
                              'MM/dd',
                            ).format(sampledEntries[lastIndex].key),
                            style: const pw.TextStyle(fontSize: 7),
                          ),
                        ),
                      );
                    }
                    return pw.Stack(children: labels);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 4),
      // Info text
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Curve: Catmull-Rom spline interpolation',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
          ),
        ],
      ),
    ],
  );
}
