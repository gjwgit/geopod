/// Hourly weather data model for historical and forecast data.
///
// Time-stamp: <Tuesday 2026-01-14 10:00:00 +1100>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

/// Hourly weather data point.
class HourlyWeatherPoint {
  HourlyWeatherPoint({
    required this.time,
    required this.temperature,
    this.humidity,
    this.windSpeed,
    this.precipitation,
  });

  final DateTime time;
  final double temperature;
  final int? humidity;
  final double? windSpeed;
  final double? precipitation;
}

/// Hourly weather data series.
class HourlyWeatherData {
  HourlyWeatherData({
    required this.data,
    required this.startDate,
    required this.endDate,
  });

  factory HourlyWeatherData.fromJson(Map<String, dynamic> json) {
    final hourly = json['hourly'] as Map<String, dynamic>;
    final times = (hourly['time'] as List).cast<String>();
    final temperatures = (hourly['temperature_2m'] as List).cast<num>();
    final humidities = hourly.containsKey('relative_humidity_2m')
        ? (hourly['relative_humidity_2m'] as List).cast<num?>()
        : null;
    final windSpeeds = hourly.containsKey('wind_speed_10m')
        ? (hourly['wind_speed_10m'] as List).cast<num?>()
        : null;
    final precipitations = hourly.containsKey('precipitation')
        ? (hourly['precipitation'] as List).cast<num?>()
        : null;

    final data = <HourlyWeatherPoint>[];
    for (var i = 0; i < times.length; i++) {
      data.add(
        HourlyWeatherPoint(
          time: DateTime.parse(times[i]),
          temperature: temperatures[i].toDouble(),
          humidity: humidities?[i]?.toInt(),
          windSpeed: windSpeeds?[i]?.toDouble(),
          precipitation: precipitations?[i]?.toDouble(),
        ),
      );
    }

    return HourlyWeatherData(
      data: data,
      startDate: data.first.time,
      endDate: data.last.time,
    );
  }

  final List<HourlyWeatherPoint> data;
  final DateTime startDate;
  final DateTime endDate;

  /// Get daily average temperatures.
  Map<DateTime, double> getDailyAverages() {
    final dailyTemps = <DateTime, List<double>>{};

    for (final point in data) {
      final date = DateTime(point.time.year, point.time.month, point.time.day);
      dailyTemps.putIfAbsent(date, () => []).add(point.temperature);
    }

    return dailyTemps.map(
      (date, temps) =>
          MapEntry(date, temps.reduce((a, b) => a + b) / temps.length),
    );
  }

  /// Get daily average humidity.
  Map<DateTime, double> getDailyAverageHumidity() {
    final dailyHumidity = <DateTime, List<double>>{};

    for (final point in data) {
      if (point.humidity == null) continue;
      final date = DateTime(point.time.year, point.time.month, point.time.day);
      dailyHumidity.putIfAbsent(date, () => []).add(point.humidity!.toDouble());
    }

    return dailyHumidity.map(
      (date, humidities) => MapEntry(
        date,
        humidities.reduce((a, b) => a + b) / humidities.length,
      ),
    );
  }

  /// Get daily average wind speed.
  Map<DateTime, double> getDailyAverageWindSpeed() {
    final dailyWindSpeed = <DateTime, List<double>>{};

    for (final point in data) {
      if (point.windSpeed == null) continue;
      final date = DateTime(point.time.year, point.time.month, point.time.day);
      dailyWindSpeed.putIfAbsent(date, () => []).add(point.windSpeed!);
    }

    return dailyWindSpeed.map(
      (date, speeds) =>
          MapEntry(date, speeds.reduce((a, b) => a + b) / speeds.length),
    );
  }

  /// Get daily min/max values for a specific data type.
  /// Returns a map where each date maps to (min, max) tuple.
  Map<DateTime, (double, double)> getDailyMinMax(String dataType) {
    final dailyValues = <DateTime, List<double>>{};

    for (final point in data) {
      final date = DateTime(point.time.year, point.time.month, point.time.day);

      switch (dataType) {
        case 'temperature':
          dailyValues.putIfAbsent(date, () => []).add(point.temperature);
        case 'humidity':
          if (point.humidity != null) {
            dailyValues
                .putIfAbsent(date, () => [])
                .add(point.humidity!.toDouble());
          }
        case 'wind_speed':
          if (point.windSpeed != null) {
            dailyValues.putIfAbsent(date, () => []).add(point.windSpeed!);
          }
        case 'precipitation':
          if (point.precipitation != null) {
            dailyValues.putIfAbsent(date, () => []).add(point.precipitation!);
          }
      }
    }

    return dailyValues.map((date, values) {
      if (values.isEmpty) return MapEntry(date, (0.0, 0.0));
      final min = values.reduce((a, b) => a < b ? a : b);
      final max = values.reduce((a, b) => a > b ? a : b);
      return MapEntry(date, (min, max));
    });
  }

