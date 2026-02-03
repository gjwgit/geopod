/// PDF export functionality for weather chart.
///
// Time-stamp: <Wednesday 2026-01-28 09:04:09 +1100 Graham Williams>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';

import 'package:geopod/models/hourly_weather_data.dart';
import 'package:geopod/utils/ui_utils.dart';

import 'pdf_document_builder.dart';
import 'pdf_export_handler.dart';

export 'pdf_chart_painter.dart';
export 'pdf_data_table.dart';
export 'pdf_document_builder.dart';
export 'pdf_export_handler.dart';
export 'pdf_utils.dart';

/// Export weather data to PDF.

Future<void> exportWeatherChartToPdf(
  BuildContext context, {
  required HourlyWeatherData data,
  required Map<DateTime, double> dailyData,
  required Map<DateTime, (double, double)> dailyMinMax,
  Map<DateTime, double>? dailyMaxData,
  Map<DateTime, double>? dailyMinData,
  required double minValue,
  required double maxValue,
  DateTime? minDate,
  DateTime? maxDate,
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
    // Build PDF document.
    final pdf = buildWeatherPdfDocument(
      data: data,
      dailyData: dailyData,
      dailyMinMax: dailyMinMax,
      dailyMaxData: dailyMaxData,
      dailyMinData: dailyMinData,
      minValue: minValue,
      maxValue: maxValue,
      minDate: minDate,
      maxDate: maxDate,
      title: title,
      unit: unit,
      dataType: dataType,
      latitude: latitude,
      longitude: longitude,
      address: address,
      precipitationHours: precipitationHours,
      dataSource: dataSource,
    );

    // Save PDF and get bytes.
    final bytes = await pdf.save();

    // Handle platform-specific export.

    if (context.mounted) {
      await handlePdfExport(context, bytes);
    }
  } catch (e) {
    // Show error message if PDF export fails.
    if (context.mounted) {
      SnackBarHelper.showError(
        context,
        'Failed to export PDF: $e',
        duration: const Duration(seconds: 3),
      );
    }
  }
}
