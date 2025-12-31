/// Places service using the new POD file system.
///
/// This is a drop-in replacement for places_service.dart that uses
/// the new GeoPod file system instead of solidpod's encrypted storage.
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

/// Places file path relative to the data directory.
const String _placesRelativePath = 'places/places.json';

const String _keyPodPlacesCache = 'pod_places_cache_v2';
const String _keyPodPlacesCacheTimestamp = 'pod_places_cache_timestamp_v2';
const Duration _cacheExpiry = Duration(minutes: 5);

/// Places service using GeoPod's own file system.
///
/// Key differences from the old PlacesService:
/// - Uses PodFileSystem instead of solidpod's encrypted storage
/// - Files are stored as plain JSON (no encryption)
/// - Simpler error handling
/// - Same path structure: geopod/data/places/places.json
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

  /// Read places JSON from POD using new file system.
  static Future<String?> _readJsonFile() async {
    return await PodFileSystem.readFile(_placesRelativePath);
  }

  /// Write places JSON to POD using new file system.
  static Future<bool> _writeJsonFile(String content) async {
    return await PodFileSystem.writeFile(
      _placesRelativePath,
      content,
      contentType: PodContentType.json,
      createParentDirs: true,
    );
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

  /// Fetch places from POD.
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

      // Read from POD
      final content = await _readJsonFile();
      if (content == null || content.trim().isEmpty) return places;

      final decoded = jsonDecode(content);
      if (decoded is List) {
        for (final i in decoded) {
          if (i is Map<String, dynamic>) {
            try {
              places.add(Place.fromJson(i, isLocalSource: false));
            } catch (_) {}
          }
        }
      } else if (decoded is Map<String, dynamic>) {
        try {
          places.add(Place.fromJson(decoded, isLocalSource: false));
        } catch (_) {}
      }

      places.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      await _cachePodPlaces(content);
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
  static Future<void> _cachePodPlaces(String json) async {
    try {
      final prefs = await SharedPreferences.getInstance();
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
        final content = await _readJsonFile();
        if (content != null && content.trim().isNotEmpty) {
          await _cachePodPlaces(content);
          final places = <Place>[];
          final decoded = jsonDecode(content);
          if (decoded is List) {
            for (final i in decoded) {
              if (i is Map<String, dynamic>) {
                try {
                  places.add(Place.fromJson(i, isLocalSource: false));
                } catch (_) {}
              }
            }
          }
          if (places.isNotEmpty) {
            PlacesCacheManager().cachePodPlaces(places);
          }
        }
      } catch (_) {}
    }());
  }

  /// Save a new place to POD.
  static Future<bool> savePlace(Place place) async {
    try {
      if (!await PodAuth.isLoggedIn()) return false;

      // Get current places
      final currentPlaces = await fetchPodPlaces(forceRefresh: true);

      // Check for duplicate
      final existingIndex = currentPlaces.indexWhere(
        (p) => p.id == place.id && p.lat == place.lat && p.lng == place.lng,
      );

      final newPlaces = List<Place>.from(currentPlaces);
      if (existingIndex >= 0) {
        newPlaces[existingIndex] = place;
      } else {
        newPlaces.insert(0, place);
      }

      // Save to POD
      final json = jsonEncode(newPlaces.map((p) => p.toJson()).toList());
      final success = await _writeJsonFile(json);

      if (success) {
        PlacesCacheManager().cachePodPlaces(newPlaces);
        placesChangeNotifierV2.value++;
      }

      return success;
    } catch (e) {
      debugPrint('PlacesServiceV2.savePlace() error: $e');
      return false;
    }
  }

  /// Delete a place from POD.
  static Future<bool> deletePlace(Place place) async {
    try {
      if (!await PodAuth.isLoggedIn()) return false;

      final currentPlaces = await fetchPodPlaces(forceRefresh: true);
      final newPlaces = currentPlaces
          .where(
            (p) =>
                !(p.id == place.id && p.lat == place.lat && p.lng == place.lng),
          )
          .toList();

      final json = jsonEncode(newPlaces.map((p) => p.toJson()).toList());
      final success = await _writeJsonFile(json);

      if (success) {
        PlacesCacheManager().cachePodPlaces(newPlaces);
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
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyPodPlacesCache);
      await prefs.remove(_keyPodPlacesCacheTimestamp);
    } catch (_) {}
  }
}
