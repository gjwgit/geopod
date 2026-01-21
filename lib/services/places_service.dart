/// Service for managing places data in the user's Solid Pod.
///
// Time-stamp: <2026-01-07 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program.  If not, see <https://opensource.org/license/gpl-3-0>.
///
/// Authors: Graham Williams, Miduo

library;

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:solidpod/solidpod.dart';

import 'package:geopod/constants/example_places_data.dart';
import 'package:geopod/models/place.dart';
import 'package:geopod/services/geocoding_service.dart';
import 'package:geopod/services/places/encrypted_places_service.dart';
import 'package:geopod/services/places/places_cache_manager.dart';
import 'package:geopod/services/places/places_cache_persistence.dart';
import 'package:geopod/services/places/places_import_export.dart';
import 'package:geopod/services/places/places_pod_file.dart';
import 'package:geopod/services/pod/pod_directory_service.dart';

export 'package:geopod/models/place.dart';
export 'package:geopod/services/places/places_cache_manager.dart';
export 'package:geopod/services/places/places_import_export.dart';

final placesChangeNotifier = ValueNotifier<int>(0);

class PlacesService {
  /// Cached local places (lazily initialized from compiled constants).
  static List<Place>? _cachedLocalPlaces;

  /// Get local example places synchronously.
  static List<Place> getLocalPlacesSync() {
    _cachedLocalPlaces ??= kExamplePlacesData
        .map((json) => Place.fromJson(json, isLocalSource: true))
        .toList();
    return _cachedLocalPlaces!;
  }

  /// Load local example places (async wrapper for API compatibility).
  /// NOTE: Prefer using getLocalPlacesSync() directly as local places
  /// are now compiled into the app and don't require async loading.
  @Deprecated('Use getLocalPlacesSync() instead - local data is compiled in')
  static Future<List<Place>> loadLocalPlaces() async => getLocalPlacesSync();

  static Future<List<Place>> fetchPlaces({
    bool forceRefresh = false,
    bool includeEncrypted = false,
  }) async {
    final cm = PlacesCacheManager();
    if (!forceRefresh) {
      final c = cm.allPlaces;
      if (c != null) {
        // If cached but need encrypted, check if encrypted is included
        if (includeEncrypted && !c.any((p) => p.isEncrypted)) {
          // Need to fetch encrypted separately
        } else {
          return c;
        }
      }
    }
    // Local places are synchronous (compiled into binary) - get them immediately
    final localPlaces = getLocalPlacesSync();

    // Fetch network data in parallel for better performance
    final results = await Future.wait([
      fetchPodPlaces(forceRefresh: forceRefresh),
      includeEncrypted
          ? fetchEncryptedPlaces(forceRefresh: forceRefresh)
          : Future.value(<Place>[]),
    ]);

    final podPlaces = results[0];
    final encryptedPlaces = results[1];

    final all = <Place>[...podPlaces, ...encryptedPlaces, ...localPlaces];
    cm.cacheAllPlaces(all);
    return all;
  }

  /// Fetch encrypted places from Pod.
  /// Returns empty list if not logged in or no security key available.
  /// NOTE: Will not prompt for security key - use EncryptedPlacesService
  /// directly if you need to prompt the user.
  static Future<List<Place>> fetchEncryptedPlaces({
    bool forceRefresh = false,
  }) async {
    try {
      if (!authStateNotifier.value) return [];
      // Check if security key is available - don't try to load if not
      final hasKey = await EncryptedPlacesService.isSecurityKeyAvailable();
      if (!hasKey) {
        debugPrint(
          'PlacesService.fetchEncryptedPlaces: no security key, skipping',
        );
        return [];
      }
      // Import and use EncryptedPlacesService
      final encPlaces = await EncryptedPlacesService.fetchEncryptedPlaces(
        forceRefresh: forceRefresh,
      );
      return encPlaces;
    } catch (e) {
      debugPrint('PlacesService.fetchEncryptedPlaces error: $e');
      return [];
    }
  }

