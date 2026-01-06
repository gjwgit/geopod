/// SharedPreferences-based persistence for places cache.
///
// Time-stamp: <2026-01-07 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:geopod/models/place.dart';

const String _keyPodPlacesCache = 'pod_places_cache';
const String _keyPodPlacesCacheTimestamp = 'pod_places_cache_timestamp';
const Duration _defaultCacheExpiry = Duration(minutes: 5);

/// Handles SharedPreferences-based persistence for POD places cache.
class PlacesCachePersistence {
  /// Retrieves cached POD places from SharedPreferences.
  ///
  /// Returns null if cache is missing or expired.
  static Future<List<Place>?> getCachedPodPlaces({
    Duration cacheExpiry = _defaultCacheExpiry,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_keyPodPlacesCache);
      final ts = prefs.getInt(_keyPodPlacesCacheTimestamp);
      if (json == null || ts == null) return null;

      // Check if cache has expired
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(ts);
      if (DateTime.now().difference(cacheTime) > cacheExpiry) {
        return null;
      }

      final places = <Place>[];
      final decoded = jsonDecode(json);
      if (decoded is List) {
        for (final i in decoded) {
          if (i is Map<String, dynamic>) {
            try {
              places.add(Place.fromJson(i, isLocalSource: false));
            } catch (_) {}
          }
        }
      }
      places.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return places;
    } catch (_) {
      return null;
    }
  }

  /// Saves POD places JSON to SharedPreferences cache.
  static Future<void> cachePodPlaces(String json) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPodPlacesCache, json);
      await prefs.setInt(
        _keyPodPlacesCacheTimestamp,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  /// Clears the POD places cache from SharedPreferences.
  static Future<void> clearPodPlacesCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyPodPlacesCache);
      await prefs.remove(_keyPodPlacesCacheTimestamp);
    } catch (_) {}
  }
}
