/// Weather view widgets for weather dialog.
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

import '../../models/hourly_weather_data.dart';
import '../../models/weather_data.dart';
import '../hourly_weather_chart.dart';
import 'weather_detail_builders.dart';

/// Build error view for failed weather loading.
Widget buildErrorView(BuildContext context, String? errorMessage) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.error_outline, size: 48, color: Colors.red),
      const SizedBox(height: 16),
      Text(
        'Failed to load weather data',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      Text(
        errorMessage ?? 'Unknown error',
        style: Theme.of(context).textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    ],
  );
}

/// Build current weather view.
Widget buildCurrentWeatherView({
  required BuildContext context,
  required WeatherData weatherData,
  required double latitude,
  required double longitude,
  String? address,
  required bool showDailyPrecipitation,
  required VoidCallback onTogglePrecipitation,
}) {
  final timeFormat = DateFormat('yyyy-MM-dd HH:mm');

  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Location
        if (address != null && address.isNotEmpty) ...[
          Text(address, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
        ],
        Text(
          'Coordinates: ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),

        // Main weather display
        Center(
          child: Column(
            children: [
              Text(
                weatherData.weatherIcon,
                style: const TextStyle(fontSize: 60),
              ),
              const SizedBox(height: 6),
              Text(
                weatherData.weatherDescription,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 2),
              Text(
                '${weatherData.temperature.toStringAsFixed(1)}°C',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Show today's high/low if available
              if (weatherData.dailyMaxTemp != null &&
                  weatherData.dailyMinTemp != null) ...[
                const SizedBox(height: 4),
                Text(
                  'H: ${weatherData.dailyMaxTemp!.toStringAsFixed(1)}°  L: ${weatherData.dailyMinTemp!.toStringAsFixed(1)}°',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Weather details
        buildWeatherDetail(
          icon: Icons.water_drop,
          label: 'Humidity',
          value: '${weatherData.humidity}%',
        ),
        buildWeatherDetail(
          icon: Icons.air,
          label: 'Wind Speed',
          value: '${weatherData.windSpeed.toStringAsFixed(1)} km/h',
        ),
        buildWindDirectionDetail(weatherData),
        buildPrecipitationDetail(
          weather: weatherData,
          showDailyPrecipitation: showDailyPrecipitation,
          onToggle: onTogglePrecipitation,
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Updated: ${timeFormat.format(weatherData.time)} UTC',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ),
      ],
    ),
  );
}

/// Build past weather view.
Widget buildPastWeatherView({
  required BuildContext context,
  required bool isLoading,
  required HourlyWeatherData? pastWeatherData,
  required double latitude,
  required double longitude,
  String? address,
  required String selectedDataType,
  required void Function(String) onDataTypeChanged,
}) {
  if (isLoading) {
    return const Center(child: CircularProgressIndicator());
  }

  if (pastWeatherData == null) {
    return const Center(child: Text('Tap to load past 10 days weather data'));
  }

  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Past 10 Days Weather',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (address != null && address.isNotEmpty) ...[
          Text(address, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
        ],
        Text(
          'Coordinates: ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        buildDataTypeSelector(
          selectedDataType: selectedDataType,
          onSelectionChanged: onDataTypeChanged,
        ),
        const SizedBox(height: 16),
        HourlyWeatherChart(
          data: pastWeatherData,
          dataType: selectedDataType,
          sortAscending: false, // Past: newest to oldest
          latitude: latitude,
          longitude: longitude,
          address: address,
        ),
      ],
    ),
  );
}

/// Build forecast weather view.
Widget buildForecastWeatherView({
  required BuildContext context,
  required bool isLoading,
  required HourlyWeatherData? forecastWeatherData,
  required double latitude,
  required double longitude,
  String? address,
  required String selectedDataType,
  required void Function(String) onDataTypeChanged,
}) {
  if (isLoading) {
    return const Center(child: CircularProgressIndicator());
  }

  if (forecastWeatherData == null) {
    return const Center(child: Text('Tap to load 7-day forecast weather data'));
  }

  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Forecast Weather (Next 7 Days)',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (address != null && address.isNotEmpty) ...[
          Text(address, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
        ],
        Text(
          'Coordinates: ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        buildDataTypeSelector(
          selectedDataType: selectedDataType,
          onSelectionChanged: onDataTypeChanged,
        ),
        const SizedBox(height: 16),
        HourlyWeatherChart(
          data: forecastWeatherData,
          dataType: selectedDataType,
          sortAscending: true, // Forecast: oldest to newest (today to future)
          latitude: latitude,
          longitude: longitude,
          address: address,
        ),
      ],
    ),
  );
}

/// Build historical weather view.
Widget buildHistoricalWeatherView({
  required BuildContext context,
  required bool isLoading,
  required HourlyWeatherData? historicalWeatherData,
  required double latitude,
  required double longitude,
  String? address,
  required String selectedDataType,
  required Widget dateRangeSelector,
  required void Function(String) onDataTypeChanged,
}) {
  if (isLoading) {
    return const Center(child: CircularProgressIndicator());
  }

  if (historicalWeatherData == null) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Tap to load historical weather data',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Data from 30 days ago (ERA5 archive has 5-7 day delay)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Historical Weather',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Data from ${historicalWeatherData.startDate.year}-${historicalWeatherData.startDate.month.toString().padLeft(2, '0')}-${historicalWeatherData.startDate.day.toString().padLeft(2, '0')} to ${historicalWeatherData.endDate.year}-${historicalWeatherData.endDate.month.toString().padLeft(2, '0')}-${historicalWeatherData.endDate.day.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 12),
        dateRangeSelector,
        const SizedBox(height: 8),
        if (address != null && address.isNotEmpty) ...[
          Text(address, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
        ],
        Text(
          'Coordinates: ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        buildDataTypeSelector(
          selectedDataType: selectedDataType,
          onSelectionChanged: onDataTypeChanged,
        ),
        const SizedBox(height: 16),
        HourlyWeatherChart(
          data: historicalWeatherData,
          dataType: selectedDataType,
          sortAscending: false, // Historical: newest to oldest
          latitude: latitude,
          longitude: longitude,
          address: address,
        ),
      ],
    ),
  );
}