  /// Get temperature range (min, max).
  (double min, double max) getTemperatureRange() {
    var min = data.first.temperature;
    var max = data.first.temperature;

    for (final point in data) {
      if (point.temperature < min) min = point.temperature;
      if (point.temperature > max) max = point.temperature;
    }

    return (min, max);
  }

  /// Get humidity range (min, max).
  (double min, double max) getHumidityRange() {
    final validPoints = data.where((p) => p.humidity != null).toList();
    if (validPoints.isEmpty) return (0, 100);

    var min = validPoints.first.humidity!.toDouble();
    var max = validPoints.first.humidity!.toDouble();

    for (final point in validPoints) {
      final humidity = point.humidity!.toDouble();
      if (humidity < min) min = humidity;
      if (humidity > max) max = humidity;
    }

    return (min, max);
  }

  /// Get wind speed range (min, max).
  (double min, double max) getWindSpeedRange() {
    final validPoints = data.where((p) => p.windSpeed != null).toList();
    if (validPoints.isEmpty) return (0, 30);

    var min = validPoints.first.windSpeed!;
    var max = validPoints.first.windSpeed!;

    for (final point in validPoints) {
      if (point.windSpeed! < min) min = point.windSpeed!;
      if (point.windSpeed! > max) max = point.windSpeed!;
    }

    return (min, max);
  }

  /// Get daily total precipitation.
  /// Sums all hourly precipitation values for each day.
  Map<DateTime, double> getDailyTotalPrecipitation() {
    final dailyPrecipitation = <DateTime, List<double>>{};

    for (final point in data) {
      // Include 0 values, skip only null
      if (point.precipitation == null) continue;
      final date = DateTime(point.time.year, point.time.month, point.time.day);
      dailyPrecipitation.putIfAbsent(date, () => []).add(point.precipitation!);
    }

    // Return empty map ONLY if no precipitation data exists at all
    // If all values are 0, we still return the data (not empty map)
    if (dailyPrecipitation.isEmpty) return {};

    return dailyPrecipitation.map(
      (date, precipitations) => MapEntry(
        date,
        precipitations.reduce((a, b) => a + b), // Sum all hourly values
      ),
    );
  }

  /// Get precipitation range (min, max) for hourly data.
  (double min, double max) getPrecipitationRange() {
    final validPoints = data.where((p) => p.precipitation != null).toList();
    if (validPoints.isEmpty) return (0, 2); // Smaller default range

    var min = validPoints.first.precipitation!;
    var max = validPoints.first.precipitation!;

    for (final point in validPoints) {
      if (point.precipitation! < min) min = point.precipitation!;
      if (point.precipitation! > max) max = point.precipitation!;
    }

    // If all values are 0 or very close, set a small visible range
    if (max < 0.1) {
      return (0, 1.0); // Show 0-1mm range for very small/zero precipitation
    }

    if (max - min < 0.1) {
      return (0, max + 0.5);
    }

    return (min, max);
  }

  /// Get daily total precipitation range (min, max).
  /// Used for chart axis scaling when displaying daily totals.
  /// Min is always 0 (precipitation cannot be negative).
  (double min, double max) getDailyTotalPrecipitationRange() {
    final dailyTotals = getDailyTotalPrecipitation();
    if (dailyTotals.isEmpty) return (0, 10); // Default range for no data

    final values = dailyTotals.values.toList();
    var maxValue = values.first;

    for (final value in values) {
      if (value > maxValue) maxValue = value;
    }

    // If all values are 0 or very close, set a visible range
    if (maxValue < 0.5) {
      return (0, 5.0); // Show 0-5mm range for very small/zero precipitation
    }

    if (maxValue < 1.0) {
      return (0, maxValue + 5.0);
    }

    // Add some padding to the max for better visualization
    return (0, maxValue * 1.1);
  }
}
