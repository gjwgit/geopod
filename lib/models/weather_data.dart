/// Weather data model for Open-Meteo API.
///
// Time-stamp: <Tuesday 2026-01-14 09:00:00 +1100>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

/// Weather data from Open-Meteo API.
class WeatherData {
  WeatherData({
    required this.temperature,
    required this.weatherCode,
    required this.windSpeed,
    required this.windDirection,
    required this.humidity,
    required this.precipitation,
    required this.time,
    this.dailyMaxTemp,
    this.dailyMinTemp,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>;

    // Get today's min/max temperature from daily data if available
    double? maxTemp;
    double? minTemp;
    if (json.containsKey('daily')) {
      final daily = json['daily'] as Map<String, dynamic>;
      if (daily.containsKey('temperature_2m_max')) {
        final maxList = daily['temperature_2m_max'] as List;
        if (maxList.isNotEmpty) maxTemp = (maxList[0] as num).toDouble();
      }
      if (daily.containsKey('temperature_2m_min')) {
        final minList = daily['temperature_2m_min'] as List;
        if (minList.isNotEmpty) minTemp = (minList[0] as num).toDouble();
      }
    }

    return WeatherData(
      temperature: (current['temperature_2m'] as num).toDouble(),
      weatherCode: current['weather_code'] as int,
      windSpeed: (current['wind_speed_10m'] as num).toDouble(),
      windDirection: (current['wind_direction_10m'] as num).toInt(),
      humidity: (current['relative_humidity_2m'] as num).toInt(),
      precipitation: (current['precipitation'] as num).toDouble(),
      time: DateTime.parse(current['time'] as String),
      dailyMaxTemp: maxTemp,
      dailyMinTemp: minTemp,
    );
  }

  final double temperature;
  final int weatherCode;
  final double windSpeed;
  final int windDirection;
  final int humidity;
  final double precipitation;
  final DateTime time;
  final double? dailyMaxTemp;
  final double? dailyMinTemp;

  /// Get weather description from WMO weather code.
  String get weatherDescription {
    return switch (weatherCode) {
      0 => 'Clear sky',
      1 => 'Mainly clear',
      2 => 'Partly cloudy',
      3 => 'Overcast',
      45 => 'Foggy',
      48 => 'Depositing rime fog',
      51 => 'Light drizzle',
      53 => 'Moderate drizzle',
      55 => 'Dense drizzle',
      56 => 'Light freezing drizzle',
      57 => 'Dense freezing drizzle',
      61 => 'Slight rain',
      63 => 'Moderate rain',
      65 => 'Heavy rain',
      66 => 'Light freezing rain',
      67 => 'Heavy freezing rain',
      71 => 'Slight snow',
      73 => 'Moderate snow',
      75 => 'Heavy snow',
      77 => 'Snow grains',
      80 => 'Slight rain showers',
      81 => 'Moderate rain showers',
      82 => 'Violent rain showers',
      85 => 'Slight snow showers',
      86 => 'Heavy snow showers',
      95 => 'Thunderstorm',
      96 => 'Thunderstorm with slight hail',
      99 => 'Thunderstorm with heavy hail',
      _ => 'Unknown',
    };
  }

  /// Get weather icon based on weather code.
  String get weatherIcon {
    return switch (weatherCode) {
      0 || 1 => '☀️',
      2 => '⛅',
      3 => '☁️',
      45 || 48 => '🌫️',
      >= 51 && <= 57 => '🌧️',
      >= 61 && <= 67 => '🌧️',
      >= 71 && <= 77 => '❄️',
      >= 80 && <= 82 => '🌦️',
      >= 85 && <= 86 => '🌨️',
      >= 95 && <= 99 => '⛈️',
      _ => '🌡️',
    };
  }

  /// Get wind direction description from degrees.
  /// 0° = North, 90° = East, 180° = South, 270° = West
  String get windDirectionDescription {
    if (windDirection >= 337.5 || windDirection < 22.5) return 'N';
    if (windDirection >= 22.5 && windDirection < 67.5) return 'NE';
    if (windDirection >= 67.5 && windDirection < 112.5) return 'E';
    if (windDirection >= 112.5 && windDirection < 157.5) return 'SE';
    if (windDirection >= 157.5 && windDirection < 202.5) return 'S';
    if (windDirection >= 202.5 && windDirection < 247.5) return 'SW';
    if (windDirection >= 247.5 && windDirection < 292.5) return 'W';
    if (windDirection >= 292.5 && windDirection < 337.5) return 'NW';
    return 'N';
  }

  /// Get wind direction full name.
  String get windDirectionFullName {
    return switch (windDirectionDescription) {
      'N' => 'North',
      'NE' => 'Northeast',
      'E' => 'East',
      'SE' => 'Southeast',
      'S' => 'South',
      'SW' => 'Southwest',
      'W' => 'West',
      'NW' => 'Northwest',
      _ => 'Unknown',
    };
  }

  /// Get arrow icon for wind direction.
  /// Arrow points in the direction the wind is blowing TO.
  String get windDirectionArrow {
    if (windDirection >= 337.5 || windDirection < 22.5) return '↑';
    if (windDirection >= 22.5 && windDirection < 67.5) return '↗';
    if (windDirection >= 67.5 && windDirection < 112.5) return '→';
    if (windDirection >= 112.5 && windDirection < 157.5) return '↘';
    if (windDirection >= 157.5 && windDirection < 202.5) return '↓';
    if (windDirection >= 202.5 && windDirection < 247.5) return '↙';
    if (windDirection >= 247.5 && windDirection < 292.5) return '←';
    if (windDirection >= 292.5 && windDirection < 337.5) return '↖';
    return '↑';
  }
}
