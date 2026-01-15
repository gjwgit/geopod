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

import '../models/hourly_weather_data.dart';
import 'weather/weather_chart_helpers.dart';
import 'weather/weather_chart_painter.dart';
import 'weather/weather_chart_pdf.dart';
import 'weather/weather_chart_sampling.dart';

/// Displays hourly weather data as a simple line chart.
class HourlyWeatherChart extends StatefulWidget {
  const HourlyWeatherChart({
    required this.data,
    this.dataType = 'temperature',
    this.latitude,
    this.longitude,
    this.address,
    super.key,
  });

  final HourlyWeatherData data;
  final String
  dataType; // 'temperature', 'humidity', 'wind_speed', 'precipitation'
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
    final (min, max) = getDataRange(widget.dataType, widget.data);
    var dailyData = getDailyData(widget.dataType, widget.data);

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

    // Sample data if too many points (keep max 30 points for better performance)
    if (dailyData.length > 30) {
      dailyData = sampleData(dailyData, 30);
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
            onPressed: () => exportWeatherChartToPdf(
              context,
              data: widget.data,
              dailyData: dailyData,
              minValue: min,
              maxValue: max,
              title: title,
              unit: unit,
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
                          '${avgValue.toStringAsFixed(1)}${getDataUnit(widget.dataType)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: getValueColor(avgValue, min, max),
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
