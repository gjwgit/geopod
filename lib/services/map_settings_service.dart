/// Service for managing map display settings with persistence.
///
// Time-stamp: <2025-12-08 Miduo>
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
const String _keyMapSource = 'map_source';
const String _keyRememberViewport = 'map_remember_viewport';
const String _keyInitialLat = 'map_initial_lat';
const String _keyInitialLng = 'map_initial_lng';
const String _keyInitialZoom = 'map_initial_zoom';
const String _keyLastLat = 'map_last_lat';
const String _keyLastLng = 'map_last_lng';
const String _keyLastZoom = 'map_last_zoom';

/// Default viewport settings (Darwin centered).
const double defaultInitialLat = -12.4634;
const double defaultInitialLng = 130.8456;
const double defaultInitialZoom = 11.0;

/// Default colors for map markers.
const Color defaultUserColor = Colors.blue;
const Color defaultLocalColor = Colors.orange;

/// Available map tile sources.
enum MapSource {
  /// OpenStreetMap - Standard street map (day default)
  openStreetMap,

  /// CartoDB Voyager - Colorful detailed map
  cartoVoyager,

  /// CartoDB Dark Matter - Night-optimized dark map
  cartoDarkMatter,

  /// Stadia Alidade Smooth Dark - Elegant dark map
  stadiaAlidadeSmoothDark,

  /// Esri World Street Map - Professional street map
  esriWorldStreetMap,

  /// Esri World Imagery - Satellite imagery
  esriWorldImagery,

  /// Esri World Topo - Topographic map
  esriWorldTopo,

  /// Stamen Terrain - Terrain map with hills shading
  stamenTerrain,

  /// CyclOSM - Optimized for cycling
  cyclOSM,
}

/// Extension for MapSource to get tile URLs and metadata.
extension MapSourceExtension on MapSource {
  /// Returns the tile URL template for this map source.
  String get urlTemplate {
    switch (this) {
      case MapSource.openStreetMap:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case MapSource.cartoVoyager:
        return 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
      case MapSource.cartoDarkMatter:
        return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';
      case MapSource.stadiaAlidadeSmoothDark:
        return 'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}{r}.png';
      case MapSource.esriWorldStreetMap:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}';
      case MapSource.esriWorldImagery:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case MapSource.esriWorldTopo:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}';
      case MapSource.stamenTerrain:
        return 'https://tiles.stadiamaps.com/tiles/stamen_terrain/{z}/{x}/{y}.png';
      case MapSource.cyclOSM:
        return 'https://{s}.tile-cyclosm.openstreetmap.fr/cyclosm/{z}/{x}/{y}.png';
    }
  }

  /// Returns subdomains if applicable (for load balancing).
  List<String> get subdomains {
    switch (this) {
      case MapSource.cartoVoyager:
      case MapSource.cartoDarkMatter:
        return ['a', 'b', 'c', 'd'];
      case MapSource.cyclOSM:
        return ['a', 'b', 'c'];
      default:
        return [];
    }
  }

  /// Display name.
  String get displayName {
    switch (this) {
      case MapSource.openStreetMap:
        return 'OpenStreetMap';
      case MapSource.cartoVoyager:
        return 'CartoDB Voyager';
      case MapSource.cartoDarkMatter:
        return 'CartoDB Dark Matter';
      case MapSource.stadiaAlidadeSmoothDark:
        return 'Stadia Dark';
      case MapSource.esriWorldStreetMap:
        return 'Esri Street Map';
      case MapSource.esriWorldImagery:
        return 'Esri Satellite';
      case MapSource.esriWorldTopo:
        return 'Esri Topographic';
      case MapSource.stamenTerrain:
        return 'Stamen Terrain';
      case MapSource.cyclOSM:
        return 'CyclOSM';
    }
  }

  /// Short description.
  String get description {
    switch (this) {
      case MapSource.openStreetMap:
        return 'Classic open source map';
      case MapSource.cartoVoyager:
        return 'Colorful and detailed';
      case MapSource.cartoDarkMatter:
        return 'Night-optimized dark theme';
      case MapSource.stadiaAlidadeSmoothDark:
        return 'Elegant dark with smooth labels';
      case MapSource.esriWorldStreetMap:
        return 'Professional street map';
      case MapSource.esriWorldImagery:
        return 'High-resolution satellite';
      case MapSource.esriWorldTopo:
        return 'Topographic with contours';
      case MapSource.stamenTerrain:
        return 'Terrain with hill shading';
      case MapSource.cyclOSM:
        return 'Optimized for cycling';
    }
  }

  /// Icon for this map source.
  IconData get icon {
    switch (this) {
      case MapSource.openStreetMap:
      case MapSource.cartoVoyager:
      case MapSource.esriWorldStreetMap:
      case MapSource.cyclOSM:
        return Icons.map;
      case MapSource.cartoDarkMatter:
      case MapSource.stadiaAlidadeSmoothDark:
        return Icons.dark_mode;
      case MapSource.esriWorldImagery:
        return Icons.satellite_alt;
      case MapSource.esriWorldTopo:
      case MapSource.stamenTerrain:
        return Icons.terrain;
    }
  }

  /// Whether this is a priority source (preload on startup).
  bool get isPriority {
    return this == MapSource.openStreetMap || this == MapSource.cartoDarkMatter;
  }

  /// Whether this is a dark/night-optimized map source.
  /// Dark sources don't need color matrix filter in dark mode.
  bool get isDarkSource {
    return this == MapSource.cartoDarkMatter ||
        this == MapSource.stadiaAlidadeSmoothDark;
  }
}