  static Future<List<Place>> fetchPodPlaces({bool forceRefresh = false}) async {
    final places = <Place>[];
    final cm = PlacesCacheManager();
    try {
      if (!authStateNotifier.value) return places;
      if (!forceRefresh) {
        final mc = cm.podPlaces;
        if (mc != null) {
          _refreshPodPlacesInBackground();
          return mc;
        }
      }
      if (!forceRefresh) {
        final c = await PlacesCachePersistence.getCachedPodPlaces();
        if (c != null) {
          cm.cachePodPlaces(c);
          _refreshPodPlacesInBackground();
          return c;
        }
      }
      final content = await readPlacesJsonFile();
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
      await PlacesCachePersistence.cachePodPlaces(content);
      cm.cachePodPlaces(places);
    } catch (_) {}
    return places;
  }

  static void _refreshPodPlacesInBackground() {
    Future(() async {
      try {
        if (!authStateNotifier.value) return;
        final c = await readPlacesJsonFile();
        if (c != null && c.trim().isNotEmpty) {
          await PlacesCachePersistence.cachePodPlaces(c);
        }
      } catch (_) {}
    });
  }

  static Future<void> clearCache() async {
    try {
      PlacesCacheManager().clearCache();
      await PlacesCachePersistence.clearPodPlacesCache();
      EncryptedPlacesService.resetSessionState();
    } catch (_) {}
  }

  static Future<void> clearPodCacheOnly() async {
    try {
      PlacesCacheManager().clearPodCacheOnly();
      await PlacesCachePersistence.clearPodPlacesCache();
    } catch (_) {}
  }

  static Future<List<Place>> refreshPodDataOnly() async {
    final cm = PlacesCacheManager();
    // Local places are synchronous (compiled into binary)
    final local = getLocalPlacesSync();
    await clearPodCacheOnly();
    final pod = await fetchPodPlaces(forceRefresh: true);
    final all = <Place>[...pod, ...local];
    cm.cacheAllPlaces(all);
    return all;
  }

  static Future<bool> addPlace(
    Place place,
    BuildContext context,
    Widget returnWidget,
  ) async {
    try {
      if (!authStateNotifier.value) return false;
      final cm = PlacesCacheManager();
      var existing = cm.podPlaces ?? await fetchPodPlaces();
      final updated = List<Place>.from(existing)..insert(0, place);

      // Write main file first to ensure it succeeds
      final mainSuccess = await writePlacesJsonFile(
        jsonEncode(updated.map((p) => p.toJson()).toList()),
      );

      if (mainSuccess) {
        // Write individual file (don't block on failure)
        final individualSuccess = await writeIndividualPlaceFile(place);
        debugPrint(
          'addPlace: main=$mainSuccess, individual=$individualSuccess',
        );

        await clearCache();
        placesChangeNotifier.value++;
        // Clear directory cache completely to force refresh
        PodDirectoryService.clearCache();
        PodDirectoryService.notifyChange();
      }
      return mainSuccess;
    } catch (e) {
      debugPrint('Error in addPlace: $e');
      return false;
    }
  }

