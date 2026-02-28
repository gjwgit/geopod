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

// ignore_for_file: use_build_context_synchronously

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
export 'package:geopod/services/places/encrypted_places_service.dart'
    show EncryptedPlacesService;
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
        // If cached but need encrypted and none present, try fast-merge from
        // EncryptedPlacesService in-memory cache before any network call.
        if (includeEncrypted && !c.any((p) => p.isEncrypted)) {
          final cachedEnc = EncryptedPlacesService.getCachedEncryptedPlaces();
          if (cachedEnc != null && cachedEnc.isNotEmpty) {
            final merged = [...c, ...cachedEnc];
            cm.cacheAllPlaces(merged);
            return merged;
          }
          // No encrypted cache — fall through to network fetch.
        } else {
          return c;
        }
      }
    }

    // Local places are synchronous (compiled into binary) - get them immediately.
    final localPlaces = getLocalPlacesSync();

    // Fetch network data in parallel for better performance.
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

      // Fast path: data already in memory — skip the async key check entirely.
      if (!forceRefresh && EncryptedPlacesService.hasLoadedEncryptedPlaces) {
        return EncryptedPlacesService.getCachedEncryptedPlaces()!;
      }

      // Check if security key is available - don't try to load if not.
      final hasKey = await EncryptedPlacesService.isSecurityKeyAvailable();
      if (!hasKey) {
        return [];
      }

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
      // Both are independent — run in parallel.
      await Future.wait([
        PlacesCachePersistence.clearPodPlacesCache(),
        EncryptedPlacesService.resetSessionState(),
      ]);
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

      // Write main file first to ensure it succeeds.
      final mainSuccess = await writePlacesJsonFile(
        jsonEncode(updated.map((p) => p.toJson()).toList()),
      );

      if (mainSuccess) {
        // Fire-and-forget individual file (non-critical — main file is the
        // source of truth and is already written above).
        writeIndividualPlaceFile(place);

        // Surgically insert into caches — avoids a full clear + re-fetch and
        // preserves the encrypted places cache which is unrelated to this write.
        final newJson = jsonEncode(updated.map((p) => p.toJson()).toList());
        cm.insertPlaceIntoCache(place);
        cm.cachePodPlaces(updated);
        // Persist in background — does not block the UI notification.
        PlacesCachePersistence.cachePodPlaces(newJson);
        placesChangeNotifier.value++;

        // Clear directory cache completely to force refresh.

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

      // Delete individual file and update main file in parallel.
      final results = await Future.wait([
        writePlacesJsonFile(
          jsonEncode(updated.map((p) => p.toJson()).toList()),
        ),
        deleteIndividualPlaceFile(placeId),
      ]);
      final success = results[0];

      if (success) {
        // Surgically remove from in-memory caches and refresh pod persistence.
        cm.removePlaceFromCache(placeId);
        await PlacesCachePersistence.cachePodPlaces(
          jsonEncode(updated.map((p) => p.toJson()).toList()),
        );
        cm.cachePodPlaces(updated);
        placesChangeNotifier.value++;

        // Invalidate directory cache and notify file browser.

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

      // Fetch all addresses in parallel instead of sequentially.
      onProgress?.call(0, newPlaces.length);
      final addresses = await Future.wait(
        newPlaces.map((p) => GeocodingService.getAddress(p.lat, p.lng)),
      );
      onProgress?.call(newPlaces.length, newPlaces.length);

      final withAddr = List<Place>.generate(newPlaces.length, (i) {
        final p = newPlaces[i];
        return Place(
          id: p.id,
          lat: p.lat,
          lng: p.lng,
          note: p.note,
          timestamp: p.timestamp,
          address: addresses[i],
          isLocal: false,
        );
      });
      final merged = [...withAddr, ...existing];

      // Write main file first.
      final success = await writePlacesJsonFile(
        jsonEncode(merged.map((p) => p.toJson()).toList()),
      );

      if (success) {
        // Write individual files for new places in parallel.
        await Future.wait(withAddr.map((p) => writeIndividualPlaceFile(p)));
        await clearCache();
        placesChangeNotifier.value++;

        // Invalidate directory cache and notify file browser.

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

      // Get all existing place IDs before clearing.
      final existing = await fetchPodPlaces();
      final placeIds = existing.map((p) => p.id).toList();
      // Snapshot before async write so we know whether to wipe encrypted.
      final hadEncryptedPlaces =
          EncryptedPlacesService.hasLoadedEncryptedPlaces;

      final success = await writePlacesJsonFile('[]');
      if (success) {
        // Delete all individual place files.
        await deleteAllIndividualPlaceFiles(placeIds);

        if (hadEncryptedPlaces) {
          // Clear main/pod cache but keep encrypted session state alive so
          // writeEncryptedPlaces can skip the security key re-check.
          PlacesCacheManager().clearCache();
          await PlacesCachePersistence.clearPodPlacesCache();
          // Erase encrypted places from Pod. writeEncryptedPlaces updates
          // the encrypted cache and fires placesChangeNotifier.
          await EncryptedPlacesService.writeEncryptedPlaces(
            [],
            context,
            returnWidget,
          );
        } else {
          await clearCache();
          placesChangeNotifier.value++;
        }

        // Invalidate directory cache and notify file browser.

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

      // Route encrypted places to their dedicated storage.
      if (updated.isEncrypted) {
        var toSave = updated;
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
            isEncrypted: true,
          );
        }
        // Surgically update main cache BEFORE the write so that the
        // placesChangeNotifier fired inside writeEncryptedPlaces hits an
        // already-correct allPlaces cache — no revert, no extra network fetch.
        PlacesCacheManager().updatePlaceInCache(toSave);
        return EncryptedPlacesService.updateEncryptedPlace(
          toSave,
          context,
          returnWidget,
        );
      }

      final cm = PlacesCacheManager();
      final existing = cm.podPlaces ?? await fetchPodPlaces();
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

      // Update both main file and individual file in parallel.
      final newJson = jsonEncode(list.map((p) => p.toJson()).toList());
      final results = await Future.wait([
        writePlacesJsonFile(newJson),
        writeIndividualPlaceFile(toSave),
      ]);
      final success = results[0];

      if (success) {
        // Surgically update in-memory caches — no full reload needed.
        cm.updatePlaceInCache(toSave);
        await PlacesCachePersistence.cachePodPlaces(newJson);
        cm.cachePodPlaces(list);
        placesChangeNotifier.value++;

        // Invalidate directory cache and notify file browser.

        PodDirectoryService.invalidateCache('data/places');
        PodDirectoryService.notifyChange();
      }
      return success;
    } catch (_) {
      return false;
    }
  }

  /// Deletes a place routing to the correct storage based on [place.isEncrypted].

  static Future<bool> deletePlaceByPlace(
    Place place,
    BuildContext context,
    Widget returnWidget,
  ) async {
    if (place.isEncrypted) {
      final success = await EncryptedPlacesService.deleteEncryptedPlace(
        place.id,
        context,
        returnWidget,
      );
      if (success) placesChangeNotifier.value++;
      return success;
    }
    return deletePlace(place.id, context, returnWidget);
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
