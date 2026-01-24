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

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:geopod/models/hourly_weather_data.dart';
import 'package:geopod/utils/ui_utils.dart';

// Conditional import for platform-specific PDF download
import 'pdf_download_stub.dart' if (dart.library.html) 'pdf_download_web.dart';
import 'weather_chart_sampling.dart';

/// Export weather data to PDF.
Future<void> exportWeatherChartToPdf(
  BuildContext context, {
  required HourlyWeatherData data,
  required Map<DateTime, double> dailyData,
  required Map<DateTime, (double, double)> dailyMinMax,
  required double minValue,
  required double maxValue,
  required String title,
  required String unit,
  String? dataType,
  double? latitude,
  double? longitude,
  String? address,
  Map<DateTime, int>? precipitationHours,
  String? dataSource,
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

          // Data source (forecast, past, historical)
          if (dataSource != null) ...[
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                border: pw.Border.all(color: PdfColors.blue200),
              ),
              child: pw.Text(
                dataSource,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
            ),
            pw.SizedBox(height: 10),
          ],

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
            dataType == 'precipitation'
                ? 'Daily Total Data'
                : 'Daily Average Data',
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
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
            headers: [
              'Date',
              dataType == 'precipitation' ? 'Total$unit' : 'Average$unit',
              dataType == 'precipitation' ? 'Hours' : 'Min$unit',
              dataType == 'precipitation' ? 'Max mm/h' : 'Max$unit',
            ],
            data:
                (dailyData.entries.toList()
                      ..sort((a, b) => a.key.compareTo(b.key)))
                    .map((entry) {
                      final date = entry.key;
                      // For precipitation: dailyData contains daily totals
                      // For other types: dailyData contains daily averages
                      final value = entry.value;
                      final (dayMin, dayMax) =
                          dailyMinMax[date] ?? (value, value);

                      // For precipitation, show hours with rain and max hourly rate
                      final secondCol = dataType == 'precipitation'
                          ? (precipitationHours?[date] ?? 0).toString()
                          : dayMin.toStringAsFixed(1);

                      return [
                        dateFormat.format(date),
                        value.toStringAsFixed(1),
                        secondCol,
                        dayMax.toStringAsFixed(1),
                      ];
                    })
                    .toList(),
          ),

          pw.SizedBox(height: 20),

          // Footer
          pw.Text(
            'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())} UTC${_formatTimeZoneOffset(DateTime.now().timeZoneOffset)}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    // Platform-specific PDF handling
    if (kIsWeb) {
      // For Web: Download PDF file directly
      final bytes = await pdf.save();
      final filename =
          'weather_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      downloadPdfWeb(bytes, filename);

      if (context.mounted) {
        SnackBarHelper.showSuccess(
          context,
          'PDF downloaded successfully',
          duration: const Duration(seconds: 2),
        );
      }
    } else {
      // For mobile/desktop: Let user choose save location
      final bytes = await pdf.save();
      final filename =
          'weather_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';

      // Ask user to choose save location
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save PDF Report',
        fileName: '$filename.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputPath != null) {
        // Save the file to the chosen location
        final file = File(outputPath);
        await file.writeAsBytes(bytes);

        if (context.mounted) {
          SnackBarHelper.showSuccess(
            context,
            'PDF saved to: $outputPath',
            duration: const Duration(seconds: 3),
          );
        }
      } else {
        // User cancelled the save dialog
        if (context.mounted) {
          SnackBarHelper.showInfo(
            context,
            'PDF export cancelled',
            duration: const Duration(seconds: 2),
          );
        }
      }
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
              top: 0,
              bottom: 20,
              child: pw.SizedBox(
                width: 40,
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

/// Format timezone offset for PDF display (e.g., "+1100", "-0500", "+0000")
String _formatTimeZoneOffset(Duration offset) {
  final hours = offset.inHours;
  final minutes = offset.inMinutes.remainder(60).abs();
  final sign = hours >= 0 ? '+' : '-';
  return '$sign${hours.abs().toString().padLeft(2, '0')}${minutes.toString().padLeft(2, '0')}';
}
