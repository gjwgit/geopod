/// PDF data table builder for weather data.
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

/// Build data table for PDF showing daily weather statistics.

pw.Widget buildPdfDataTable({
  required Map<DateTime, double> dailyData,
  required Map<DateTime, (double, double)> dailyMinMax,
  required String dataType,
  required String unit,
  Map<DateTime, int>? precipitationHours,
}) {
  final dateFormat = DateFormat('yyyy-MM-dd');

  return pw.TableHelper.fromTextArray(
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
    data: (dailyData.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
        .map((entry) {
          final date = entry.key;

          // For precipitation: dailyData contains daily totals
          // For other types: dailyData contains daily averages.
          final value = entry.value;
          final (dayMin, dayMax) = dailyMinMax[date] ?? (value, value);

          // For precipitation, show hours with rain and max hourly rate.
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
  );
}
