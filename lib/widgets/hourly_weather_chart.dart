/// Widget for displaying hourly weather chart.
///
// Time-stamp: <Tuesday 2026-01-14 10:00:00 +1100>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

// Conditional imports for platform-specific functionality
import 'dart:js_interop';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:web/web.dart' as web;

import '../models/hourly_weather_data.dart';

/// Displays hourly weather data as a simple line chart.
class HourlyWeatherChart extends StatefulWidget {
  const HourlyWeatherChart({
    required this.data,
    this.dataType = 'temperature',
    this.latitude,
    this.longitude,
    super.key,
  });

  final HourlyWeatherData data;
  final String
  dataType; // 'temperature', 'humidity', 'wind_speed', 'precipitation'
  final double? latitude;
  final double? longitude;

  @override
  State<HourlyWeatherChart> createState() => _HourlyWeatherChartState();
}

class _HourlyWeatherChartState extends State<HourlyWeatherChart> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (min, max) = _getDataRange();
    var dailyData = _getDailyData();

    // Check if we have any data
    if (dailyData.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No ${_getDataTitle().toLowerCase()} data available',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'This might be because the data is not available for this time period.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    // Sample data if too many points (keep max 30 points for better performance)
    if (dailyData.length > 30) {
      dailyData = _sampleData(dailyData, 30);
    }

    final dateFormat = DateFormat('MMM dd');
    final title = _getDataTitle();
    final unit = _getDataUnit();
    final icon = _getDataIcon();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with date range
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              '${dateFormat.format(widget.data.startDate)} - ${dateFormat.format(widget.data.endDate)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Data range indicator
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.blue[700]),
            const SizedBox(width: 4),
            Text(
              'Min: ${min.toStringAsFixed(1)}$unit',
              style: TextStyle(fontSize: 12, color: Colors.blue[700]),
            ),
            const SizedBox(width: 16),
            Icon(icon, size: 16, color: Colors.red[700]),
            const SizedBox(width: 4),
            Text(
              'Max: ${max.toStringAsFixed(1)}$unit',
              style: TextStyle(fontSize: 12, color: Colors.red[700]),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Simple chart using daily averages
        Container(
          height: 220,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
            child: _buildSimpleChart(context, dailyData, min, max),
          ),
        ),
        const SizedBox(height: 4),

        // Chart info with tooltip
        if (widget.data.getDailyAverages().length > 30)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Tooltip(
                  message:
                      'Catmull-Rom spline: Smooth curve algorithm that passes through data points\n'
                      'Ramer-Douglas-Peucker: Smart sampling to preserve key features',
                  child: Icon(
                    Icons.info_outline,
                    size: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Curve fitting: Catmull-Rom spline | Data sampling: RDP algorithm',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),

        // Export PDF button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: OutlinedButton.icon(
            onPressed: () => _exportToPdf(context, dailyData, min, max),
            icon: const Icon(Icons.picture_as_pdf, size: 18),
            label: const Text('Export to PDF'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Daily averages list with scrollbar
        Row(
          children: [
            Text(
              'Daily Averages',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Icon(Icons.swipe_left, size: 16, color: Colors.grey[500]),
            Text(
              'Scroll to see all',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            thickness: 8,
            radius: const Radius.circular(4),
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: dailyData.entries.map((entry) {
                  final date = entry.key;
                  final avgValue = entry.value;
                  final isToday =
                      date.day == DateTime.now().day &&
                      date.month == DateTime.now().month &&
                      date.year == DateTime.now().year;

                  return Container(
                    width: 70,
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isToday
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: isToday
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            )
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('MMM').format(date),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          DateFormat('dd').format(date),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${avgValue.toStringAsFixed(1)}${_getDataUnit()}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _getValueColor(avgValue, min, max),
                          ),
                        ),
                        if (isToday)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Today',
                              style: TextStyle(
                                fontSize: 9,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleChart(
    BuildContext context,
    Map<DateTime, double> dailyAverages,
    double minValue,
    double maxValue,
  ) {
    if (dailyAverages.isEmpty) return const SizedBox();

    final valueRange = maxValue - minValue;
    // For precipitation or any data with no variation, still show chart
    if (valueRange < 0.01) {
      // Use a small range to make the flat line visible
      final adjustedMax = minValue == 0 ? 1.0 : minValue * 1.1;
      return CustomPaint(
        painter: _TemperatureChartPainter(
          dailyAverages: dailyAverages,
          minTemp: 0, // Always start from 0 for flat lines
          maxTemp: adjustedMax,
          color: widget.dataType == 'precipitation'
              ? Colors.blue
              : Theme.of(context).colorScheme.primary,
        ),
        child: Container(),
      );
    }

    return CustomPaint(
      painter: _TemperatureChartPainter(
        dailyAverages: dailyAverages,
        minTemp: minValue,
        maxTemp: maxValue,
        color: Theme.of(context).colorScheme.primary,
      ),
      child: const SizedBox.expand(),
    );
  }

  /// Export weather data to PDF
  Future<void> _exportToPdf(
    BuildContext context,
    Map<DateTime, double> dailyData,
    double minValue,
    double maxValue,
  ) async {
    try {
      final pdf = pw.Document();
      final dateFormat = DateFormat('yyyy-MM-dd');
      final title = _getDataTitle();
      final unit = _getDataUnit();

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
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),

            // Location info
            if (widget.latitude != null && widget.longitude != null)
              pw.Text(
                'Location: ${widget.latitude!.toStringAsFixed(4)}, ${widget.longitude!.toStringAsFixed(4)}',
                style: const pw.TextStyle(fontSize: 12),
              ),
            pw.SizedBox(height: 10),

            // Date range
            pw.Text(
              'Date Range: ${dateFormat.format(widget.data.startDate)} - ${dateFormat.format(widget.data.endDate)}',
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
                    '• Catmull-Rom spline interpolation: Smooth curve algorithm passing through data points',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    '• Ramer-Douglas-Peucker algorithm: Smart sampling preserving key features',
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
            _buildPdfChart(dailyData, minValue, maxValue, unit),
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
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
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
              'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF downloaded successfully'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // For mobile/desktop: Show PDF preview and allow save/print
        await Printing.layoutPdf(onLayout: (format) async => pdf.save());
      }
    } catch (e) {
      // Show error message if PDF export fails
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export PDF: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Build line chart for PDF using simple drawing
  pw.Widget _buildPdfChart(
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
        ? _sampleEntriesForPdf(entries, 20)
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
                      final labelStep = (sampledEntries.length / 6)
                          .ceil()
                          .clamp(1, 5);
                      final labels = <pw.Widget>[];
                      for (
                        var i = 0;
                        i < sampledEntries.length;
                        i += labelStep
                      ) {
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

  /// Sample entries for PDF to reduce clutter
  List<MapEntry<DateTime, double>> _sampleEntriesForPdf(
    List<MapEntry<DateTime, double>> entries,
    int targetCount,
  ) {
    if (entries.length <= targetCount) return entries;

    final step = entries.length / targetCount;
    final sampled = <MapEntry<DateTime, double>>[];

    for (var i = 0; i < targetCount; i++) {
      final index = (i * step).floor().clamp(0, entries.length - 1);
      sampled.add(entries[index]);
    }

    // Always include the last entry
    if (sampled.last.key != entries.last.key) {
      sampled.add(entries.last);
    }

    return sampled;
  }

  Color _getValueColor(double value, double min, double max) {
    final range = max - min;
    if (range == 0) return Colors.blue;

    final normalized = (value - min) / range;

    if (normalized < 0.33) {
      return Colors.blue[700]!;
    } else if (normalized < 0.67) {
      return Colors.orange[700]!;
    } else {
      return Colors.red[700]!;
    }
  }

  // Helper methods for data type
  (double, double) _getDataRange() {
    switch (widget.dataType) {
      case 'humidity':
        return widget.data.getHumidityRange();
      case 'wind_speed':
        return widget.data.getWindSpeedRange();
      case 'precipitation':
        return widget.data.getPrecipitationRange();
      case 'temperature':
      default:
        return widget.data.getTemperatureRange();
    }
  }

  Map<DateTime, double> _getDailyData() {
    switch (widget.dataType) {
      case 'humidity':
        return widget.data.getDailyAverageHumidity();
      case 'wind_speed':
        return widget.data.getDailyAverageWindSpeed();
      case 'precipitation':
        return widget.data.getDailyAveragePrecipitation();
      case 'temperature':
      default:
        return widget.data.getDailyAverages();
    }
  }

  String _getDataTitle() {
    switch (widget.dataType) {
      case 'humidity':
        return 'Humidity Range';
      case 'wind_speed':
        return 'Wind Speed Range';
      case 'precipitation':
        return 'Precipitation Range';
      case 'temperature':
      default:
        return 'Temperature Range';
    }
  }

  String _getDataUnit() {
    switch (widget.dataType) {
      case 'humidity':
        return '%';
      case 'wind_speed':
        return ' km/h';
      case 'precipitation':
        return ' mm';
      case 'temperature':
      default:
        return '°C';
    }
  }

  IconData _getDataIcon() {
    switch (widget.dataType) {
      case 'humidity':
        return Icons.water_drop;
      case 'wind_speed':
        return Icons.air;
      case 'precipitation':
        return Icons.umbrella;
      case 'temperature':
      default:
        return Icons.thermostat;
    }
  }

  /// Sample data using Ramer-Douglas-Peucker algorithm to preserve curve characteristics
  /// This algorithm keeps points that are important for maintaining the shape of the curve
  Map<DateTime, double> _sampleData(
    Map<DateTime, double> data,
    int targetCount,
  ) {
    if (data.length <= targetCount) return data;

    final entries = data.entries.toList();

    // Use Douglas-Peucker algorithm for smart sampling
    final sampled = _douglasPeucker(entries, targetCount);

    // Convert back to map
    return Map.fromEntries(sampled);
  }

  /// Ramer-Douglas-Peucker algorithm implementation
  /// Reduces number of points while preserving the overall shape
  List<MapEntry<DateTime, double>> _douglasPeucker(
    List<MapEntry<DateTime, double>> points,
    int targetCount,
  ) {
    if (points.length <= targetCount) return points;

    // Calculate appropriate epsilon (tolerance) based on data range
    final values = points.map((e) => e.value).toList();
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final range = maxVal - minVal;

    // Start with a small epsilon and increase until we reach target count
    var epsilon = range * 0.01;
    var result = _rdpRecursive(points, epsilon);

    // Adjust epsilon to get closer to target count
    var iterations = 0;
    while (result.length > targetCount && iterations < 10) {
      epsilon *= 1.5;
      result = _rdpRecursive(points, epsilon);
      iterations++;
    }

    // If still too many points, fall back to uniform sampling
    if (result.length > targetCount) {
      final step = result.length / targetCount;
      final uniformSampled = <MapEntry<DateTime, double>>[];
      for (var i = 0; i < targetCount; i++) {
        final index = (i * step).round();
        if (index < result.length) {
          uniformSampled.add(result[index]);
        }
      }
      return uniformSampled;
    }

    return result;
  }

  /// Recursive RDP algorithm
  List<MapEntry<DateTime, double>> _rdpRecursive(
    List<MapEntry<DateTime, double>> points,
    double epsilon,
  ) {
    if (points.length < 3) return points;

    // Find the point with maximum distance from line segment
    var maxDistance = 0.0;
    var maxIndex = 0;

    final firstPoint = points.first;
    final lastPoint = points.last;

    for (var i = 1; i < points.length - 1; i++) {
      final distance = _perpendicularDistance(
        points[i],
        firstPoint,
        lastPoint,
        points.length,
      );
      if (distance > maxDistance) {
        maxDistance = distance;
        maxIndex = i;
      }
    }

    // If max distance is greater than epsilon, recursively simplify
    if (maxDistance > epsilon) {
      final left = _rdpRecursive(points.sublist(0, maxIndex + 1), epsilon);
      final right = _rdpRecursive(points.sublist(maxIndex), epsilon);

      // Combine results (remove duplicate middle point)
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      // If max distance is less than epsilon, keep only endpoints
      return [firstPoint, lastPoint];
    }
  }

  /// Calculate perpendicular distance from point to line segment
  double _perpendicularDistance(
    MapEntry<DateTime, double> point,
    MapEntry<DateTime, double> lineStart,
    MapEntry<DateTime, double> lineEnd,
    int totalPoints,
  ) {
    // Normalize time to 0-1 range for distance calculation
    final x0 = point.key.millisecondsSinceEpoch.toDouble();
    final y0 = point.value;

    final x1 = lineStart.key.millisecondsSinceEpoch.toDouble();
    final y1 = lineStart.value;

    final x2 = lineEnd.key.millisecondsSinceEpoch.toDouble();
    final y2 = lineEnd.value;

    // Calculate perpendicular distance
    final dx = x2 - x1;
    final dy = y2 - y1;
    final numerator = ((dy * (x0 - x1)) - (dx * (y0 - y1))).abs();
    final denominator = sqrt(dx * dx + dy * dy);

    return denominator != 0 ? numerator / denominator : 0;
  }
}

class _TemperatureChartPainter extends CustomPainter {
  _TemperatureChartPainter({
    required this.dailyAverages,
    required this.minTemp,
    required this.maxTemp,
    required this.color,
  });

  final Map<DateTime, double> dailyAverages;
  final double minTemp;
  final double maxTemp;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (dailyAverages.isEmpty) return;

    final tempRange = maxTemp - minTemp;
    if (tempRange == 0) return;

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
      final temp = entries[i].value;
      final x = chartLeft + (i * xStep);
      final y = size.height - ((temp - minTemp) / tempRange) * size.height;
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
    final tempRange = maxTemp - minTemp;
    final rawStep = tempRange / 5; // Aim for ~5 grid lines
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
    final startValue = (minTemp / niceStep).ceil() * niceStep;
    var currentValue = startValue;

    while (currentValue <= maxTemp) {
      final y =
          size.height - ((currentValue - minTemp) / tempRange) * size.height;

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
  bool shouldRepaint(_TemperatureChartPainter oldDelegate) {
    return dailyAverages != oldDelegate.dailyAverages ||
        minTemp != oldDelegate.minTemp ||
        maxTemp != oldDelegate.maxTemp;
  }
}
