/// POD operations for PlacesServiceV2.
///
/// Handles saving, deleting, and updating places in POD.
///
// Time-stamp: <2026-01-01 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';

import 'package:geopod/services/geocoding_service.dart';
import 'package:geopod/services/places_v2/places_cache_storage.dart';
import 'package:geopod/services/places_v2/places_file_operations.dart';
import 'package:geopod/services/places_v2/places_service_v2.dart';
import 'package:geopod/services/pod/pod.dart';

/// Save a new place to POD (creates individual file).
Future<bool> savePlaceToPod(Place place) async {
  try {
    if (!await PodAuth.isLoggedIn()) return false;

    // Write the place to its own file
    final success = await writePlaceFile(place);

    if (success) {
      debugPrint('PlacesServiceV2: Saved place ${place.id}');

      final cm = PlacesCacheManager();

      // Update pod places cache
      final currentPodPlaces = cm.podPlaces ?? [];
      final newPodPlaces = List<Place>.from(currentPodPlaces);
      newPodPlaces.removeWhere((p) => p.id == place.id);
      newPodPlaces.insert(0, place);
      cm.cachePodPlaces(newPodPlaces);

      // Update all places cache (pod + local)
      final currentAllPlaces = cm.allPlaces;
      if (currentAllPlaces != null) {
        final newAllPlaces = List<Place>.from(currentAllPlaces);
        newAllPlaces.removeWhere((p) => p.id == place.id);
        newAllPlaces.insert(0, place);
        cm.cacheAllPlaces(newAllPlaces);
      }

      await cachePodPlacesToStorage(newPodPlaces);
      placesChangeNotifierV2.value++;
    }

    return success;
  } catch (e) {
    debugPrint('savePlaceToPod() error: $e');
    return false;
  }
}

/// Delete a place from POD (deletes individual file).
Future<bool> deletePlaceFromPod(Place place) async {
  try {
    if (!await PodAuth.isLoggedIn()) return false;

    // Delete the place file
    final success = await deletePlaceFile(place.id);

    if (success) {
      debugPrint('PlacesServiceV2: Deleted place ${place.id}');

      final cm = PlacesCacheManager();

      // Update pod places cache
      final currentPodPlaces = cm.podPlaces ?? [];
      final newPodPlaces = currentPodPlaces
          .where((p) => p.id != place.id)
          .toList();
      cm.cachePodPlaces(newPodPlaces);

      // Update all places cache
      final currentAllPlaces = cm.allPlaces;
      if (currentAllPlaces != null) {
        final newAllPlaces = currentAllPlaces
            .where((p) => p.id != place.id)
            .toList();
        cm.cacheAllPlaces(newAllPlaces);
      }

      await cachePodPlacesToStorage(newPodPlaces);
      placesChangeNotifierV2.value++;
    }

    return success;
  } catch (e) {
    debugPrint('deletePlaceFromPod() error: $e');
    return false;
  }
}

/// Delete a place by ID.
Future<bool> deletePlaceByIdFromPod(String placeId) async {
  try {
    if (!await PodAuth.isLoggedIn()) return false;
    final success = await deletePlaceFile(placeId);
    if (success) {
      debugPrint('PlacesServiceV2: Deleted place $placeId');

      final cm = PlacesCacheManager();

      // Update pod places cache
      final currentPodPlaces = cm.podPlaces ?? [];
      final newPodPlaces = currentPodPlaces
          .where((p) => p.id != placeId)
          .toList();
      cm.cachePodPlaces(newPodPlaces);

      // Update all places cache
      final currentAllPlaces = cm.allPlaces;
      if (currentAllPlaces != null) {
        final newAllPlaces = currentAllPlaces
            .where((p) => p.id != placeId)
            .toList();
        cm.cacheAllPlaces(newAllPlaces);
      }

      await cachePodPlacesToStorage(newPodPlaces);
      placesChangeNotifierV2.value++;
    }
    return success;
  } catch (e) {
    debugPrint('deletePlaceByIdFromPod() error: $e');
    return false;
  }
}

/// Clear all places from POD.
Future<bool> clearAllPlacesFromPod() async {
  try {
    if (!await PodAuth.isLoggedIn()) return false;

    // List and delete all place files (force refresh to get latest)
    final files = await listPlaceFiles(forceRefresh: true);

    // Delete files in parallel for better performance
    await Future.wait(
      files.map((filename) async {
        final placeId = extractPlaceId(filename);
        if (placeId != null) {
          await deletePlaceFile(placeId);
        }
      }),
    );

    await clearAllCaches();
    placesChangeNotifierV2.value++;
    return true;
  } catch (e) {
    debugPrint('clearAllPlacesFromPod() error: $e');
    return false;
  }
}

/// Update an existing place.
Future<bool> updatePlaceInPod(
  Place updated, {
  bool coordinatesChanged = false,
}) async {
  try {
    if (!await PodAuth.isLoggedIn()) return false;

    var toSave = updated;
    if (coordinatesChanged) {
      final addr = await GeocodingService.getAddress(updated.lat, updated.lng);
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

    final success = await writePlaceFile(toSave);
    if (success) {
      // Update cache
      final currentPlaces = PlacesCacheManager().podPlaces ?? [];
      final newPlaces = List<Place>.from(currentPlaces);
      final index = newPlaces.indexWhere((p) => p.id == toSave.id);
      if (index >= 0) {
        newPlaces[index] = toSave;
      } else {
        newPlaces.insert(0, toSave);
      }
      PlacesCacheManager().cachePodPlaces(newPlaces);
      await cachePodPlacesToStorage(newPlaces);
      placesChangeNotifierV2.value++;
    }
    return success;
  } catch (e) {
    debugPrint('updatePlaceInPod() error: $e');
    return false;
  }
}

/// Merge imported places with existing ones.
Future<bool> mergeImportedPlacesToPod(
  List<Place> imported, {
  void Function(int, int)? onProgress,
}) async {
  try {
    if (!await PodAuth.isLoggedIn()) return false;
    final existing = await PlacesServiceV2.fetchPodPlaces(forceRefresh: true);
    final ids = existing.map((p) => p.id).toSet();
    final newPlaces = imported.where((p) => !ids.contains(p.id)).toList();
    if (newPlaces.isEmpty && imported.isNotEmpty) return true;

    // Save each new place as individual file
    for (int i = 0; i < newPlaces.length; i++) {
      final p = newPlaces[i];
      onProgress?.call(i + 1, newPlaces.length);
      final addr = await GeocodingService.getAddress(p.lat, p.lng);
      final placeWithAddr = Place(
        id: p.id,
        lat: p.lat,
        lng: p.lng,
        note: p.note,
        timestamp: p.timestamp,
        address: addr,
        isLocal: false,
      );
      await writePlaceFile(placeWithAddr);
    }

    await clearAllCaches();
    placesChangeNotifierV2.value++;
    return true;
  } catch (e) {
    debugPrint('mergeImportedPlacesToPod() error: $e');
    return false;
  }
}

/// Export places to file.
Future<bool> exportPlacesToFile(List<Place> places) =>
    PlacesImportExport.exportPlaces(places);

/// Import places from file.
Future<ImportResult> importPlacesFromFile() =>
    PlacesImportExport.importPlaces();
