/// News-related logic for GeoMapWidget.
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

import 'package:latlong2/latlong.dart';

/// Check if news cache should be updated based on position change.
///
/// Returns true if position/zoom changed significantly enough to warrant
/// a cache update. This prevents excessive updates during small movements.

bool shouldUpdateNewsCache({
  required LatLng newPosition,
  required double newZoom,
  required LatLng? lastPosition,
  required double? lastZoom,
}) {
  // First time or no previous position.
  if (lastPosition == null || lastZoom == null) {
    return true;
  }

  // Calculate position change in degrees.
  final latDiff = (newPosition.latitude - lastPosition.latitude).abs();
  final lngDiff = (newPosition.longitude - lastPosition.longitude).abs();
  final zoomDiff = (newZoom - lastZoom).abs();

  // Thresholds: ~1km movement or 1 zoom level change
  // At zoom 12, 0.01 degrees ≈ 1.1 km.

  const positionThreshold = 0.01;
  const zoomThreshold = 1.0;

  return latDiff > positionThreshold ||
      lngDiff > positionThreshold ||
      zoomDiff > zoomThreshold;
}