/// Data class holding all map display settings.
class MapSettings {
  /// Whether to show local (canned example) places on the map.
  final bool showLocalPlaces;

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
    this.userPlacesColor = defaultUserColor,
    this.localPlacesColor = defaultLocalColor,
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
  /// Loads settings from SharedPreferences.
  static Future<MapSettings> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final showLocal = prefs.getBool(_keyShowLocalPlaces) ?? true;
      final userColorValue = prefs.getInt(_keyUserPlacesColor);
      final localColorValue = prefs.getInt(_keyLocalPlacesColor);
      final rememberViewport = prefs.getBool(_keyRememberViewport) ?? true;
      final initialLat = prefs.getDouble(_keyInitialLat) ?? defaultInitialLat;
      final initialLng = prefs.getDouble(_keyInitialLng) ?? defaultInitialLng;
      final initialZoom =
          prefs.getDouble(_keyInitialZoom) ?? defaultInitialZoom;

      // Load saved map source, or use time-based default
      final savedSourceIndex = prefs.getInt(_keyMapSource);
      final mapSource =
          savedSourceIndex != null &&
              savedSourceIndex >= 0 &&
              savedSourceIndex < MapSource.values.length
          ? MapSource.values[savedSourceIndex]
          : MapSettings.getDefaultMapSource();

      return MapSettings(
        showLocalPlaces: showLocal,
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
    } catch (_) {
      return MapSettings(mapSource: MapSettings.getDefaultMapSource());
    }
  }

  /// Saves settings to SharedPreferences.
  static Future<bool> saveSettings(MapSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(_keyShowLocalPlaces, settings.showLocalPlaces);
      await prefs.setInt(
        _keyUserPlacesColor,
        settings.userPlacesColor.toARGB32(),
      );
      await prefs.setInt(
        _keyLocalPlacesColor,
        settings.localPlacesColor.toARGB32(),
      );
      await prefs.setInt(_keyMapSource, settings.mapSource.index);
      await prefs.setBool(_keyRememberViewport, settings.rememberViewport);
      await prefs.setDouble(_keyInitialLat, settings.initialLat);
      await prefs.setDouble(_keyInitialLng, settings.initialLng);
      await prefs.setDouble(_keyInitialZoom, settings.initialZoom);

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Saves the last viewed viewport position.
  static Future<bool> saveLastViewport({
    required double lat,
    required double lng,
    required double zoom,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyLastLat, lat);
      await prefs.setDouble(_keyLastLng, lng);
      await prefs.setDouble(_keyLastZoom, zoom);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Loads the last viewed viewport position.
  static Future<ViewportPosition?> loadLastViewport() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_keyLastLat);
      final lng = prefs.getDouble(_keyLastLng);
      final zoom = prefs.getDouble(_keyLastZoom);
      if (lat != null && lng != null && zoom != null) {
        return ViewportPosition(lat: lat, lng: lng, zoom: zoom);
      }
      return null;
    } catch (_) {
      return null;
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
      await prefs.remove(_keyLastLat);
      await prefs.remove(_keyLastLng);
      await prefs.remove(_keyLastZoom);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Represents a map viewport position (center + zoom).
class ViewportPosition {
  final double lat;
  final double lng;
  final double zoom;

  const ViewportPosition({
    required this.lat,
    required this.lng,
    required this.zoom,
  });
}

/// Preloads map settings in the background to warm up cache.
/// Call this on app startup to make settings instantly available.
/// This is fire-and-forget - errors are silently ignored.
Future<void> preloadMapSettings() async {
  try {
    // Fire preload without blocking caller
    await MapSettingsService.loadSettings().catchError((_) {
      // Silently ignore preload errors - will use defaults
      return MapSettings(mapSource: MapSettings.getDefaultMapSource());
    });
  } catch (_) {
    // Silently ignore preload errors
  }
}
