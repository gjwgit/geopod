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

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:geopod/models/place.dart';
import 'package:geopod/services/map_settings_pod.dart';
import 'package:geopod/services/map_settings_service.dart';
import 'package:geopod/services/places/encrypted_places_service.dart';

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

    // Load viewport separately
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

/// Validates the saved encrypted places setting.
/// Returns true if validation passed and encrypted places should be loaded.
Future<bool> validateSavedEncryptedSetting({
  required MapSettings mapSettings,
  required bool isLoggedIn,
  required List<Place> allPlaces,
}) async {
  if (!mapSettings.showEncryptedPlaces) return false;

  if (!isLoggedIn) {
    // Not logged in, setting should be reset
    return false;
  }

  // Check if encrypted places are already loaded
  final hasEncryptedPlaces = allPlaces.any((p) => p.isEncrypted);
  if (hasEncryptedPlaces) {
    debugPrint(
      'validateSavedEncryptedSetting: encrypted places already loaded, skipping',
    );
    return false;
  }

  // Check if security key is already available
  final hasKey = await EncryptedPlacesService.isSecurityKeyAvailable();
  debugPrint(
    'validateSavedEncryptedSetting: hasKey=$hasKey, will load encrypted places',
  );

  // Always return true to trigger loading (will prompt for key if needed)
  return true;
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
  } catch (_) {
    // Ignore errors during viewport saving
  }
}

/// Handles settings dialog changes.
class SettingsChangeResult {
  final bool mapSourceChanged;
  final bool encryptedToggled;
  final bool encryptedEnabled;

  SettingsChangeResult({
    required this.mapSourceChanged,
    required this.encryptedToggled,
    required this.encryptedEnabled,
  });
}

/// Computes what changed when settings are updated.
SettingsChangeResult computeSettingsChanges({
  required MapSettings oldSettings,
  required MapSettings newSettings,
}) {
  final mapSourceChanged = oldSettings.mapSource != newSettings.mapSource;
  final encryptedToggled =
      oldSettings.showEncryptedPlaces != newSettings.showEncryptedPlaces;
  final encryptedEnabled = newSettings.showEncryptedPlaces;

  return SettingsChangeResult(
    mapSourceChanged: mapSourceChanged,
    encryptedToggled: encryptedToggled,
    encryptedEnabled: encryptedEnabled,
  );
}
