/// Viewport-related logic for GeoMapWidget.
///
// Time-stamp: <2025-12-31 Miduo>
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
