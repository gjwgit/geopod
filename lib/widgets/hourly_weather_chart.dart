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

import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import 'package:geopod/models/hourly_weather_data.dart';

import 'weather/weather_chart_helpers.dart';
import 'weather/weather_chart_painter.dart';
import 'weather/weather_chart_pdf.dart';
import 'weather/weather_chart_sampling.dart';

/// Maximum number of data points to display in the chart for better performance.
const int maxChartDataPoints = 30;

/// Displays hourly weather data as a simple line chart.
class HourlyWeatherChart extends StatefulWidget {
  const HourlyWeatherChart({
    required this.data,
    this.dataType = 'temperature',
    this.sortAscending = false,
    this.latitude,
    this.longitude,
    this.address,
    super.key,
  });

  final HourlyWeatherData data;
  final String
  dataType; // 'temperature', 'humidity', 'wind_speed', 'precipitation'
  final bool sortAscending; // true = oldest to newest, false = newest to oldest
  final double? latitude;
  final double? longitude;
  final String? address;

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

    // Sort data based on sortAscending parameter
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No ${getDataTitle(widget.dataType).toLowerCase()} data available',
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

    // Sample data for chart if too many points (but keep full data for cards display)
    Map<DateTime, double> chartData = dailyData;
    if (dailyData.length > maxChartDataPoints) {
      chartData = sampleData(dailyData, maxChartDataPoints);
    }

    final dateFormat = DateFormat('MMM dd');
    final title = getDataTitle(widget.dataType);
    final unit = getDataUnit(widget.dataType);
    final icon = getDataIcon(widget.dataType);

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

        // Data range indicator (shows actual data min/max)
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.blue[700]),
            const SizedBox(width: 4),
            Text(
              'Min: ${dataMin.toStringAsFixed(1)}$unit',
              style: TextStyle(fontSize: 12, color: Colors.blue[700]),
            ),
            const SizedBox(width: 16),
            Icon(icon, size: 16, color: Colors.red[700]),
            const SizedBox(width: 4),
            Text(
              'Max: ${dataMax.toStringAsFixed(1)}$unit',
              style: TextStyle(fontSize: 12, color: Colors.red[700]),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Simple chart using daily data
        Container(
          height: 250, // Increased height to accommodate X-axis labels
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
            onPressed: () => exportWeatherChartToPdf(
              context,
              data: widget.data,
              dailyData: dailyData,
              dailyMinMax: dailyMinMax,
              minValue: dataMin,
              maxValue: dataMax,
              title: title,
              unit: unit,
              dataType: widget.dataType,
              latitude: widget.latitude,
              longitude: widget.longitude,
              address: widget.address,
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

                  return Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
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
                            fontSize: 9,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          DateFormat('dd').format(date),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${avgValue.toStringAsFixed(1)}${getDataUnit(widget.dataType)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: getValueColor(avgValue, dataMin, dataMax),
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Show min/max for the day
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'min ',
                              style: TextStyle(
                                fontSize: 8,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '${dayMin.toStringAsFixed(1)}${widget.dataType == 'precipitation' ? 'mm/h' : ''}',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'max ',
                              style: TextStyle(
                                fontSize: 8,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '${dayMax.toStringAsFixed(1)}${widget.dataType == 'precipitation' ? 'mm/h' : ''}',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w500,
                                color: Colors.red[700],
                              ),
                            ),
                          ],
                        ),
                        if (isToday)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Today',
                              style: TextStyle(
                                fontSize: 8,
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
