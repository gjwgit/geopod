/// Local (SharedPreferences) storage for the last map viewport.
///
/// Map display settings and the last viewport are device-specific preferences,
/// stored locally only — they are intentionally not synced to the POD.
///
// Time-stamp: <2026-06-15>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:shared_preferences/shared_preferences.dart';

/// Keys for last viewport storage.

const String keyLastLat = 'map_last_lat';
const String keyLastLng = 'map_last_lng';
const String keyLastZoom = 'map_last_zoom';

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

/// Saves the last viewed viewport position.

Future<bool> saveLastViewport({
  required double lat,
  required double lng,
  required double zoom,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(keyLastLat, lat);
    await prefs.setDouble(keyLastLng, lng);
    await prefs.setDouble(keyLastZoom, zoom);
    return true;
  } catch (_) {
    return false;
  }
}

/// Loads the last viewed viewport position.

Future<ViewportPosition?> loadLastViewport() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(keyLastLat);
    final lng = prefs.getDouble(keyLastLng);
    final zoom = prefs.getDouble(keyLastZoom);
    if (lat != null && lng != null && zoom != null) {
      return ViewportPosition(lat: lat, lng: lng, zoom: zoom);
    }
    return null;
  } catch (_) {
    return null;
  }
}
