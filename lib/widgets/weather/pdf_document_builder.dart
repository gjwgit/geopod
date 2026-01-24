/// PDF document builder for weather reports.
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

import 'package:geopod/models/hourly_weather_data.dart';

import 'pdf_chart_painter.dart';
import 'pdf_data_table.dart';
import 'pdf_utils.dart';

/// Build complete PDF document for weather data report.
pw.Document buildWeatherPdfDocument({
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
}) {
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
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
        buildPdfDataTable(
          dailyData: dailyData,
          dailyMinMax: dailyMinMax,
          dataType: dataType ?? '',
          unit: unit,
          precipitationHours: precipitationHours,
        ),
        pw.SizedBox(height: 20),

        // Footer
        pw.Text(
          'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())} UTC${formatTimeZoneOffset(DateTime.now().timeZoneOffset)}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ],
    ),
  );

  return pdf;
}
