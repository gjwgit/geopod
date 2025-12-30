/// Viewport-related logic for GeoMapWidget.
///
// Time-stamp: <Wednesday 2025-12-18 08:22:27 +1100 Graham Williams>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.
///
/// Authors: Graham Williams, Miduo

library;

import 'package:flutter_map/flutter_map.dart';

import 'package:geopod/services/map_settings_service.dart';

/// Saves the current viewport position to persistent storage.
void saveCurrentViewport({
  required MapController mapController,
  required MapSettings mapSettings,
}) {
  if (mapSettings.rememberViewport) {
    final center = mapController.camera.center;
    final zoom = mapController.camera.zoom;
    MapSettingsService.saveLastViewport(
      lat: center.latitude,
      lng: center.longitude,
      zoom: zoom,
    );
  }
}

/// Adjusts zoom level if it exceeds the map source's max native zoom.
///
/// Returns true if zoom was adjusted.
bool adjustZoomForMapSource({
  required MapController mapController,
  required MapSettings mapSettings,
}) {
  final currentZoom = mapController.camera.zoom;
  final maxNativeZoom = mapSettings.mapSource.maxNativeZoom.toDouble();

  if (currentZoom > maxNativeZoom) {
    mapController.move(mapController.camera.center, maxNativeZoom);
    return true;
  }
  return false;
}
