/// PDF export functionality for weather chart.
///
// Time-stamp: <Tuesday 2026-01-14 10:00:00 +1100>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'dart:js_interop';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:web/web.dart' as web;

import '../../models/hourly_weather_data.dart';
import '../../utils/ui_utils.dart';
import 'weather_chart_sampling.dart';

/// Export weather data to PDF.
Future<void> exportWeatherChartToPdf(
  BuildContext context, {
  required HourlyWeatherData data,
  required Map<DateTime, double> dailyData,
  required double minValue,
  required double maxValue,
  required String title,
  required String unit,
  double? latitude,
  double? longitude,
  String? address,
}) async {
  try {
    final pdf = pw.Document();
    final dateFormat = DateFormat('yyyy-MM-dd');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Title
          pw.Header(
            level: 0,
            child: pw.Text(
              'Weather Data Report',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),

          // Location info
          if (address != null && address.isNotEmpty) ...[
            pw.Text(
              'Location: $address',
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.SizedBox(height: 4),
          ],
          if (latitude != null && longitude != null)
            pw.Text(
              'Coordinates: ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          pw.SizedBox(height: 10),

          // Date range
          pw.Text(
            'Date Range: ${dateFormat.format(data.startDate)} - ${dateFormat.format(data.endDate)}',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 10),

          // Data type
          pw.Text(
            'Data Type: $title',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),

          // Data range
          pw.Text(
            'Min: ${minValue.toStringAsFixed(1)}$unit  Max: ${maxValue.toStringAsFixed(1)}$unit',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 20),

          // Algorithm explanation
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Data Processing Algorithms',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Catmull-Rom spline interpolation: Smooth curve algorithm passing through data points',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Ramer-Douglas-Peucker algorithm: Smart sampling preserving key features',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Chart visualization
          pw.Text(
            'Data Visualization',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          buildPdfChart(dailyData, minValue, maxValue, unit),
          pw.SizedBox(height: 20),

          // Daily data table
          pw.Text(
            'Daily Average Data',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),

          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellHeight: 25,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
            },
            headers: ['Date', 'Average$unit'],
            data: dailyData.entries.map((entry) {
              return [
                dateFormat.format(entry.key),
                entry.value.toStringAsFixed(2),
              ];
            }).toList(),
          ),

          pw.SizedBox(height: 20),

          // Footer
          pw.Text(
            'Generated: ${DateFormat('yyyy-MM-dd HH:mm z').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    // Platform-specific PDF handling
    if (kIsWeb) {
      // For Web: Download PDF file directly
      final bytes = await pdf.save();
      // Convert Uint8List to JSUint8Array for web
      final blob = web.Blob(
        [bytes.toJS].toJS,
        web.BlobPropertyBag(type: 'application/pdf'),
      );
      final url = web.URL.createObjectURL(blob);
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement
        ..href = url
        ..download =
            'weather_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      anchor.click();
      web.URL.revokeObjectURL(url);

      if (context.mounted) {
        SnackBarHelper.showSuccess(
          context,
          'PDF downloaded successfully',
          duration: const Duration(seconds: 2),
        );
      }
    } else {
      // For mobile/desktop: Show PDF preview and allow save/print
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    }
  } catch (e) {
    // Show error message if PDF export fails
    if (context.mounted) {
      SnackBarHelper.showError(
        context,
        'Failed to export PDF: $e',
        duration: const Duration(seconds: 3),
      );
    }
  }
}

/// Build line chart for PDF using simple drawing.
pw.Widget buildPdfChart(
  Map<DateTime, double> data,
  double minValue,
  double maxValue,
  String unit,
) {
  if (data.isEmpty) return pw.SizedBox();

  final entries = data.entries.toList();
  final valueRange = maxValue - minValue;

  // Handle flat lines (all same values)
  final effectiveMin = minValue;
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
        height: 160,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
        ),
        child: pw.Stack(
          children: [
            // Y-axis labels
            pw.Positioned(
              left: 0,
              top: 0,
              bottom: 20,
              child: pw.SizedBox(
                width: 40,
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: List.generate(5, (i) {
                    final value = effectiveMax - (effectiveRange * i / 4);
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
              left: 45,
              top: 5,
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
                    final points = <PdfPoint>[];
                    for (var i = 0; i < sampledEntries.length; i++) {
                      final x = i * xStep;
                      final normalizedY =
                          (sampledEntries[i].value - effectiveMin) /
                          effectiveRange;
                      final y = chartHeight - (normalizedY * chartHeight);
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

                        final cp1x = p1.x + (p2.x - p0.x) / 6;
                        final cp1y = p1.y + (p2.y - p0.y) / 6;
                        final cp2x = p2.x - (p3.x - p1.x) / 6;
                        final cp2y = p2.y - (p3.y - p1.y) / 6;

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
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: () {
                    final labelStep = (sampledEntries.length / 6).ceil().clamp(
                      1,
                      5,
                    );
                    final labels = <pw.Widget>[];
                    for (var i = 0; i < sampledEntries.length; i += labelStep) {
                      labels.add(
                        pw.Text(
                          DateFormat('MM/dd').format(sampledEntries[i].key),
                          style: const pw.TextStyle(fontSize: 7),
                        ),
                      );
                    }
                    return labels;
                  }(),
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
