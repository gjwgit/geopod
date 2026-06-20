/// Settings loading and validation logic for GeoMap.
///
// Time-stamp: <Tuesday 2026-01-14 +1100>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.
///
/// Authors: Miduo

library;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:geopod/services/map_settings_service.dart';
import 'package:geopod/services/map_viewport_store.dart';

/// Result of loading map settings.

class LoadSettingsResult {
  final MapSettings settings;
  final LatLng? initialCenter;
  final double? initialZoom;
  final bool viewportInitialized;

  LoadSettingsResult({
    required this.settings,
    this.initialCenter,
    this.initialZoom,
    required this.viewportInitialized,
  });
}

/// Loads map settings synchronously from SharedPreferences.

Future<LoadSettingsResult> loadMapSettingsSync({
  required bool viewportInitialized,
}) async {
  try {
    final settings = await MapSettingsService.loadSettings();

    if (viewportInitialized) {
      return LoadSettingsResult(
        settings: settings,
        viewportInitialized: viewportInitialized,
      );
    }

    try {
      final viewport = await MapSettingsService.getStartupViewport(settings);
      return LoadSettingsResult(
        settings: settings,
        initialCenter: LatLng(viewport.lat, viewport.lng),
        initialZoom: viewport.zoom,
        viewportInitialized: true,
      );
    } catch (_) {
      return LoadSettingsResult(
        settings: settings,
        viewportInitialized: viewportInitialized,
      );
    }
  } catch (_) {
    return LoadSettingsResult(
      settings: MapSettings(mapSource: MapSettings.getDefaultMapSource()),
      viewportInitialized: viewportInitialized,
    );
  }
}

/// Saves current viewport position if rememberViewport is enabled.

void saveViewportIfEnabled({
  required MapController mapController,
  required MapSettings mapSettings,
}) {
  if (!mapSettings.rememberViewport) return;
  try {
    final center = mapController.camera.center;
    final zoom = mapController.camera.zoom;
    saveLastViewport(lat: center.latitude, lng: center.longitude, zoom: zoom);
  } catch (_) {}
}

/// Handles settings dialog changes.

class SettingsChangeResult {
  final bool mapSourceChanged;

  SettingsChangeResult({required this.mapSourceChanged});
}

/// Computes what changed when settings are updated.

SettingsChangeResult computeSettingsChanges({
  required MapSettings oldSettings,
  required MapSettings newSettings,
}) {
  return SettingsChangeResult(
    mapSourceChanged: oldSettings.mapSource != newSettings.mapSource,
  );
}
