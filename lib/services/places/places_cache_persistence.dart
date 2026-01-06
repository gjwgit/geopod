/// Persistence service for places cache using SharedPreferences.
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

/// Handles persistent caching of places data to SharedPreferences.
///
/// This allows the app to show previously loaded places immediately
/// on startup while fetching fresh data in the background.
class PlacesCachePersistence {
  /// Key for storing cached Pod places JSON in SharedPreferences.
  static const String _podPlacesCacheKey = 'geopod_pod_places_cache';

  /// Key for storing cache timestamp.
  static const String _podPlacesCacheTimestampKey =
      'geopod_pod_places_cache_timestamp';

  /// Maximum cache age in hours before considering it stale.
  static const int _maxCacheAgeHours = 24;

  /// Get cached Pod places from SharedPreferences.
  ///
  /// Returns null if no cache exists or cache is too old.
  static Future<List<Place>?> getCachedPodPlaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check cache age
      final timestamp = prefs.getInt(_podPlacesCacheTimestampKey);
      if (timestamp != null) {
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final age = DateTime.now().difference(cacheTime);
        if (age.inHours > _maxCacheAgeHours) {
          // Cache is too old, return null to trigger refresh
          return null;
        }
      }

      final cachedJson = prefs.getString(_podPlacesCacheKey);
      if (cachedJson == null || cachedJson.isEmpty) return null;

      final decoded = jsonDecode(cachedJson);
      final places = <Place>[];

      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            try {
              places.add(Place.fromJson(item, isLocalSource: false));
            } catch (_) {
              // Skip malformed entries
            }
          }
        }
      }

      return places.isEmpty ? null : places;
    } catch (_) {
      return null;
    }
  }

  /// Cache Pod places JSON content to SharedPreferences.
  ///
  /// [content] should be the raw JSON string from the Pod.
  static Future<void> cachePodPlaces(String content) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_podPlacesCacheKey, content);
      await prefs.setInt(
        _podPlacesCacheTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // Silently fail - caching is best-effort
    }
  }

  /// Clear the Pod places cache.
  static Future<void> clearPodPlacesCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_podPlacesCacheKey);
      await prefs.remove(_podPlacesCacheTimestampKey);
    } catch (_) {
      // Silently fail
    }
  }

  /// Check if cache exists and is valid.
  static Future<bool> hasFreshCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_podPlacesCacheTimestampKey);
      if (timestamp == null) return false;

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final age = DateTime.now().difference(cacheTime);
      return age.inHours <= _maxCacheAgeHours;
    } catch (_) {
      return false;
    }
  }
}
