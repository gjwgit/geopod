/// Widget for displaying hourly weather chart.
///
// Time-stamp: <Friday 2026-01-24 10:00:00 +1100>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';

import 'package:geopod/models/hourly_weather_data.dart';

import 'weather/weather_chart_config.dart';
import 'weather/weather_chart_data_card.dart';
import 'weather/weather_chart_empty_state.dart';
import 'weather/weather_chart_header.dart';
import 'weather/weather_chart_helpers.dart';
import 'weather/weather_chart_painter.dart';
import 'weather/weather_chart_pdf.dart';
import 'weather/weather_chart_range_indicator.dart';
import 'weather/weather_chart_sampling.dart';

/// Displays hourly weather data as a simple line chart.
class HourlyWeatherChart extends StatefulWidget {
  const HourlyWeatherChart({
    required this.data,
    this.dataType = 'temperature',
    this.sortAscending = false,
    this.latitude,
    this.longitude,
    this.address,
    this.dataSource,
    super.key,
  });

  final HourlyWeatherData data;
  final String
  dataType; // 'temperature', 'humidity', 'wind_speed', 'precipitation'
  final bool sortAscending; // true = oldest to newest, false = newest to oldest
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? dataSource; // 'Past 10 Days', 'Forecast (7 Days)', 'Historical'

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
    final (axisMin, axisMax) = getDataRange(widget.dataType, widget.data);
    var dailyData = getDailyData(widget.dataType, widget.data);

    // Get daily min/max values for each day
    final dailyMinMax = widget.data.getDailyMinMax(widget.dataType);

    // Get precipitation hours for each day (only for precipitation data)
    final precipitationHours = widget.dataType == 'precipitation'
        ? widget.data.getDailyPrecipitationHours()
        : null;

    // Keep original unsorted data for PDF export
    final originalDailyData = dailyData;

    // Sort data based on sortAscending parameter for UI display
    final sortedEntries = dailyData.entries.toList()
      ..sort(
        (a, b) => widget.sortAscending
            ? a.key.compareTo(b.key) // Ascending: old to new
            : b.key.compareTo(a.key),
      ); // Descending: new to old
    dailyData = Map.fromEntries(sortedEntries);

    // Calculate actual data range for display
    double dataMin = axisMin;
    double dataMax = axisMax;
    if (dailyData.isNotEmpty) {
      final values = dailyData.values.toList();
      dataMin = values.reduce((a, b) => a < b ? a : b);
      dataMax = values.reduce((a, b) => a > b ? a : b);
    }

    // Check if we have any data
    if (dailyData.isEmpty) {
      return WeatherChartEmptyState(dataTitle: getDataTitle(widget.dataType));
    }

    // Sample data for chart if too many points (but keep full data for cards display)
    Map<DateTime, double> chartData = dailyData;
    if (dailyData.length > maxChartDataPoints) {
      chartData = sampleData(dailyData, maxChartDataPoints);
    }

    final title = getDataTitle(widget.dataType);
    final unit = getDataUnit(widget.dataType);
    final icon = getDataIcon(widget.dataType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with date range
        WeatherChartHeader(
          title: title,
          startDate: widget.data.startDate,
          endDate: widget.data.endDate,
        ),
        const SizedBox(height: 12),

        // Data range indicator (shows actual data min/max)
        WeatherChartRangeIndicator(
          dataMin: dataMin,
          dataMax: dataMax,
          unit: unit,
          icon: icon,
        ),
        const SizedBox(height: 16),

        // Simple chart using daily data
        Container(
          height: chartHeight,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              8,
              16,
              16,
              30,
            ), // More bottom padding for X-axis
            child: _buildSimpleChart(context, chartData, axisMin, axisMax),
          ),
        ),
        const SizedBox(height: 4),

        // Chart info with tooltip
        if (widget.data.getDailyAverages().length > maxChartDataPoints)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Tooltip(
                  message: chartSamplingTooltip,
                  child: Icon(
                    Icons.info_outline,
                    size: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    chartSamplingInfo,
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
            onPressed: () => exportWeatherChartToPdf(
              context,
              data: widget.data,
              dailyData: originalDailyData,
              dailyMinMax: dailyMinMax,
              minValue: dataMin,
              maxValue: dataMax,
              title: title,
              unit: unit,
              dataType: widget.dataType,
              latitude: widget.latitude,
              longitude: widget.longitude,
              address: widget.address,
              precipitationHours: precipitationHours,
              dataSource: widget.dataSource,
            ),
            icon: const Icon(Icons.picture_as_pdf, size: 18),
            label: const Text('Export to PDF'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Daily data list with scrollbar
        Row(
          children: [
            Text(
              widget.dataType == 'precipitation'
                  ? 'Daily Totals'
                  : 'Daily Averages',
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
          height: 120,
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
                  final (dayMin, dayMax) =
                      dailyMinMax[date] ?? (avgValue, avgValue);
                  final isToday =
                      date.day == DateTime.now().day &&
                      date.month == DateTime.now().month &&
                      date.year == DateTime.now().year;

                  return WeatherDataCard(
                    date: date,
                    avgValue: avgValue,
                    dayMin: dayMin,
                    dayMax: dayMax,
                    dataMin: dataMin,
                    dataMax: dataMax,
                    dataType: widget.dataType,
                    precipitationHours: precipitationHours?[date],
                    isToday: isToday,
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
        painter: WeatherChartPainter(
          dailyAverages: dailyAverages,
          minValue: 0, // Always start from 0 for flat lines
          maxValue: adjustedMax,
          color: widget.dataType == 'precipitation'
              ? Colors.blue
              : Theme.of(context).colorScheme.primary,
        ),
        child: Container(),
      );
    }

    return CustomPaint(
      painter: WeatherChartPainter(
        dailyAverages: dailyAverages,
        minValue: minValue,
        maxValue: maxValue,
        color: Theme.of(context).colorScheme.primary,
      ),
      child: const SizedBox.expand(),
    );
  }
}
