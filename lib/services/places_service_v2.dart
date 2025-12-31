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

import 'package:shared_preferences/shared_preferences.dart';

import 'package:geopod/models/place.dart';
import 'package:geopod/services/places/places_cache_manager.dart';
import 'package:geopod/services/pod/pod.dart';

export 'package:geopod/models/place.dart';
export 'package:geopod/services/places/places_cache_manager.dart';
export 'package:geopod/services/places/places_import_export.dart';

final placesChangeNotifierV2 = ValueNotifier<int>(0);

/// Places directory path relative to the data directory.
const String _placesDir = 'places';

const String _keyPodPlacesCache = 'pod_places_cache_v2';
const String _keyPodPlacesCacheTimestamp = 'pod_places_cache_timestamp_v2';
const Duration _cacheExpiry = Duration(minutes: 5);

/// Generate filename for a place.
String _placeFileName(String placeId) => 'place_$placeId.json';

/// Generate full path for a place file.
String _placeFilePath(String placeId) =>
    '$_placesDir/${_placeFileName(placeId)}';

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

  /// Read a single place from its file.
  static Future<Place?> _readPlaceFile(String placeId) async {
    try {
      final content = await PodFileSystem.readFile(_placeFilePath(placeId));
      if (content == null || content.trim().isEmpty) return null;
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        return Place.fromJson(decoded, isLocalSource: false);
      }
    } catch (e) {
      debugPrint('PlacesServiceV2._readPlaceFile($placeId) error: $e');
    }
    return null;
  }

  /// Write a single place to its file.
  static Future<bool> _writePlaceFile(Place place) async {
    try {
      final content = jsonEncode(place.toJson());
      return await PodFileSystem.writeFile(
        _placeFilePath(place.id),
        content,
        contentType: PodContentType.json,
        createParentDirs: true,
      );
    } catch (e) {
      debugPrint('PlacesServiceV2._writePlaceFile() error: $e');
      return false;
    }
  }

  /// Delete a place file.
  static Future<bool> _deletePlaceFile(String placeId) async {
    try {
      final success = await PodFileSystem.deleteFile(_placeFilePath(placeId));
      if (success) {
        // Also remove from directory cache
        PodDirectoryService.removeFromCache(_placeFilePath(placeId));
      }
      return success;
    } catch (e) {
      debugPrint('PlacesServiceV2._deletePlaceFile() error: $e');
      return false;
    }
  }

  /// List all place files in the places directory.
  static Future<List<String>> _listPlaceFiles() async {
    try {
      final items = await PodDirectoryService.listDirectory(
        _placesDir,
        forceRefresh: true,
      );
      // Filter for place_*.json files
      return items
          .where(
            (item) =>
                !item.isDirectory &&
                item.name.startsWith('place_') &&
                item.name.endsWith('.json'),
          )
          .map((item) => item.name)
          .toList();
    } catch (e) {
      debugPrint('PlacesServiceV2._listPlaceFiles() error: $e');
      return [];
    }
  }

  /// Extract place ID from filename.
  static String? _extractPlaceId(String filename) {
    // place_{id}.json -> {id}
    if (filename.startsWith('place_') && filename.endsWith('.json')) {
      return filename.substring(6, filename.length - 5);
    }
    return null;
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
        final c = await _getCachedPodPlaces();
        if (c != null) {
          cm.cachePodPlaces(c);
          _refreshPodPlacesInBackground();
          return c;
        }
      }

      // List all place files and read them
      final files = await _listPlaceFiles();
      debugPrint('PlacesServiceV2: Found ${files.length} place files');

      for (final filename in files) {
        final placeId = _extractPlaceId(filename);
        if (placeId != null) {
          final place = await _readPlaceFile(placeId);
          if (place != null) {
            places.add(place);
          }
        }
      }

      places.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      await _cachePodPlacesToStorage(places);
      cm.cachePodPlaces(places);
    } catch (e) {
      debugPrint('PlacesServiceV2.fetchPodPlaces() error: $e');
    }
    return places;
  }

  /// Get cached POD places from SharedPreferences.
  static Future<List<Place>?> _getCachedPodPlaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_keyPodPlacesCache);
      final ts = prefs.getInt(_keyPodPlacesCacheTimestamp);
      if (json == null || ts == null) return null;
      if (DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts)) >
          _cacheExpiry) {
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
  static Future<void> _cachePodPlacesToStorage(List<Place> places) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(places.map((p) => p.toJson()).toList());
      await prefs.setString(_keyPodPlacesCache, json);
      await prefs.setInt(
        _keyPodPlacesCacheTimestamp,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  /// Background refresh of POD places.
  static void _refreshPodPlacesInBackground() {
    unawaited(() async {
      try {
        if (!await PodAuth.isLoggedIn()) return;

        final files = await _listPlaceFiles();
        final places = <Place>[];

        for (final filename in files) {
          final placeId = _extractPlaceId(filename);
          if (placeId != null) {
            final place = await _readPlaceFile(placeId);
            if (place != null) {
              places.add(place);
            }
          }
        }

        if (places.isNotEmpty) {
          places.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          await _cachePodPlacesToStorage(places);
          PlacesCacheManager().cachePodPlaces(places);
        }
      } catch (_) {}
    }());
  }

  /// Save a new place to POD (creates individual file).
  static Future<bool> savePlace(Place place) async {
    try {
      if (!await PodAuth.isLoggedIn()) return false;

      // Write the place to its own file
      final success = await _writePlaceFile(place);

      if (success) {
        debugPrint('PlacesServiceV2: Saved place ${place.id}');

        // Update cache
        final currentPlaces = PlacesCacheManager().podPlaces ?? [];
        final newPlaces = List<Place>.from(currentPlaces);

        // Remove existing if updating
        newPlaces.removeWhere((p) => p.id == place.id);
        newPlaces.insert(0, place);

        PlacesCacheManager().cachePodPlaces(newPlaces);
        await _cachePodPlacesToStorage(newPlaces);
        placesChangeNotifierV2.value++;
      }

      return success;
    } catch (e) {
      debugPrint('PlacesServiceV2.savePlace() error: $e');
      return false;
    }
  }

  /// Delete a place from POD (deletes individual file).
  static Future<bool> deletePlace(Place place) async {
    try {
      if (!await PodAuth.isLoggedIn()) return false;

      // Delete the place file
      final success = await _deletePlaceFile(place.id);

      if (success) {
        debugPrint('PlacesServiceV2: Deleted place ${place.id}');

        // Update cache
        final currentPlaces = PlacesCacheManager().podPlaces ?? [];
        final newPlaces = currentPlaces.where((p) => p.id != place.id).toList();

        PlacesCacheManager().cachePodPlaces(newPlaces);
        await _cachePodPlacesToStorage(newPlaces);
        placesChangeNotifierV2.value++;
      }

      return success;
    } catch (e) {
      debugPrint('PlacesServiceV2.deletePlace() error: $e');
      return false;
    }
  }

  /// Clear all caches.
  static Future<void> clearCache() async {
    _cachedLocalPlaces = null;
    PlacesCacheManager().clearCache();
    PodDirectoryService.clearCache();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyPodPlacesCache);
      await prefs.remove(_keyPodPlacesCacheTimestamp);
    } catch (_) {}
  }
}