  static Future<bool> deletePlace(
    String placeId,
    BuildContext context,
    Widget returnWidget,
  ) async {
    try {
      if (!authStateNotifier.value) return false;
      final cm = PlacesCacheManager();
      var existing = cm.podPlaces ?? await fetchPodPlaces();
      final updated = List<Place>.from(existing)
        ..removeWhere((p) => p.id == placeId);

      // Delete individual file and update main file in parallel
      final results = await Future.wait([
        writePlacesJsonFile(
          jsonEncode(updated.map((p) => p.toJson()).toList()),
        ),
        deleteIndividualPlaceFile(placeId),
      ]);
      final success = results[0];

      if (success) {
        await clearCache();
        placesChangeNotifier.value++;
        // Invalidate directory cache and notify file browser
        PodDirectoryService.invalidateCache('data/places');
        PodDirectoryService.notifyChange();
      }
      return success;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> exportPlaces(List<Place> places) =>
      PlacesImportExport.exportPlaces(places);
  static Future<ImportResult> importPlaces() =>
      PlacesImportExport.importPlaces();

  static Future<bool> mergeImportedPlaces(
    List<Place> imported,
    BuildContext context,
    Widget returnWidget, {
    void Function(int, int)? onProgress,
  }) async {
    try {
      if (!authStateNotifier.value) return false;
      final existing = await fetchPodPlaces();
      final ids = existing.map((p) => p.id).toSet();
      final newPlaces = imported.where((p) => !ids.contains(p.id)).toList();
      if (newPlaces.isEmpty && imported.isNotEmpty) return true;
      final withAddr = <Place>[];
      for (int i = 0; i < newPlaces.length; i++) {
        final p = newPlaces[i];
        onProgress?.call(i + 1, newPlaces.length);
        final addr = await GeocodingService.getAddress(p.lat, p.lng);
        withAddr.add(
          Place(
            id: p.id,
            lat: p.lat,
            lng: p.lng,
            note: p.note,
            timestamp: p.timestamp,
            address: addr,
            isLocal: false,
          ),
        );
      }
      final merged = [...withAddr, ...existing];

      // Write main file first
      final success = await writePlacesJsonFile(
        jsonEncode(merged.map((p) => p.toJson()).toList()),
      );

      if (success) {
        // Write individual files for new places in parallel
        await Future.wait(withAddr.map((p) => writeIndividualPlaceFile(p)));
        await clearCache();
        placesChangeNotifier.value++;
        // Invalidate directory cache and notify file browser
        PodDirectoryService.invalidateCache('data/places');
        PodDirectoryService.notifyChange();
      }
      return success;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> clearAllPlaces(
    BuildContext context,
    Widget returnWidget,
  ) async {
    try {
      if (!authStateNotifier.value) return false;

      // Get all existing place IDs before clearing
      final existing = await fetchPodPlaces();
      final placeIds = existing.map((p) => p.id).toList();

      final success = await writePlacesJsonFile('[]');
      if (success) {
        // Delete all individual place files
        await deleteAllIndividualPlaceFiles(placeIds);
        await clearCache();
        placesChangeNotifier.value++;
        // Invalidate directory cache and notify file browser
        PodDirectoryService.invalidateCache('data/places');
        PodDirectoryService.notifyChange();
      }
      return success;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> updatePlace(
    Place updated,
    BuildContext context,
    Widget returnWidget, {
    bool coordinatesChanged = false,
  }) async {
    try {
      if (!authStateNotifier.value) return false;
      final existing = await fetchPodPlaces();
      final list = List<Place>.from(existing);
      final i = list.indexWhere((p) => p.id == updated.id);
      var toSave = updated;

      if (i == -1) {
        list.insert(0, updated);
      } else {
        if (coordinatesChanged) {
          final addr = await GeocodingService.getAddress(
            updated.lat,
            updated.lng,
          );
          toSave = Place(
            id: updated.id,
            lat: updated.lat,
            lng: updated.lng,
            note: updated.note,
            timestamp: updated.timestamp,
            address: addr,
            isLocal: false,
          );
        }
        list[i] = toSave;
      }

      // Update both main file and individual file in parallel
      final results = await Future.wait([
        writePlacesJsonFile(jsonEncode(list.map((p) => p.toJson()).toList())),
        writeIndividualPlaceFile(toSave),
      ]);
      final success = results[0];

      if (success) {
        await clearCache();
        placesChangeNotifier.value++;
        // Invalidate directory cache and notify file browser
        PodDirectoryService.invalidateCache('data/places');
        PodDirectoryService.notifyChange();
      }
      return success;
    } catch (_) {
      return false;
    }
  }

  /// Delete a place by its individual file path.
  /// This is called when a user deletes place_xxx.json from the file browser.
  /// It will also remove the place from the main places.json file.
  static Future<bool> deletePlaceByFilePath(
    String filePath,
    BuildContext context,
    Widget returnWidget,
  ) async {
    // Extract place ID from file path like "place_abc123.json"
    final fileName = filePath.split('/').last;
    final match = RegExp(r'^place_(.+)\.json$').firstMatch(fileName);
    if (match == null) return false;

    final placeId = match.group(1)!;
    return deletePlace(placeId, context, returnWidget);
  }

  /// Check if a file path is a places.json file.
  static bool isMainPlacesFile(String filePath) {
    return filePath.endsWith('/places.json') ||
        filePath.endsWith('\\places.json');
  }

  /// Check if a file path is an individual place file.
  static bool isIndividualPlaceFile(String filePath) {
    final fileName = filePath.split('/').last.split('\\').last;
    return RegExp(r'^place_.+\.json$').hasMatch(fileName);
  }
}
