/// Cache storage operations for PlacesServiceV2.
///
/// Handles SharedPreferences caching for POD places.
///
// Time-stamp: <2026-01-01 Miduo>
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
import 'package:geopod/services/places/places_cache_manager.dart';
import 'package:geopod/services/pod/pod.dart';

const String keyPodPlacesCache = 'pod_places_cache_v2';
const String keyPodPlacesCacheTimestamp = 'pod_places_cache_timestamp_v2';
const Duration cacheExpiry = Duration(minutes: 5);

/// Get cached POD places from SharedPreferences.
Future<List<Place>?> getCachedPodPlaces() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(keyPodPlacesCache);
    final ts = prefs.getInt(keyPodPlacesCacheTimestamp);
    if (json == null || ts == null) return null;
    if (DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts)) >
        cacheExpiry) {
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
    return places.isEmpty ? null : places;
  } catch (_) {
    return null;
  }
}

/// Cache POD places to SharedPreferences.
Future<void> cachePodPlacesToStorage(List<Place> places) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(places.map((p) => p.toJson()).toList());
    await prefs.setString(keyPodPlacesCache, json);
    await prefs.setInt(
      keyPodPlacesCacheTimestamp,
      DateTime.now().millisecondsSinceEpoch,
    );
  } catch (_) {}
}

/// Clear POD cache from SharedPreferences.
Future<void> clearPodCacheStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyPodPlacesCache);
    await prefs.remove(keyPodPlacesCacheTimestamp);
  } catch (_) {}
}

/// Clear all caches (memory + storage + directory).
Future<void> clearAllCaches() async {
  PlacesCacheManager().clearCache();
  PodDirectoryService.clearCache();
  await clearPodCacheStorage();
}

/// Clear only POD cache (keep local places cache).
Future<void> clearPodCacheOnly() async {
  PlacesCacheManager().clearPodCacheOnly();
  PodDirectoryService.clearCache();
  await clearPodCacheStorage();
}
