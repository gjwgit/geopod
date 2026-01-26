/// PDF dual-line chart painting functionality for max/min values.
///
// Time-stamp: <Sunday 2026-01-26 10:00:00 +1100>
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

/// Build dual-line chart for PDF (e.g., max/min temperature).
pw.Widget buildPdfDualChart(
  Map<DateTime, double> maxData,
  Map<DateTime, double> minData,
  double minValue,
  double maxValue,
  String unit,
) {
  if (maxData.isEmpty || minData.isEmpty) return pw.SizedBox();

  // Always sort entries by date in ascending order for PDF
  final maxEntries = maxData.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  final minEntries = minData.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  final valueRange = maxValue - minValue;

  // Handle flat lines
  final effectiveMin = minValue;
  final effectiveMax = valueRange < 0.01 ? minValue * 1.1 : maxValue;
  final effectiveRange = effectiveMax - effectiveMin;

  // Sample data for PDF if too many points
  final sampledMaxEntries = maxEntries.length > 20
      ? sampleEntriesForPdf(maxEntries, 20)
      : maxEntries;
  final sampledMinEntries = minEntries.length > 20
      ? sampleEntriesForPdf(minEntries, 20)
      : minEntries;

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      // Legend (for both temperature and wind speed)
      pw.Row(
        children: [
          pw.Container(width: 20, height: 2, color: PdfColors.red700),
          pw.SizedBox(width: 5),
          pw.Text('Maximum', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(width: 15),
          pw.Container(width: 20, height: 2, color: PdfColors.blue700),
          pw.SizedBox(width: 5),
          pw.Text('Minimum/Average', style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
      pw.SizedBox(height: 10),

      // Chart area
      pw.Container(
        height: 200,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
        ),
        child: pw.Stack(
          children: [
            // Y-axis labels
            pw.Positioned(
              left: 0,
              top: 17,
              bottom: 22,
              child: pw.SizedBox(
                width: 25,
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: List.generate(5, (i) {
                    final value = effectiveMin + (effectiveRange * (4 - i) / 4);
                    return pw.Text(
                      value.toStringAsFixed(1),
                      style: const pw.TextStyle(fontSize: 7),
                    );
                  }),
                ),
              ),
            ),
            // Chart with grid and lines
            pw.Positioned(
              left: 30,
              top: 20,
              right: 5,
              bottom: 25,
              child: pw.CustomPaint(
                painter: (canvas, size) {
                  final chartWidth = size.x;
                  final chartHeight = size.y;

                  // Draw grid
                  for (var i = 0; i <= 4; i++) {
                    final y = chartHeight * i / 4;
                    canvas
                      ..setStrokeColor(PdfColors.grey300)
                      ..setLineWidth(0.5)
                      ..moveTo(0, y)
                      ..lineTo(chartWidth, y)
                      ..strokePath();
                  }

                  // Draw max temperature line
                  if (sampledMaxEntries.length >= 2) {
                    final xStep = chartWidth / (sampledMaxEntries.length - 1);
                    canvas
                      ..setStrokeColor(PdfColors.red700)
                      ..setLineWidth(2);

                    final maxPoints = <PdfPoint>[];
                    for (var i = 0; i < sampledMaxEntries.length; i++) {
                      final x = i * xStep;
                      final normalizedY =
                          (sampledMaxEntries[i].value - effectiveMin) /
                          effectiveRange;
                      final y = normalizedY * chartHeight;
                      maxPoints.add(PdfPoint(x, y));
                    }

                    canvas.moveTo(maxPoints[0].x, maxPoints[0].y);
                    if (maxPoints.length == 2) {
                      canvas.lineTo(maxPoints[1].x, maxPoints[1].y);
                    } else {
                      for (var i = 0; i < maxPoints.length - 1; i++) {
                        final p0 = i > 0 ? maxPoints[i - 1] : maxPoints[i];
                        final p1 = maxPoints[i];
                        final p2 = maxPoints[i + 1];
                        final p3 = i < maxPoints.length - 2
                            ? maxPoints[i + 2]
                            : maxPoints[i + 1];

                        final cp1x = p1.x + (p2.x - p0.x) / 6;
                        final cp1y = p1.y + (p2.y - p0.y) / 6;
                        final cp2x = p2.x - (p3.x - p1.x) / 6;
                        final cp2y = p2.y - (p3.y - p1.y) / 6;

                        canvas.curveTo(cp1x, cp1y, cp2x, cp2y, p2.x, p2.y);
                      }
                    }
                    canvas.strokePath();
                  }

                  // Draw min temperature line
                  if (sampledMinEntries.length >= 2) {
                    final xStep = chartWidth / (sampledMinEntries.length - 1);
                    canvas
                      ..setStrokeColor(PdfColors.blue700)
                      ..setLineWidth(2);

                    final minPoints = <PdfPoint>[];
                    for (var i = 0; i < sampledMinEntries.length; i++) {
                      final x = i * xStep;
                      final normalizedY =
                          (sampledMinEntries[i].value - effectiveMin) /
                          effectiveRange;
                      final y = normalizedY * chartHeight;
                      minPoints.add(PdfPoint(x, y));
                    }

                    canvas.moveTo(minPoints[0].x, minPoints[0].y);
                    if (minPoints.length == 2) {
                      canvas.lineTo(minPoints[1].x, minPoints[1].y);
                    } else {
                      for (var i = 0; i < minPoints.length - 1; i++) {
                        final p0 = i > 0 ? minPoints[i - 1] : minPoints[i];
                        final p1 = minPoints[i];
                        final p2 = minPoints[i + 1];
                        final p3 = i < minPoints.length - 2
                            ? minPoints[i + 2]
                            : minPoints[i + 1];

                        final cp1x = p1.x + (p2.x - p0.x) / 6;
                        final cp1y = p1.y + (p2.y - p0.y) / 6;
                        final cp2x = p2.x - (p3.x - p1.x) / 6;
                        final cp2y = p2.y - (p3.y - p1.y) / 6;

                        canvas.curveTo(cp1x, cp1y, cp2x, cp2y, p2.x, p2.y);
                      }
                    }
                    canvas.strokePath();

                    // Draw data points for min temperature
                    for (final point in minPoints) {
                      canvas
                        ..setFillColor(PdfColors.blue700)
                        ..drawEllipse(point.x, point.y, 2.5, 2.5)
                        ..fillPath();
                    }
                  }

                  // Draw data points for max temperature (after drawing both lines)
                  if (sampledMaxEntries.length >= 2) {
                    final xStep = chartWidth / (sampledMaxEntries.length - 1);
                    for (var i = 0; i < sampledMaxEntries.length; i++) {
                      final x = i * xStep;
                      final normalizedY =
                          (sampledMaxEntries[i].value - effectiveMin) /
                          effectiveRange;
                      final y = normalizedY * chartHeight;
                      canvas
                        ..setFillColor(PdfColors.red700)
                        ..drawEllipse(x, y, 2.5, 2.5)
                        ..fillPath();
                    }
                  }

                  // Draw X-axis tick marks at the bottom
                  if (sampledMaxEntries.length >= 2) {
                    final xStep = chartWidth / (sampledMaxEntries.length - 1);
                    canvas
                      ..setStrokeColor(PdfColors.grey600)
                      ..setLineWidth(1);
                    for (var i = 0; i < sampledMaxEntries.length; i++) {
                      final x = i * xStep;
                      canvas
                        ..moveTo(x, 0)
                        ..lineTo(x, 3)
                        ..strokePath();
                    }
                  }
                },
              ),
            ),
            // X-axis labels
            pw.Positioned(
              left: 30,
              right: 5,
              bottom: 0,
              child: pw.SizedBox(
                height: 20,
                child: pw.LayoutBuilder(
                  builder: (context, constraints) {
                    final chartWidth = constraints!.maxWidth;
                    final labelStep = sampledMaxEntries.length <= 10
                        ? 1
                        : (sampledMaxEntries.length / 7).ceil();
                    final labels = <pw.Widget>[];
                    final xStep = sampledMaxEntries.length > 1
                        ? chartWidth / (sampledMaxEntries.length - 1)
                        : 0.0;

                    for (
                      var i = 0;
                      i < sampledMaxEntries.length;
                      i += labelStep
                    ) {
                      final x = i * xStep;
                      labels.add(
                        pw.Positioned(
                          left: (x - 15).clamp(0.0, chartWidth - 30),
                          child: pw.Text(
                            DateFormat(
                              'MM/dd',
                            ).format(sampledMaxEntries[i].key),
                            style: const pw.TextStyle(fontSize: 7),
                          ),
                        ),
                      );
                    }

                    // Always show the last label
                    if (sampledMaxEntries.length > 1 &&
                        (sampledMaxEntries.length - 1) % labelStep != 0) {
                      final lastIndex = sampledMaxEntries.length - 1;
                      final x = lastIndex * xStep;
                      labels.add(
                        pw.Positioned(
                          left: (x - 15).clamp(0.0, chartWidth - 30),
                          child: pw.Text(
                            DateFormat(
                              'MM/dd',
                            ).format(sampledMaxEntries[lastIndex].key),
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
      pw.SizedBox(height: 5),
      // Info text
      pw.Text(
        'Curve: Catmull-Rom spline interpolation',
        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
      ),
    ],
  );
}
