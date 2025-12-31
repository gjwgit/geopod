/// Places service using the new POD file system.
///
/// Each place is stored as a separate JSON file in the places directory.
/// File naming convention: place_{id}.json
///
// Time-stamp: <2026-01-01 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:geopod/models/place.dart';
import 'package:geopod/services/places/places_cache_manager.dart';
import 'package:geopod/services/places/places_import_export.dart';
import 'package:geopod/services/places_v2/places_cache_storage.dart';
import 'package:geopod/services/places_v2/places_file_operations.dart';
import 'package:geopod/services/places_v2/places_pod_operations.dart';
import 'package:geopod/services/pod/pod.dart';

export 'package:geopod/models/place.dart';
export 'package:geopod/services/places/places_cache_manager.dart';
export 'package:geopod/services/places/places_import_export.dart';

/// Notifier for places changes (increment to trigger UI refresh).
final placesChangeNotifierV2 = ValueNotifier<int>(0);

/// Places service using GeoPod's own file system.
///
/// Key differences from the old PlacesService:
/// - Each place is stored as a separate file: places/place_{id}.json
/// - Uses PodFileSystem instead of solidpod's encrypted storage
/// - Files are stored as plain JSON (no encryption)
/// - Deleting a place simply deletes its file
class PlacesServiceV2 {
  static List<Place>? _cachedLocalPlaces;

  /// Load local (bundled) places from assets.
  static Future<List<Place>> loadLocalPlaces() async {
    if (_cachedLocalPlaces != null) return _cachedLocalPlaces!;
    final places = <Place>[];
    try {
      final json = await rootBundle.loadString('assets/data/places.json');
      final decoded = jsonDecode(json);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            try {
              places.add(Place.fromJson(item, isLocalSource: true));
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
    _cachedLocalPlaces = places;
    return places;
  }

  /// Fetch all places (local + POD).
  static Future<List<Place>> fetchPlaces({bool forceRefresh = false}) async {
    final cm = PlacesCacheManager();
    if (!forceRefresh) {
      final c = cm.allPlaces;
      if (c != null) return c;
    }
    final results = await Future.wait([
      loadLocalPlaces(),
      fetchPodPlaces(forceRefresh: forceRefresh),
    ]);
    final all = <Place>[...results[1], ...results[0]];
    cm.cacheAllPlaces(all);
    return all;
  }

  /// Fetch places from POD (reads individual files).
  static Future<List<Place>> fetchPodPlaces({bool forceRefresh = false}) async {
    final places = <Place>[];
    final cm = PlacesCacheManager();

    try {
      if (!await PodAuth.isLoggedIn()) return places;

      // Try memory cache first
      if (!forceRefresh) {
        final mc = cm.podPlaces;
        if (mc != null) {
          _refreshPodPlacesInBackground();
          return mc;
        }
      }

      // Try local storage cache
      if (!forceRefresh) {
        final c = await getCachedPodPlaces();
        if (c != null) {
          cm.cachePodPlaces(c);
          _refreshPodPlacesInBackground();
          return c;
        }
      }

      // List all place files (use cache unless forceRefresh)
      final files = await listPlaceFiles(forceRefresh: forceRefresh);
      debugPrint('PlacesServiceV2: Found ${files.length} place files');

      // Read files in parallel for better performance
      final placeIds = files
          .map((f) => extractPlaceId(f))
          .where((id) => id != null)
          .cast<String>()
          .toList();

      final results = await Future.wait(
        placeIds.map((id) => readPlaceFile(id)),
      );

      for (final place in results) {
        if (place != null) {
          places.add(place);
        }
      }

      places.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      await cachePodPlacesToStorage(places);
      cm.cachePodPlaces(places);
    } catch (e) {
      debugPrint('PlacesServiceV2.fetchPodPlaces() error: $e');
    }
    return places;
  }

  /// Background refresh of POD places.
  static void _refreshPodPlacesInBackground() {
    unawaited(() async {
      try {
        if (!await PodAuth.isLoggedIn()) return;

        // Force refresh directory listing in background
        final files = await listPlaceFiles(forceRefresh: true);

        // Read files in parallel
        final placeIds = files
            .map((f) => extractPlaceId(f))
            .where((id) => id != null)
            .cast<String>()
            .toList();

        final results = await Future.wait(
          placeIds.map((id) => readPlaceFile(id)),
        );

        final places = results.whereType<Place>().toList();

        if (places.isNotEmpty) {
          places.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          await cachePodPlacesToStorage(places);
          PlacesCacheManager().cachePodPlaces(places);
        }
      } catch (_) {}
    }());
  }

  /// Save a new place to POD.
  static Future<bool> savePlace(Place place) => savePlaceToPod(place);

  /// Delete a place from POD.
  static Future<bool> deletePlace(Place place) => deletePlaceFromPod(place);

  /// Clear all caches.
  static Future<void> clearCache() async {
    _cachedLocalPlaces = null;
    await clearAllCaches();
  }

  /// Clear only POD cache (keep local places cache).
  static Future<void> clearPodCacheOnly() async {
    PlacesCacheManager().clearPodCacheOnly();
    PodDirectoryService.clearCache();
    await clearPodCacheStorage();
  }

  /// Refresh POD data only (keeping local places).
  static Future<List<Place>> refreshPodDataOnly() async {
    final cm = PlacesCacheManager();
    final local = await loadLocalPlaces();
    await clearPodCacheOnly();
    final pod = await fetchPodPlaces(forceRefresh: true);
    final all = <Place>[...pod, ...local];
    cm.cacheAllPlaces(all);
    return all;
  }

  // ============================================================
  // Compatibility methods (for migration from old PlacesService)
  // ============================================================

  /// Add a new place (compatibility wrapper for savePlace).
  static Future<bool> addPlace(
    Place place,
    BuildContext context,
    Widget returnWidget,
  ) async => savePlace(place);

  /// Delete a place by ID (compatibility wrapper).
  static Future<bool> deletePlaceById(
    String placeId,
    BuildContext context,
    Widget returnWidget,
  ) => deletePlaceByIdFromPod(placeId);

  /// Export places to file.
  static Future<bool> exportPlaces(List<Place> places) =>
      exportPlacesToFile(places);

  /// Import places from file.
  static Future<ImportResult> importPlaces() => importPlacesFromFile();

  /// Merge imported places with existing ones.
  static Future<bool> mergeImportedPlaces(
    List<Place> imported,
    BuildContext context,
    Widget returnWidget, {
    void Function(int, int)? onProgress,
  }) => mergeImportedPlacesToPod(imported, onProgress: onProgress);

  /// Clear all places from POD.
  static Future<bool> clearAllPlaces(
    BuildContext context,
    Widget returnWidget,
  ) => clearAllPlacesFromPod();

  /// Update an existing place.
  static Future<bool> updatePlace(
    Place updated,
    BuildContext context,
    Widget returnWidget, {
    bool coordinatesChanged = false,
  }) => updatePlaceInPod(updated, coordinatesChanged: coordinatesChanged);
}

/// Preload places data in background.
Future<void> preloadPlacesDataV2() async {
  try {
    unawaited(
      PlacesServiceV2.fetchPlaces(
        forceRefresh: false,
      ).catchError((_) => <Place>[]),
    );
  } catch (_) {}
}
