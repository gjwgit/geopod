/// Weather service using Open-Meteo API.
///
// Time-stamp: <Tuesday 2026-01-14 09:00:00 +1100>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/hourly_weather_data.dart';
import '../models/weather_data.dart';

/// Service for fetching weather data from Open-Meteo API.
class WeatherService {
  /// Base URL for Open-Meteo forecast API.
  static const String _forecastUrl = 'https://api.open-meteo.com/v1/forecast';

  /// Base URL for Open-Meteo archive API.
  static const String _archiveUrl =
      'https://archive-api.open-meteo.com/v1/era5';

  /// Fetch current weather data for a location.
  ///
  /// Returns [WeatherData] for the specified [latitude] and [longitude].
  /// Throws an exception if the request fails.
  Future<WeatherData> getCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(_forecastUrl).replace(
      queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'current': [
          'temperature_2m',
          'relative_humidity_2m',
          'precipitation',
          'weather_code',
          'wind_speed_10m',
          'wind_direction_10m',
        ].join(','),
        'timezone': 'Australia/Sydney',
      },
    );

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return WeatherData.fromJson(json);
      } else {
        throw Exception('Failed to load weather data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch weather: $e');
    }
  }

  /// Fetch past weather data (last N days, actual historical data only).
  ///
  /// Returns [HourlyWeatherData] with hourly data for the past [days].
  /// Uses the archive API to get actual past weather, not forecasts.
  /// Maximum [days] is 10 to ensure data is available (ERA5 has ~5-7 day delay).
  Future<HourlyWeatherData> getPastWeather({
    required double latitude,
    required double longitude,
    int days = 10,
  }) async {
    if (days < 1 || days > 10) {
      throw ArgumentError('days must be between 1 and 10');
    }

    // Calculate date range for past N days (excluding today)
    final now = DateTime.now();
    final endDate = now.subtract(const Duration(days: 1)); // Yesterday
    final startDate = endDate.subtract(Duration(days: days - 1));

    final startDateStr =
        '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    final endDateStr =
        '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

    final uri = Uri.parse(_archiveUrl).replace(
      queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'start_date': startDateStr,
        'end_date': endDateStr,
        'hourly': [
          'temperature_2m',
          'relative_humidity_2m',
          'wind_speed_10m',
          'precipitation',
        ].join(','),
        'timezone': 'Australia/Sydney',
      },
    );

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return HourlyWeatherData.fromJson(json);
      } else {
        throw Exception(
          'Failed to load past weather data: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Failed to fetch past weather: $e');
    }
  }

  /// Fetch forecast weather data (next N days).
  ///
  /// Returns [HourlyWeatherData] with hourly forecast data for the next [days].
  /// Maximum [days] is 16 (Open-Meteo forecast limit).
  Future<HourlyWeatherData> getForecastWeather({
    required double latitude,
    required double longitude,
    int days = 7,
  }) async {
    if (days < 1 || days > 16) {
      throw ArgumentError('days must be between 1 and 16');
    }

    final uri = Uri.parse(_forecastUrl).replace(
      queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'forecast_days': days.toString(),
        'hourly': [
          'temperature_2m',
          'relative_humidity_2m',
          'wind_speed_10m',
          'precipitation',
        ].join(','),
        'timezone': 'Australia/Sydney',
      },
    );

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return HourlyWeatherData.fromJson(json);
      } else {
        throw Exception(
          'Failed to load forecast weather data: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Failed to fetch forecast weather: $e');
    }
  }

  /// Fetch historical weather data for a specific date range.
  ///
  /// Returns [HourlyWeatherData] with hourly data between [startDate] and
  /// [endDate]. Available from 1940 onwards. Maximum range is 1 year.
  ///
  /// **Important**: ERA5 archive data has a delay of about 5-7 days.
  /// The end date must be at least 7 days before today.
  Future<HourlyWeatherData> getHistoricalWeather({
    required double latitude,
    required double longitude,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // ERA5 data has approximately 5-7 days delay
    final now = DateTime.now();
    final maxEndDate = now.subtract(const Duration(days: 7));

    // Validate date range
    if (endDate.isBefore(startDate)) {
      throw ArgumentError('endDate must be after startDate');
    }

    if (endDate.isAfter(maxEndDate)) {
      throw ArgumentError(
        'ERA5 archive data has a 5-7 day delay. '
        'End date must be at least 7 days before today. '
        'Latest available date: ${maxEndDate.year}-${maxEndDate.month.toString().padLeft(2, '0')}-${maxEndDate.day.toString().padLeft(2, '0')}',
      );
    }

    final daysDiff = endDate.difference(startDate).inDays;
    if (daysDiff > 365) {
      throw ArgumentError('Date range cannot exceed 365 days');
    }

    if (startDate.year < 1940) {
      throw ArgumentError('Historical data only available from 1940 onwards');
    }

    final startDateStr =
        '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    final endDateStr =
        '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

    final uri = Uri.parse(_archiveUrl).replace(
      queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'start_date': startDateStr,
        'end_date': endDateStr,
        'hourly': [
          'temperature_2m',
          'relative_humidity_2m',
          'wind_speed_10m',
          'precipitation',
        ].join(','),
        'timezone': 'Australia/Sydney',
      },
    );

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return HourlyWeatherData.fromJson(json);
      } else {
        throw Exception(
          'Failed to load historical weather data: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Failed to fetch historical weather: $e');
    }
  }
}
