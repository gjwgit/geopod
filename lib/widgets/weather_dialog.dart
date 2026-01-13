/// Weather info dialog widget.
///
// Time-stamp: <Tuesday 2026-01-14 09:00:00 +1100>
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
import '../models/weather_data.dart';
import '../services/weather_service.dart';
import 'hourly_weather_chart.dart';

/// Shows a weather info dialog for the specified location.
Future<void> showWeatherDialog({
  required BuildContext context,
  required double latitude,
  required double longitude,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) =>
        WeatherDialog(latitude: latitude, longitude: longitude),
  );
}

/// Dialog displaying current weather information.
class WeatherDialog extends StatefulWidget {
  const WeatherDialog({
    required this.latitude,
    required this.longitude,
    super.key,
  });

  final double latitude;
  final double longitude;

  @override
  State<WeatherDialog> createState() => _WeatherDialogState();
}

class _WeatherDialogState extends State<WeatherDialog>
    with SingleTickerProviderStateMixin {
  final WeatherService _weatherService = WeatherService();
  late TabController _tabController;
  WeatherData? _weatherData;
  HourlyWeatherData? _pastWeatherData;
  HourlyWeatherData? _historicalWeatherData;
  bool _isLoading = true;
  bool _isLoadingPast = false;
  bool _isLoadingHistorical = false;
  String? _errorMessage;
  bool _showDailyPrecipitation = false; // false = hourly, true = daily
  String _selectedDataType = 'temperature'; // temperature, humidity, wind_speed
  DateTime? _historicalStartDate;
  DateTime? _historicalEndDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadWeather();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadWeather() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final weather = await _weatherService.getCurrentWeather(
        latitude: widget.latitude,
        longitude: widget.longitude,
      );
      if (mounted) {
        setState(() {
          _weatherData = weather;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadPastWeather() async {
    if (_pastWeatherData != null) return; // Already loaded

    setState(() {
      _isLoadingPast = true;
    });

    try {
      final pastWeather = await _weatherService.getPastWeather(
        latitude: widget.latitude,
        longitude: widget.longitude,
        days: 10,
      );
      if (mounted) {
        setState(() {
          _pastWeatherData = pastWeather;
          _isLoadingPast = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPast = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load past weather: $e')),
        );
      }
    }
  }

  Future<void> _loadHistoricalWeather({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    setState(() {
      _isLoadingHistorical = true;
    });

    try {
      // ERA5 archive data has 5-7 days delay, so end date must be at least 7 days ago
      final now = DateTime.now();
      final selectedEndDate = endDate ?? now.subtract(const Duration(days: 7));
      final selectedStartDate =
          startDate ?? selectedEndDate.subtract(const Duration(days: 30));

      final historicalWeather = await _weatherService.getHistoricalWeather(
        latitude: widget.latitude,
        longitude: widget.longitude,
        startDate: selectedStartDate,
        endDate: selectedEndDate,
      );
      if (mounted) {
        setState(() {
          _historicalWeatherData = historicalWeather;
          _historicalStartDate = selectedStartDate;
          _historicalEndDate = selectedEndDate;
          _isLoadingHistorical = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingHistorical = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load historical weather: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.cloud_outlined),
          const SizedBox(width: 8),
          const Text('Weather Info'),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 600,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              onTap: (index) {
                if (index == 1 && _pastWeatherData == null) {
                  _loadPastWeather();
                } else if (index == 2 && _historicalWeatherData == null) {
                  _loadHistoricalWeather();
                }
              },
              tabs: const [
                Tab(text: 'Current'),
                Tab(text: 'Past 10 Days'),
                Tab(text: 'Historical (30d ago)'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Current weather tab
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage != null
                      ? _buildErrorView()
                      : _buildWeatherView(),

                  // Past weather tab
                  _buildPastWeatherView(),

                  // Historical weather tab
                  _buildHistoricalWeatherView(),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
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
          _errorMessage ?? 'Unknown error',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildWeatherView() {
    if (_weatherData == null) return const SizedBox();

    final weather = _weatherData!;
    // Time is already in Sydney timezone from API
    final timeFormat = DateFormat('yyyy-MM-dd HH:mm');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location
          Text(
            'Location: ${widget.latitude.toStringAsFixed(4)}, ${widget.longitude.toStringAsFixed(4)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),

          // Main weather display
          Center(
            child: Column(
              children: [
                Text(weather.weatherIcon, style: const TextStyle(fontSize: 60)),
                const SizedBox(height: 6),
                Text(
                  weather.weatherDescription,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  '${weather.temperature.toStringAsFixed(1)}°C',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Weather details
          _buildWeatherDetail(
            icon: Icons.water_drop,
            label: 'Humidity',
            value: '${weather.humidity}%',
          ),
          _buildWeatherDetail(
            icon: Icons.air,
            label: 'Wind Speed',
            value: '${weather.windSpeed.toStringAsFixed(1)} km/h',
          ),
          _buildWindDirectionDetail(weather),
          _buildPrecipitationDetail(weather),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Updated: ${timeFormat.format(weather.time)} (Sydney)',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherDetail({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.grey[600]),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildWindDirectionDetail(WeatherData weather) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.navigation, size: 24, color: Colors.grey[600]),
          const SizedBox(width: 16),
          const Expanded(
            child: Text('Wind Direction', style: TextStyle(fontSize: 15)),
          ),
          Tooltip(
            message:
                '''Wind Direction: ${weather.windDirectionFullName}
Angle: ${weather.windDirection}° (clockwise from North)
Wind is blowing FROM the ${weather.windDirectionFullName.toLowerCase()}
Arrow shows where wind is blowing TO''',
            child: Row(
              children: [
                Text(
                  weather.windDirectionArrow,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  weather.windDirectionDescription,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.info_outline, size: 16, color: Colors.grey[500]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrecipitationDetail(WeatherData weather) {
    final precipValue = _showDailyPrecipitation
        ? weather.precipitation *
              24 // Approximate daily total
        : weather.precipitation;
    final unit = _showDailyPrecipitation ? 'mm/day' : 'mm/h';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.umbrella, size: 24, color: Colors.grey[600]),
          const SizedBox(width: 16),
          const Expanded(
            child: Text('Precipitation', style: TextStyle(fontSize: 15)),
          ),
          InkWell(
            onTap: () {
              setState(() {
                _showDailyPrecipitation = !_showDailyPrecipitation;
              });
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  Text(
                    '${precipValue.toStringAsFixed(1)} $unit',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.swap_horiz, size: 16, color: Colors.grey[600]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPastWeatherView() {
    if (_isLoadingPast) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pastWeatherData == null) {
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
          Text(
            'Location: ${widget.latitude.toStringAsFixed(4)}, ${widget.longitude.toStringAsFixed(4)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          _buildDataTypeSelector(),
          const SizedBox(height: 16),
          HourlyWeatherChart(
            data: _pastWeatherData!,
            dataType: _selectedDataType,
            latitude: widget.latitude,
            longitude: widget.longitude,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoricalWeatherView() {
    if (_isLoadingHistorical) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_historicalWeatherData == null) {
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
              if (_historicalWeatherData != null)
                Text(
                  'Data from ${_historicalWeatherData!.startDate.year}-${_historicalWeatherData!.startDate.month.toString().padLeft(2, '0')}-${_historicalWeatherData!.startDate.day.toString().padLeft(2, '0')} to ${_historicalWeatherData!.endDate.year}-${_historicalWeatherData!.endDate.month.toString().padLeft(2, '0')}-${_historicalWeatherData!.endDate.day.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDateRangeSelector(),
          const SizedBox(height: 8),
          Text(
            'Location: ${widget.latitude.toStringAsFixed(4)}, ${widget.longitude.toStringAsFixed(4)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          _buildDataTypeSelector(),
          const SizedBox(height: 16),
          HourlyWeatherChart(
            data: _historicalWeatherData!,
            dataType: _selectedDataType,
            latitude: widget.latitude,
            longitude: widget.longitude,
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    final now = DateTime.now();
    final maxEndDate = now.subtract(const Duration(days: 7));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Date Range (ERA5 has 5-7 day delay)',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final selectedDate = await showDatePicker(
                        context: context,
                        initialDate:
                            _historicalStartDate ??
                            maxEndDate.subtract(const Duration(days: 30)),
                        firstDate: DateTime(1940),
                        lastDate: maxEndDate.subtract(const Duration(days: 1)),
                        helpText: 'Select Start Date',
                      );
                      if (selectedDate != null) {
                        setState(() {
                          _historicalStartDate = selectedDate;
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _historicalStartDate == null
                          ? 'Start Date'
                          : DateFormat(
                              'yyyy-MM-dd',
                            ).format(_historicalStartDate!),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final minDate = _historicalStartDate ?? DateTime(1940);
                      final selectedDate = await showDatePicker(
                        context: context,
                        initialDate: _historicalEndDate ?? maxEndDate,
                        firstDate: minDate.add(const Duration(days: 1)),
                        lastDate: maxEndDate,
                        helpText: 'Select End Date',
                      );
                      if (selectedDate != null) {
                        final daysDiff = selectedDate
                            .difference(minDate)
                            .inDays;
                        if (daysDiff > 365) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Date range cannot exceed 365 days',
                                ),
                              ),
                            );
                          }
                          return;
                        }
                        setState(() {
                          _historicalEndDate = selectedDate;
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _historicalEndDate == null
                          ? 'End Date'
                          : DateFormat(
                              'yyyy-MM-dd',
                            ).format(_historicalEndDate!),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    (_historicalStartDate != null && _historicalEndDate != null)
                    ? () {
                        _loadHistoricalWeather(
                          startDate: _historicalStartDate,
                          endDate: _historicalEndDate,
                        );
                      }
                    : null,
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Load Data'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTypeSelector() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment<String>(
          value: 'temperature',
          label: Text('Temp'),
          icon: Icon(Icons.thermostat, size: 16),
        ),
        ButtonSegment<String>(
          value: 'humidity',
          label: Text('Humidity'),
          icon: Icon(Icons.water_drop, size: 16),
        ),
        ButtonSegment<String>(
          value: 'wind_speed',
          label: Text('Wind'),
          icon: Icon(Icons.air, size: 16),
        ),
        ButtonSegment<String>(
          value: 'precipitation',
          label: Text('Rain'),
          icon: Icon(Icons.umbrella, size: 16),
        ),
      ],
      selected: {_selectedDataType},
      onSelectionChanged: (Set<String> newSelection) {
        setState(() {
          _selectedDataType = newSelection.first;
        });
      },
    );
  }
}
