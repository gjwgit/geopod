/// Service for managing map display settings with persistence.
///
// Time-stamp: <2026-01-02 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program.  If not, see <https://opensource.org/license/gpl-3-0>.
///
/// Authors: Graham Williams, Miduo

library;

import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:geopod/services/map_source.dart';
import 'package:geopod/services/map_viewport_store.dart';

export 'package:geopod/services/map_source.dart';
export 'package:geopod/services/map_viewport_store.dart' show ViewportPosition;

/// Keys for SharedPreferences storage.

const String _keyShowLocalPlaces = 'map_show_local_places';
const String _keyHideAllMarkers = 'map_hide_all_markers';
const String _keyUserPlacesColor = 'map_user_places_color';
const String _keyLocalPlacesColor = 'map_local_places_color';
const String _keyMapSource = 'map_source';
const String _keyRememberViewport = 'map_remember_viewport';
const String _keyInitialLat = 'map_initial_lat';
const String _keyInitialLng = 'map_initial_lng';
const String _keyInitialZoom = 'map_initial_zoom';

/// Default viewport settings (Darwin centered).

const double defaultInitialLat = -12.4634;
const double defaultInitialLng = 130.8456;
const double defaultInitialZoom = 11.0;

/// Default colors for map markers.

const Color defaultUserColor = Colors.blue;
const Color defaultLocalColor = Colors.red;

/// Data class holding all map display settings.

class MapSettings {
  /// Whether to show local (canned example) places on the map.
  final bool showLocalPlaces;

  /// Whether to hide all markers on the map.
  final bool hideAllMarkers;

  /// Color for user's saved places (from Pod).
  final Color userPlacesColor;

  /// Color for local canned example places.
  final Color localPlacesColor;

  /// Current map tile source.
  final MapSource mapSource;

  /// Whether to remember the last viewed viewport on restart.
  final bool rememberViewport;

  /// Initial viewport latitude (used when rememberViewport is off).
  final double initialLat;

  /// Initial viewport longitude (used when rememberViewport is off).
  final double initialLng;

  /// Initial viewport zoom level (used when rememberViewport is off).
  final double initialZoom;

  const MapSettings({
    this.showLocalPlaces = true,
    this.hideAllMarkers = false,
    this.userPlacesColor = defaultUserColor,
    this.localPlacesColor = defaultLocalColor,
    this.rememberViewport = true,
    this.initialLat = defaultInitialLat,
    this.initialLng = defaultInitialLng,
    this.initialZoom = defaultInitialZoom,
    MapSource? mapSource,
  }) : mapSource = mapSource ?? MapSource.openStreetMap;

  /// Always defaults to OpenStreetMap.

  static MapSource getDefaultMapSource() => MapSource.openStreetMap;

  /// Creates a copy with optional overrides.

  MapSettings copyWith({
    bool? showLocalPlaces,
    bool? hideAllMarkers,
    Color? userPlacesColor,
    Color? localPlacesColor,
    MapSource? mapSource,
    bool? rememberViewport,
    double? initialLat,
    double? initialLng,
    double? initialZoom,
  }) {
    return MapSettings(
      showLocalPlaces: showLocalPlaces ?? this.showLocalPlaces,
      hideAllMarkers: hideAllMarkers ?? this.hideAllMarkers,
      userPlacesColor: userPlacesColor ?? this.userPlacesColor,
      localPlacesColor: localPlacesColor ?? this.localPlacesColor,
      mapSource: mapSource ?? this.mapSource,
      rememberViewport: rememberViewport ?? this.rememberViewport,
      initialLat: initialLat ?? this.initialLat,
      initialLng: initialLng ?? this.initialLng,
      initialZoom: initialZoom ?? this.initialZoom,
    );
  }
}

/// Service for loading and saving map display settings.

