/// Service for managing map display settings with persistence.
///
// Time-stamp: <2025-12-05 Miduo>
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

/// Keys for SharedPreferences storage.
const String _keyShowLocalPlaces = 'map_show_local_places';
const String _keyUserPlacesColor = 'map_user_places_color';
const String _keyLocalPlacesColor = 'map_local_places_color';

/// Default colors for map markers.
const Color defaultUserColor = Colors.blue;
const Color defaultLocalColor = Colors.orange;

/// Data class holding all map display settings.
class MapSettings {
  /// Whether to show local (canned example) places on the map.
  final bool showLocalPlaces;

  /// Color for user's saved places (from Pod).
  final Color userPlacesColor;

  /// Color for local canned example places.
  final Color localPlacesColor;

  const MapSettings({
    this.showLocalPlaces = true,
    this.userPlacesColor = defaultUserColor,
    this.localPlacesColor = defaultLocalColor,
  });

  /// Creates a copy with optional overrides.
  MapSettings copyWith({
    bool? showLocalPlaces,
    Color? userPlacesColor,
    Color? localPlacesColor,
  }) {
    return MapSettings(
      showLocalPlaces: showLocalPlaces ?? this.showLocalPlaces,
      userPlacesColor: userPlacesColor ?? this.userPlacesColor,
      localPlacesColor: localPlacesColor ?? this.localPlacesColor,
    );
  }
}

/// Service for loading and saving map display settings.
class MapSettingsService {
  /// Loads settings from SharedPreferences.
  static Future<MapSettings> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final showLocal = prefs.getBool(_keyShowLocalPlaces) ?? true;
      final userColorValue = prefs.getInt(_keyUserPlacesColor);
      final localColorValue = prefs.getInt(_keyLocalPlacesColor);

      return MapSettings(
        showLocalPlaces: showLocal,
        userPlacesColor:
            userColorValue != null ? Color(userColorValue) : defaultUserColor,
        localPlacesColor:
            localColorValue != null ? Color(localColorValue) : defaultLocalColor,
      );
    } catch (_) {
      // Return defaults on error.
      return const MapSettings();
    }
  }

  /// Saves settings to SharedPreferences.
  static Future<bool> saveSettings(MapSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(_keyShowLocalPlaces, settings.showLocalPlaces);
      await prefs.setInt(_keyUserPlacesColor, settings.userPlacesColor.toARGB32());
      await prefs.setInt(_keyLocalPlacesColor, settings.localPlacesColor.toARGB32());

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Saves only the showLocalPlaces setting.
  static Future<bool> saveShowLocalPlaces(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyShowLocalPlaces, value);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Saves only the user places color.
  static Future<bool> saveUserPlacesColor(Color color) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyUserPlacesColor, color.toARGB32());
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Saves only the local places color.
  static Future<bool> saveLocalPlacesColor(Color color) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyLocalPlacesColor, color.toARGB32());
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Resets all settings to defaults.
  static Future<bool> resetToDefaults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyShowLocalPlaces);
      await prefs.remove(_keyUserPlacesColor);
      await prefs.remove(_keyLocalPlacesColor);
      return true;
    } catch (_) {
      return false;
    }
  }
}

