/// Data processing utilities for weather charts.
///
// Time-stamp: <Sunday 2026-01-26 12:00:00 +1100>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:geopod/models/hourly_weather_data.dart';

import 'weather_chart_helpers.dart';
import 'weather_chart_sampling.dart';

/// Processed weather chart data.
class ProcessedChartData {
  ProcessedChartData({
    required this.dailyData,
    required this.dailyMaxData,
    required this.dailyMinData,
    required this.originalDailyData,
    required this.originalDailyMaxData,
    required this.originalDailyMinData,
    required this.chartData,
    required this.chartMaxData,
    required this.chartMinData,
    required this.dataMin,
    required this.dataMax,
    this.minDate,
    this.maxDate,
    required this.dailyMinMax,
    this.precipitationHours,
  });

  final Map<DateTime, double> dailyData;
  final Map<DateTime, double>? dailyMaxData;
  final Map<DateTime, double>? dailyMinData;
  final Map<DateTime, double> originalDailyData;
  final Map<DateTime, double>? originalDailyMaxData;
  final Map<DateTime, double>? originalDailyMinData;
  final Map<DateTime, double> chartData;
  final Map<DateTime, double>? chartMaxData;
  final Map<DateTime, double>? chartMinData;
  final double dataMin;
  final double dataMax;
  final DateTime? minDate;
  final DateTime? maxDate;
  final Map<DateTime, (double, double)> dailyMinMax;
  final Map<DateTime, int>? precipitationHours;
}

/// Process hourly weather data for chart display.
ProcessedChartData processWeatherData({
  required HourlyWeatherData data,
  required String dataType,
  required bool sortAscending,
  required int maxChartDataPoints,
}) {
  final (axisMin, axisMax) = getDataRange(dataType, data);
  var dailyData = getDailyData(dataType, data);

  // Get daily min/max values for each day
  final dailyMinMax = data.getDailyMinMax(dataType);

  // For temperature and wind_speed, extract separate max and min/avg data
  Map<DateTime, double>? dailyMaxData;
  Map<DateTime, double>? dailyMinData;
  if (dataType == 'temperature') {
    dailyMaxData = dailyMinMax.map((date, values) => MapEntry(date, values.$2));
    dailyMinData = dailyMinMax.map((date, values) => MapEntry(date, values.$1));
  } else if (dataType == 'wind_speed') {
    // For wind speed: max wind speed and average wind speed
    dailyMaxData = dailyMinMax.map((date, values) => MapEntry(date, values.$2));
    dailyMinData = dailyData; // Average wind speed
  }

  // Get precipitation hours for each day (only for precipitation data)
  final precipitationHours = dataType == 'precipitation'
      ? data.getDailyPrecipitationHours()
      : null;

  // Keep original unsorted data for PDF export
  final originalDailyData = dailyData;
  final originalDailyMaxData = dailyMaxData;
  final originalDailyMinData = dailyMinData;

  // Sort data based on sortAscending parameter for UI display
  final sortedEntries = dailyData.entries.toList()
    ..sort(
      (a, b) => sortAscending
          ? a.key.compareTo(b.key) // Ascending: old to new
          : b.key.compareTo(a.key),
    ); // Descending: new to old
  dailyData = Map.fromEntries(sortedEntries);

  // Sort max/min data for temperature and wind_speed
  if (dailyMaxData != null && dailyMinData != null) {
    final sortedMaxEntries = dailyMaxData.entries.toList()
      ..sort(
        (a, b) =>
            sortAscending ? a.key.compareTo(b.key) : b.key.compareTo(a.key),
      );
    dailyMaxData = Map.fromEntries(sortedMaxEntries);

    final sortedMinEntries = dailyMinData.entries.toList()
      ..sort(
        (a, b) =>
            sortAscending ? a.key.compareTo(b.key) : b.key.compareTo(a.key),
      );
    dailyMinData = Map.fromEntries(sortedMinEntries);
  }

  // Calculate actual data range for display and track dates
  double dataMin = axisMin;
  double dataMax = axisMax;
  DateTime? minDate;
  DateTime? maxDate;

  if ((dataType == 'temperature' || dataType == 'wind_speed') &&
      dailyMinData != null &&
      dailyMaxData != null) {
    // For temperature and wind_speed, use actual min/avg and max values
    if (dailyMinData.isNotEmpty && dailyMaxData.isNotEmpty) {
      // Find min value and its date
      var minEntry = dailyMinData.entries.first;
      for (final entry in dailyMinData.entries) {
        if (entry.value < minEntry.value) {
          minEntry = entry;
        }
      }
      dataMin = minEntry.value;
      minDate = minEntry.key;

      // Find max value and its date
      var maxEntry = dailyMaxData.entries.first;
      for (final entry in dailyMaxData.entries) {
        if (entry.value > maxEntry.value) {
          maxEntry = entry;
        }
      }
      dataMax = maxEntry.value;
      maxDate = maxEntry.key;
    }
  } else if (dailyData.isNotEmpty) {
    // Find min value and its date
    var minEntry = dailyData.entries.first;
    for (final entry in dailyData.entries) {
      if (entry.value < minEntry.value) {
        minEntry = entry;
      }
    }
    dataMin = minEntry.value;
    minDate = minEntry.key;

    // Find max value and its date
    var maxEntry = dailyData.entries.first;
    for (final entry in dailyData.entries) {
      if (entry.value > maxEntry.value) {
        maxEntry = entry;
      }
    }
    dataMax = maxEntry.value;
    maxDate = maxEntry.key;
  }

  // Sample data for chart if too many points (but keep full data for cards display)
  Map<DateTime, double> chartData = dailyData;
  Map<DateTime, double>? chartMaxData = dailyMaxData;
  Map<DateTime, double>? chartMinData = dailyMinData;

  if (dailyData.length > maxChartDataPoints) {
    chartData = sampleData(dailyData, maxChartDataPoints);
    if (dailyMaxData != null && dailyMinData != null) {
      chartMaxData = sampleData(dailyMaxData, maxChartDataPoints);
      // For wind_speed, dailyMinData is already dailyData (average), so sample it
      if (dataType == 'wind_speed') {
        chartMinData = chartData;
      } else {
        chartMinData = sampleData(dailyMinData, maxChartDataPoints);
      }
    }
  }

  return ProcessedChartData(
    dailyData: dailyData,
    dailyMaxData: dailyMaxData,
    dailyMinData: dailyMinData,
    originalDailyData: originalDailyData,
    originalDailyMaxData: originalDailyMaxData,
    originalDailyMinData: originalDailyMinData,
    chartData: chartData,
    chartMaxData: chartMaxData,
    chartMinData: chartMinData,
    dataMin: dataMin,
    dataMax: dataMax,
    minDate: minDate,
    maxDate: maxDate,
    dailyMinMax: dailyMinMax,
    precipitationHours: precipitationHours,
  );
}
