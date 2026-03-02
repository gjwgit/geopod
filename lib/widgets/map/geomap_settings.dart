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

import 'package:geopod/models/place.dart';
import 'package:geopod/services/map_settings_pod.dart';
import 'package:geopod/services/map_settings_service.dart';
import 'package:geopod/services/places/encrypted_places_service.dart';
import 'package:geopod/services/places_service.dart' show PlacesCacheManager;

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

    // Load viewport separately.

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

/// Guard against concurrent/duplicate encrypted-places load attempts.

bool _encryptedLoadInProgress = false;

/// Validates the saved encrypted places setting.
/// Returns true if validation passed and encrypted places should be loaded.
///
/// Optimised loading strategy:
///   1. Service cache hit  → skip network, re-merge from cache, return false
///   2. Widget state hit   → places already in allPlaces, return false
///   3. Concurrent guard   → another load is in flight, return false
///   4. Otherwise          → proceed to load (network fetch required)

Future<bool> validateSavedEncryptedSetting({
  required MapSettings mapSettings,
  required bool isLoggedIn,
  required List<Place> allPlaces,
}) async {
  if (!mapSettings.showEncryptedPlaces) return false;

  if (!isLoggedIn) {
    // Not logged in, setting should be reset.
    return false;
  }

  // Fast path: EncryptedPlacesService already has data in memory.
  // This happens when a regular-place edit triggers a PlacesCacheManager flush
  // but the encrypted-places service cache is untouched. Re-inject into the
  // main cache so the next fetchPlaces call returns the full merged list.
  if (EncryptedPlacesService.hasLoadedEncryptedPlaces) {
    if (!allPlaces.any((p) => p.isEncrypted)) {
      final cachedEnc = EncryptedPlacesService.getCachedEncryptedPlaces()!;
      final cm = PlacesCacheManager();
      final current = cm.allPlaces;
      if (current != null) {
        cm.cacheAllPlaces([...current, ...cachedEnc]);
      }
    }
    return false;
  }

  // Widget state already contains encrypted places.
  if (allPlaces.any((p) => p.isEncrypted)) {
    return false;
  }

  // Prevent duplicate concurrent loads.
  if (_encryptedLoadInProgress) {
    return false;
  }

  _encryptedLoadInProgress = true;
  return true;
}

/// Resets the in-progress guard so future loads are allowed.

void encryptedLoadInProgressReset() {
  _encryptedLoadInProgress = false;
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
    // Ignore errors during viewport saving.
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
