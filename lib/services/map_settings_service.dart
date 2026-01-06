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

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:geopod/services/map_settings_pod.dart';
import 'package:geopod/services/map_source.dart';

export 'package:geopod/services/map_settings_pod.dart' show ViewportPosition;
export 'package:geopod/services/map_source.dart';

/// Keys for SharedPreferences storage.
const String _keyShowLocalPlaces = 'map_show_local_places';
const String _keyShowEncryptedPlaces = 'map_show_encrypted_places';
const String _keyUserPlacesColor = 'map_user_places_color';
const String _keyLocalPlacesColor = 'map_local_places_color';
const String _keyEncryptedPlacesColor = 'map_encrypted_places_color';
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
const Color defaultLocalColor = Colors.orange;
const Color defaultEncryptedColor = Colors.purple;

/// Data class holding all map display settings.
class MapSettings {
  /// Whether to show local (canned example) places on the map.
  final bool showLocalPlaces;

  /// Whether to show encrypted places on the map.
  /// Encrypted places require security key to decrypt.
  final bool showEncryptedPlaces;

  /// Color for user's saved places (from Pod).
  final Color userPlacesColor;

  /// Color for local canned example places.
  final Color localPlacesColor;

  /// Color for encrypted places.
  final Color encryptedPlacesColor;

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
    this.showEncryptedPlaces = false,
    this.userPlacesColor = defaultUserColor,
    this.localPlacesColor = defaultLocalColor,
    this.encryptedPlacesColor = defaultEncryptedColor,
    this.rememberViewport = true,
    this.initialLat = defaultInitialLat,
    this.initialLng = defaultInitialLng,
    this.initialZoom = defaultInitialZoom,
    MapSource? mapSource,
  }) : mapSource = mapSource ?? MapSource.openStreetMap;

  /// Time-based default map source.
  /// Always defaults to OpenStreetMap.
  /// Night mode styling is handled by app theme + color filter.
  static MapSource getDefaultMapSource() {
    return MapSource.openStreetMap;
  }

  /// Creates a copy with optional overrides.
  MapSettings copyWith({
    bool? showLocalPlaces,
    bool? showEncryptedPlaces,
    Color? userPlacesColor,
    Color? localPlacesColor,
    Color? encryptedPlacesColor,
    MapSource? mapSource,
    bool? rememberViewport,
    double? initialLat,
    double? initialLng,
    double? initialZoom,
  }) {
    return MapSettings(
      showLocalPlaces: showLocalPlaces ?? this.showLocalPlaces,
      showEncryptedPlaces: showEncryptedPlaces ?? this.showEncryptedPlaces,
      userPlacesColor: userPlacesColor ?? this.userPlacesColor,
      localPlacesColor: localPlacesColor ?? this.localPlacesColor,
      encryptedPlacesColor: encryptedPlacesColor ?? this.encryptedPlacesColor,
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
  /// Convert MapSettings to JSON map.
  static Map<String, dynamic> _settingsToJson(MapSettings settings) {
    return {
      'showLocalPlaces': settings.showLocalPlaces,
      'showEncryptedPlaces': settings.showEncryptedPlaces,
      'userPlacesColor': settings.userPlacesColor.toARGB32(),
      'localPlacesColor': settings.localPlacesColor.toARGB32(),
      'encryptedPlacesColor': settings.encryptedPlacesColor.toARGB32(),
      'mapSource': settings.mapSource.index,
      'rememberViewport': settings.rememberViewport,
      'initialLat': settings.initialLat,
      'initialLng': settings.initialLng,
      'initialZoom': settings.initialZoom,
    };
  }

  /// Create MapSettings from JSON map.
  static MapSettings _settingsFromJson(Map<String, dynamic> json) {
    final savedSourceIndex = json['mapSource'] as int?;
    final mapSource =
        savedSourceIndex != null &&
            savedSourceIndex >= 0 &&
            savedSourceIndex < MapSource.values.length
        ? MapSource.values[savedSourceIndex]
        : MapSettings.getDefaultMapSource();

    return MapSettings(
      showLocalPlaces: json['showLocalPlaces'] as bool? ?? true,
      showEncryptedPlaces: json['showEncryptedPlaces'] as bool? ?? false,
      userPlacesColor: json['userPlacesColor'] != null
          ? Color(json['userPlacesColor'] as int)
          : defaultUserColor,
      localPlacesColor: json['localPlacesColor'] != null
          ? Color(json['localPlacesColor'] as int)
          : defaultLocalColor,
      encryptedPlacesColor: json['encryptedPlacesColor'] != null
          ? Color(json['encryptedPlacesColor'] as int)
          : defaultEncryptedColor,
      mapSource: mapSource,
      rememberViewport: json['rememberViewport'] as bool? ?? true,
      initialLat: (json['initialLat'] as num?)?.toDouble() ?? defaultInitialLat,
      initialLng: (json['initialLng'] as num?)?.toDouble() ?? defaultInitialLng,
      initialZoom:
          (json['initialZoom'] as num?)?.toDouble() ?? defaultInitialZoom,
    );
  }

  /// Save settings to SharedPreferences.
  static Future<void> _saveToPrefs(MapSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowLocalPlaces, settings.showLocalPlaces);
    await prefs.setBool(_keyShowEncryptedPlaces, settings.showEncryptedPlaces);
    await prefs.setInt(
      _keyUserPlacesColor,
      settings.userPlacesColor.toARGB32(),
    );
    await prefs.setInt(
      _keyLocalPlacesColor,
      settings.localPlacesColor.toARGB32(),
    );
    await prefs.setInt(
      _keyEncryptedPlacesColor,
      settings.encryptedPlacesColor.toARGB32(),
    );
    await prefs.setInt(_keyMapSource, settings.mapSource.index);
    await prefs.setBool(_keyRememberViewport, settings.rememberViewport);
    await prefs.setDouble(_keyInitialLat, settings.initialLat);
    await prefs.setDouble(_keyInitialLng, settings.initialLng);
    await prefs.setDouble(_keyInitialZoom, settings.initialZoom);
  }

  /// Load settings from SharedPreferences.
  static Future<MapSettings> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final showLocal = prefs.getBool(_keyShowLocalPlaces) ?? true;
    final showEncrypted = prefs.getBool(_keyShowEncryptedPlaces) ?? false;
    final userColorValue = prefs.getInt(_keyUserPlacesColor);
    final localColorValue = prefs.getInt(_keyLocalPlacesColor);
    final encryptedColorValue = prefs.getInt(_keyEncryptedPlacesColor);
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
      showEncryptedPlaces: showEncrypted,
      userPlacesColor: userColorValue != null
          ? Color(userColorValue)
          : defaultUserColor,
      localPlacesColor: localColorValue != null
          ? Color(localColorValue)
          : defaultLocalColor,
      encryptedPlacesColor: encryptedColorValue != null
          ? Color(encryptedColorValue)
          : defaultEncryptedColor,
      mapSource: mapSource,
      rememberViewport: rememberViewport,
      initialLat: initialLat,
      initialLng: initialLng,
      initialZoom: initialZoom,
    );
  }

  /// Check if we have cached settings in SharedPreferences.
  static Future<bool> _hasLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    // Check if any setting key exists (mapSource is always saved)
    return prefs.containsKey(_keyMapSource);
  }

  /// Loads settings from SharedPreferences (fast, non-blocking).
  /// POD sync is done separately via syncFromPod().
  static Future<MapSettings> loadSettings() async {
    try {
      // Always load from SharedPreferences first (fast, no network)
      debugPrint('loadSettings: loading from SharedPreferences');
      return await _loadFromPrefs();
    } catch (e) {
      debugPrint('Error loading settings: $e');
      return MapSettings(mapSource: MapSettings.getDefaultMapSource());
    }
  }

  /// Smart load: if no local cache, try POD first (for first login).
  /// Otherwise load from local cache (fast).
  static Future<MapSettings> loadSettingsSmart() async {
    try {
      // Check if we have local cache
      if (await _hasLocalCache()) {
        debugPrint('loadSettingsSmart: using local cache');
        return await _loadFromPrefs();
      }

      // No local cache - try to load from POD first (first login scenario)
      debugPrint('loadSettingsSmart: no local cache, trying POD...');
      final podData = await readSettingsFromPod();
      if (podData != null) {
        debugPrint('loadSettingsSmart: loaded from POD');
        final settings = _settingsFromJson(podData);
        // Save to local cache
        await _saveToPrefs(settings);
        return settings;
      }

      // POD also empty - use defaults
      debugPrint('loadSettingsSmart: POD empty, using defaults');
      return MapSettings(mapSource: MapSettings.getDefaultMapSource());
    } catch (e) {
      debugPrint('Error in loadSettingsSmart: $e');
      return MapSettings(mapSource: MapSettings.getDefaultMapSource());
    }
  }

  /// Saves settings to SharedPreferences only (fast, no network).
  /// POD sync is done separately via syncToPod() when needed.
  static Future<bool> saveSettings(MapSettings settings) async {
    try {
      // Save to SharedPreferences only (fast, no blocking)
      await _saveToPrefs(settings);
      return true;
    } catch (e) {
      debugPrint('Error saving settings: $e');
      return false;
    }
  }

  /// Manually sync current settings to POD.
  /// Call this when user closes settings dialog or at app exit.
  static Future<bool> syncToPod() async {
    try {
      final settings = await _loadFromPrefs();
      return await writeSettingsToPod(_settingsToJson(settings));
    } catch (e) {
      debugPrint('Error syncing settings to POD: $e');
      return false;
    }
  }

  /// Gets the initial viewport based on settings.
  /// If rememberViewport is ON, returns last viewport if available.
  /// Otherwise returns the configured initial viewport.
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
      await prefs.remove(_keyShowLocalPlaces);
      await prefs.remove(_keyUserPlacesColor);
      await prefs.remove(_keyLocalPlacesColor);
      await prefs.remove(_keyMapSource);
      await prefs.remove(_keyRememberViewport);
      await prefs.remove(_keyInitialLat);
      await prefs.remove(_keyInitialLng);
      await prefs.remove(_keyInitialZoom);
      await prefs.remove(keyLastLat);
      await prefs.remove(keyLastLng);
      await prefs.remove(keyLastZoom);

      // Write default settings to POD (not empty object)
      final defaultSettings = MapSettings(
        mapSource: MapSettings.getDefaultMapSource(),
      );
      unawaited(
        writeSettingsToPod(_settingsToJson(defaultSettings)).then((success) {
          debugPrint('resetToDefaults: POD sync ${success ? 'ok' : 'failed'}');
        }),
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Sync settings from POD to local (background, non-blocking).
  /// Call this after login to ensure local settings match POD.
  /// Returns the synced settings if POD has data, null otherwise.
  static Future<MapSettings?> syncFromPod() async {
    try {
      final podData = await readSettingsFromPod();
      if (podData != null) {
        debugPrint('syncFromPod: updating local with POD settings');
        final settings = _settingsFromJson(podData);
        await _saveToPrefs(settings);
        return settings;
      } else {
        // POD has no settings, upload local settings to POD
        debugPrint('syncFromPod: POD empty, uploading local settings');
        final localSettings = await _loadFromPrefs();
        unawaited(writeSettingsToPod(_settingsToJson(localSettings)));
        return null;
      }
    } catch (e) {
      debugPrint('Error syncing from POD: $e');
      return null;
    }
  }

  /// Start background sync from POD.
  /// This is non-blocking and updates settings silently.
  /// [onSettingsUpdated] is called if POD has newer settings.
  static void startBackgroundSync({
    void Function(MapSettings)? onSettingsUpdated,
  }) {
    unawaited(
      syncFromPod().then((settings) {
        if (settings != null && onSettingsUpdated != null) {
          debugPrint('startBackgroundSync: settings updated from POD');
          onSettingsUpdated(settings);
        }
      }),
    );
  }
}

/// Preloads map settings in the background to warm up cache.
/// Call this on app startup to make settings instantly available.
/// Uses smart loading: if no local cache, loads from POD first.
Future<void> preloadMapSettings() async {
  try {
    // Smart load: if no local cache, try POD first
    await MapSettingsService.loadSettingsSmart().catchError((_) {
      // Silently ignore preload errors - will use defaults
      return MapSettings(mapSource: MapSettings.getDefaultMapSource());
    });
  } catch (_) {
    // Silently ignore preload errors
  }
}

/// Syncs settings from POD in background.
/// Call this after preloadMapSettings() to keep settings in sync.
/// Only needed when local cache exists (preloadMapSettings handles first login).
Future<void> syncSettingsFromPod() async {
  try {
    // Small delay to let UI settle first
    await Future.delayed(const Duration(seconds: 3));
    await MapSettingsService.syncFromPod();
  } catch (_) {
    // Silently ignore sync errors
  }
}
