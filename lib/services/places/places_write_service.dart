/// Service for writing, updating, and deleting places data.
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

import 'package:geopod/models/place.dart';
import 'package:geopod/services/geocoding_service.dart';
import 'package:geopod/services/media/media_pod_service.dart';
import 'package:geopod/services/places/encrypted_places_service.dart';
import 'package:geopod/services/places/places_cache_manager.dart';
import 'package:geopod/services/places/places_cache_persistence.dart';
import 'package:geopod/services/places/places_cache_service.dart';
import 'package:geopod/services/places/places_fetch_service.dart';
import 'package:geopod/services/places/places_import_export.dart';
import 'package:geopod/services/places/places_notifier.dart';
import 'package:geopod/services/places/places_pod_file.dart';
import 'package:geopod/services/pod/pod_directory_service.dart';

/// Handles all mutation operations: add, delete, update, clear, and merge.
///
/// Every successful write increments [placesChangeNotifier] so that
/// dependent widgets can rebuild automatically.

class PlacesWriteService {
  /// Adds [place] to the user's Pod and updates all caches.
  ///
  /// Returns `true` on success.  Requires an active Solid login.

  static Future<bool> addPlace(
    Place place,
    BuildContext context,
    Widget returnWidget,
  ) async {
    try {
      if (!authStateNotifier.value) return false;
      final cm = PlacesCacheManager();
      var existing = cm.podPlaces ?? await PlacesFetchService.fetchPodPlaces();
      final updated = List<Place>.from(existing)..insert(0, place);

      // Write main file first to ensure it succeeds.
      final mainSuccess = await writePlacesJsonFile(
        jsonEncode(updated.map((p) => p.toJson()).toList()),
      );

      if (mainSuccess) {
        // Await individual file write BEFORE notifying the file browser.
        // If we fire-and-forget here, the directory listing refresh triggered
        // by notifyChange() can race with the write and show a stale listing.
        await writeIndividualPlaceFile(place);

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
      debugPrint('PlacesWriteService.addPlace error: $e');
      return false;
    }
  }

  /// Deletes the place identified by [placeId] from the user's Pod.
  ///
  /// Removes the main places.json entry and the individual place file.
  /// Returns `true` on success.

  static Future<bool> deletePlace(
    String placeId,
    BuildContext context,
    Widget returnWidget,
  ) async {
    try {
      if (!authStateNotifier.value) return false;
      final cm = PlacesCacheManager();
      var existing = cm.podPlaces ?? await PlacesFetchService.fetchPodPlaces();
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

        // Fire-and-forget: remove stale place links from all media items.
        MediaPodService.unlinkAllForPlace(placeId);

        // Invalidate directory cache and notify file browser.
        PodDirectoryService.invalidateCache('data/places');
        PodDirectoryService.notifyChange();
      }
      return success;
    } catch (_) {
      return false;
    }
  }

  /// Deletes a place routing to the correct storage based on
  /// [place.isEncrypted].

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
      if (success) {
        placesChangeNotifier.value++;
        // Fire-and-forget: remove stale place links from all media items.
        MediaPodService.unlinkAllForPlace(place.id);
      }
      return success;
    }
    return deletePlace(place.id, context, returnWidget);
  }

  /// Deletes a place by its individual file path.
  ///
  /// This is called when a user deletes `place_xxx.json` from the file
  /// browser.  It also removes the entry from the main `places.json` file.

  static Future<bool> deletePlaceByFilePath(
    String filePath,
    BuildContext context,
    Widget returnWidget,
  ) async {
    // Extract place ID from file path like "place_abc123.json".
    final fileName = filePath.split('/').last;
    final match = RegExp(r'^place_(.+)\.json$').firstMatch(fileName);
    if (match == null) return false;

    final placeId = match.group(1)!;
    return deletePlace(placeId, context, returnWidget);
  }

  /// Updates [updated] in the Pod, re-geocoding if [coordinatesChanged].
  ///
  /// Encrypted places are routed to [EncryptedPlacesService].
  /// Returns `true` on success.

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
      final existing =
          cm.podPlaces ?? await PlacesFetchService.fetchPodPlaces();
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
      // createAcl: false — ACL already exists from the initial addPlace write.
      final newJson = jsonEncode(list.map((p) => p.toJson()).toList());
      final results = await Future.wait([
        writePlacesJsonFile(newJson),
        writeIndividualPlaceFile(toSave, createAcl: false),
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

  /// Removes all places from the user's Pod (both regular and encrypted).
  ///
  /// Returns `true` on success.

  static Future<bool> clearAllPlaces(
    BuildContext context,
    Widget returnWidget,
  ) async {
    try {
      if (!authStateNotifier.value) return false;

      // Get all existing place IDs before clearing.
      final existing = await PlacesFetchService.fetchPodPlaces();
      final placeIds = existing.map((p) => p.id).toList();
      // Snapshot before async write so we know whether to wipe encrypted.
      final hadEncryptedPlaces =
          EncryptedPlacesService.hasLoadedEncryptedPlaces;

      final success = await writePlacesJsonFile('[]');
      if (success) {
        // Delete all individual place files.
        await deleteAllIndividualPlaceFiles(placeIds);

        // Fire-and-forget: clear all media-place links since no places remain.
        MediaPodService.clearAllPlaceLinks();

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
          await PlacesCacheService.clearCache();
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

  /// Merges [imported] places into the user's Pod, skipping any that already
  /// exist (matched by ID).
  ///
  /// Fetches addresses for new places in parallel.
  /// [onProgress] is called with (done, total) during geocoding.
  /// Returns `true` on success.

  static Future<bool> mergeImportedPlaces(
    List<Place> imported,
    BuildContext context,
    Widget returnWidget, {
    void Function(int, int)? onProgress,
  }) async {
    try {
      if (!authStateNotifier.value) return false;
      final existing = await PlacesFetchService.fetchPodPlaces();
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
        await PlacesCacheService.clearCache();
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

  /// Convenience re-export: delegates to [PlacesImportExport.exportPlaces].

  static Future<bool> exportPlaces(List<Place> places) =>
      PlacesImportExport.exportPlaces(places);

  /// Convenience re-export: delegates to [PlacesImportExport.importPlaces].

  static Future<ImportResult> importPlaces() =>
      PlacesImportExport.importPlaces();
}