class MapSettingsService {
  static Future<void> _saveToPrefs(MapSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool(_keyShowLocalPlaces, settings.showLocalPlaces),
      prefs.setBool(_keyHideAllMarkers, settings.hideAllMarkers),
      prefs.setInt(_keyUserPlacesColor, settings.userPlacesColor.toARGB32()),
      prefs.setInt(_keyLocalPlacesColor, settings.localPlacesColor.toARGB32()),
      prefs.setInt(_keyMapSource, settings.mapSource.index),
      prefs.setBool(_keyRememberViewport, settings.rememberViewport),
      prefs.setDouble(_keyInitialLat, settings.initialLat),
      prefs.setDouble(_keyInitialLng, settings.initialLng),
      prefs.setDouble(_keyInitialZoom, settings.initialZoom),
    ]);
  }

  static Future<MapSettings> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final showLocal = prefs.getBool(_keyShowLocalPlaces) ?? true;
    final hideMarkers = prefs.getBool(_keyHideAllMarkers) ?? false;
    final userColorValue = prefs.getInt(_keyUserPlacesColor);
    final localColorValue = prefs.getInt(_keyLocalPlacesColor);
    final rememberViewport = prefs.getBool(_keyRememberViewport) ?? true;
    final initialLat = prefs.getDouble(_keyInitialLat) ?? defaultInitialLat;
    final initialLng = prefs.getDouble(_keyInitialLng) ?? defaultInitialLng;
    final initialZoom = prefs.getDouble(_keyInitialZoom) ?? defaultInitialZoom;

    final savedSourceIndex = prefs.getInt(_keyMapSource);
    final mapSource =
        savedSourceIndex != null &&
            savedSourceIndex >= 0 &&
            savedSourceIndex < MapSource.values.length
        ? MapSource.values[savedSourceIndex]
        : MapSettings.getDefaultMapSource();

    return MapSettings(
      showLocalPlaces: showLocal,
      hideAllMarkers: hideMarkers,
      userPlacesColor: userColorValue != null
          ? Color(userColorValue)
          : defaultUserColor,
      localPlacesColor: localColorValue != null
          ? Color(localColorValue)
          : defaultLocalColor,
      mapSource: mapSource,
      rememberViewport: rememberViewport,
      initialLat: initialLat,
      initialLng: initialLng,
      initialZoom: initialZoom,
    );
  }

  /// Loads settings from SharedPreferences.

  static Future<MapSettings> loadSettings() async {
    try {
      return await _loadFromPrefs();
    } catch (e) {
      debugPrint('Error loading settings: $e');
      return MapSettings(mapSource: MapSettings.getDefaultMapSource());
    }
  }

  /// Load settings from local cache (SharedPreferences).

  static Future<MapSettings> loadSettingsSmart() async {
    try {
      return await _loadFromPrefs();
    } catch (e) {
      debugPrint('Error in loadSettingsSmart: $e');
      return MapSettings(mapSource: MapSettings.getDefaultMapSource());
    }
  }

  /// Saves settings to SharedPreferences.

  static Future<bool> saveSettings(MapSettings settings) async {
    try {
      await _saveToPrefs(settings);
      return true;
    } catch (e) {
      debugPrint('Error saving settings: $e');
      return false;
    }
  }

  /// Gets the initial viewport based on settings.

  static Future<ViewportPosition> getStartupViewport(
    MapSettings settings,
  ) async {
    if (settings.rememberViewport) {
      final last = await loadLastViewport();
      if (last != null) return last;
    }
    return ViewportPosition(
      lat: settings.initialLat,
      lng: settings.initialLng,
      zoom: settings.initialZoom,
    );
  }

  /// Resets all settings to defaults.

  static Future<bool> resetToDefaults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_keyShowLocalPlaces),
        prefs.remove(_keyUserPlacesColor),
        prefs.remove(_keyLocalPlacesColor),
        prefs.remove(_keyMapSource),
        prefs.remove(_keyRememberViewport),
        prefs.remove(_keyInitialLat),
        prefs.remove(_keyInitialLng),
        prefs.remove(_keyInitialZoom),
        prefs.remove(keyLastLat),
        prefs.remove(keyLastLng),
        prefs.remove(keyLastZoom),
      ]);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Preloads map settings in the background to warm up cache.

Future<void> preloadMapSettings() async {
  try {
    await MapSettingsService.loadSettings();
  } catch (_) {}
}
