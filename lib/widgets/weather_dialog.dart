/// Weather info dialog widget.
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

import 'package:geopod/models/hourly_weather_data.dart';
import 'package:geopod/models/weather_data.dart';
import 'package:geopod/services/weather_service.dart';
import 'package:geopod/utils/ui_utils.dart';
import 'package:geopod/utils/widget_utils.dart';

import 'weather/weather_date_selector.dart';
import 'weather/weather_view_widgets.dart';

/// Shows a weather info dialog for the specified location.

Future<void> showWeatherDialog({
  required BuildContext context,
  required double latitude,
  required double longitude,
  String? address,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) => WeatherDialog(
      latitude: latitude,
      longitude: longitude,
      address: address,
    ),
  );
}

/// Dialog displaying current weather information.

class WeatherDialog extends StatefulWidget {
  const WeatherDialog({
    required this.latitude,
    required this.longitude,
    this.address,
    super.key,
  });

  final double latitude;
  final double longitude;
  final String? address;

  @override
  State<WeatherDialog> createState() => _WeatherDialogState();
}

class _WeatherDialogState extends State<WeatherDialog>
    with SingleTickerProviderStateMixin {
  final WeatherService _weatherService = WeatherService();
  late TabController _tabController;
  WeatherData? _weatherData;
  HourlyWeatherData? _pastWeatherData;
  HourlyWeatherData? _forecastWeatherData;
  HourlyWeatherData? _historicalWeatherData;
  bool _isLoading = true;
  bool _isLoadingPast = false;
  bool _isLoadingForecast = false;
  bool _isLoadingHistorical = false;
  String? _errorMessage;
  bool _showDailyPrecipitation = false; // false = hourly, true = daily total
  String _selectedDataType = 'temperature'; // temperature, humidity, wind_speed
  DateTime? _historicalStartDate;
  DateTime? _historicalEndDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
      safeSetState(this, () {
        _weatherData = weather;
        _isLoading = false;
      });
    } catch (e) {
      safeSetState(this, () {
        _errorMessage = e.toString();
        _isLoading = false;
      });
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
      safeSetState(this, () {
        _pastWeatherData = pastWeather;
        _isLoadingPast = false;
      });
    } catch (e) {
      safeSetState(this, () {
        _isLoadingPast = false;
      });
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to load past weather: $e');
      }
    }
  }

  Future<void> _loadForecastWeather() async {
    if (_forecastWeatherData != null) return; // Already loaded

    setState(() {
      _isLoadingForecast = true;
    });

    try {
      final forecastWeather = await _weatherService.getForecastWeather(
        latitude: widget.latitude,
        longitude: widget.longitude,
        days: 7,
      );
      safeSetState(this, () {
        _forecastWeatherData = forecastWeather;
        _isLoadingForecast = false;
      });
    } catch (e) {
      safeSetState(this, () {
        _isLoadingForecast = false;
      });
      if (mounted) {
        SnackBarHelper.showError(
          context,
          'Failed to load forecast weather: $e',
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
      // ERA5 archive data has 5-7 days delay, so end date must be at least 7 days ago.
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
      safeSetState(this, () {
        _historicalWeatherData = historicalWeather;
        _historicalStartDate = selectedStartDate;
        _historicalEndDate = selectedEndDate;
        _isLoadingHistorical = false;
      });
    } catch (e) {
      safeSetState(this, () {
        _isLoadingHistorical = false;
      });
      if (mounted) {
        SnackBarHelper.showError(
          context,
          'Failed to load historical weather: $e',
          duration: const Duration(seconds: 5),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.wb_sunny_outlined),
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
                } else if (index == 2 && _forecastWeatherData == null) {
                  _loadForecastWeather();
                } else if (index == 3 && _historicalWeatherData == null) {
                  _loadHistoricalWeather();
                }
              },
              tabs: const [
                Tab(text: 'Current'),
                Tab(text: 'Past 10 Days'),
                Tab(text: 'Forecast (7 Days)'),
                Tab(text: 'Historical (30d ago)'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Current weather tab.
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage != null
                      ? _buildErrorView()
                      : _buildWeatherView(),

                  // Past weather tab.
                  _buildPastWeatherView(),

                  // Forecast weather tab.
                  _buildForecastWeatherView(),

                  // Historical weather tab.
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
    return buildErrorView(context, _errorMessage);
  }

  Widget _buildWeatherView() {
    if (_weatherData == null) return const SizedBox();

    return buildCurrentWeatherView(
      context: context,
      weatherData: _weatherData!,
      latitude: widget.latitude,
      longitude: widget.longitude,
      address: widget.address,
      showDailyPrecipitation: _showDailyPrecipitation,
      onTogglePrecipitation: () {
        setState(() {
          _showDailyPrecipitation = !_showDailyPrecipitation;
        });
      },
    );
  }

  Widget _buildPastWeatherView() {
    return buildPastWeatherView(
      context: context,
      isLoading: _isLoadingPast,
      pastWeatherData: _pastWeatherData,
      latitude: widget.latitude,
      longitude: widget.longitude,
      address: widget.address,
      selectedDataType: _selectedDataType,
      onDataTypeChanged: (newType) {
        setState(() {
          _selectedDataType = newType;
        });
      },
    );
  }

  Widget _buildForecastWeatherView() {
    return buildForecastWeatherView(
      context: context,
      isLoading: _isLoadingForecast,
      forecastWeatherData: _forecastWeatherData,
      latitude: widget.latitude,
      longitude: widget.longitude,
      address: widget.address,
      selectedDataType: _selectedDataType,
      onDataTypeChanged: (newType) {
        setState(() {
          _selectedDataType = newType;
        });
      },
    );
  }

  Widget _buildHistoricalWeatherView() {
    return buildHistoricalWeatherView(
      context: context,
      isLoading: _isLoadingHistorical,
      historicalWeatherData: _historicalWeatherData,
      latitude: widget.latitude,
      longitude: widget.longitude,
      address: widget.address,
      selectedDataType: _selectedDataType,
      dateRangeSelector: _buildDateRangeSelector(),
      onDataTypeChanged: (newType) {
        setState(() {
          _selectedDataType = newType;
        });
      },
    );
  }

  Widget _buildDateRangeSelector() {
    return buildDateRangeSelector(
      context: context,
      historicalStartDate: _historicalStartDate,
      historicalEndDate: _historicalEndDate,
      onStartDateChanged: (date) {
        setState(() {
          _historicalStartDate = date;
        });
      },
      onEndDateChanged: (date) {
        setState(() {
          _historicalEndDate = date;
        });
      },
      onLoadData: () {
        _loadHistoricalWeather(
          startDate: _historicalStartDate,
          endDate: _historicalEndDate,
        );
      },
    );
  }
}
