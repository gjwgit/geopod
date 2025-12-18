/// CRUD operations for places data in the user's Solid Pod.
///
// Time-stamp: <2025-12-04 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:solidpod/solidpod.dart';

import 'package:geopod/models/place.dart';
import 'package:geopod/services/geocoding_service.dart';
import 'package:geopod/services/places/places_cache_manager.dart';

/// Mixin providing CRUD operations for places.
mixin PlacesCrudOperations {
  /// Notifier for places data changes.
  ValueNotifier<int> get changeNotifier;

  /// Fetches Pod places.
  Future<List<Place>> fetchPodPlaces({bool forceRefresh = false});

  /// Writes JSON content to the Pod.
  Future<bool> writeJsonFile(String content);

  /// Clears the cache.
  Future<void> clearCache();

  /// Adds a new place to the Pod.
  Future<bool> addPlace(
    Place place,
    BuildContext context,
    Widget returnWidget,
  ) async {
    try {
      if (!await checkLoggedIn()) return false;
      final cm = PlacesCacheManager();
      var existing = cm.podPlaces;
      existing ??= await fetchPodPlaces();
      final updated = List<Place>.from(existing)..insert(0, place);
      final json = jsonEncode(updated.map((p) => p.toJson()).toList());
      final success = await writeJsonFile(json);
      if (success) {
        await clearCache();
        changeNotifier.value++;
      }
      return success;
    } catch (_) {
      return false;
    }
  }

  /// Deletes a place from the Pod by its ID.
  Future<bool> deletePlace(
    String placeId,
    BuildContext context,
    Widget returnWidget,
  ) async {
    try {
      if (!await checkLoggedIn()) return false;
      final cm = PlacesCacheManager();
      var existing = cm.podPlaces;
      existing ??= await fetchPodPlaces();
      final updated = List<Place>.from(existing)
        ..removeWhere((p) => p.id == placeId);
      final json = jsonEncode(updated.map((p) => p.toJson()).toList());
      final success = await writeJsonFile(json);
      if (success) {
        await clearCache();
        changeNotifier.value++;
      }
      return success;
    } catch (_) {
      return false;
    }
  }

  /// Clears all user's saved places from the Pod.
  Future<bool> clearAllPlaces(BuildContext context, Widget returnWidget) async {
    try {
      if (!await checkLoggedIn()) return false;
      final success = await writeJsonFile('[]');
      if (success) {
        await clearCache();
        changeNotifier.value++;
      }
      return success;
    } catch (_) {
      return false;
    }
  }

  /// Updates an existing place in the Pod.
  Future<bool> updatePlace(
    Place updatedPlace,
    BuildContext context,
    Widget returnWidget, {
    bool coordinatesChanged = false,
  }) async {
    try {
      if (!await checkLoggedIn()) return false;
      final existing = await fetchPodPlaces();
      final updated = List<Place>.from(existing);
      final i = updated.indexWhere((p) => p.id == updatedPlace.id);
      if (i == -1) {
        updated.insert(0, updatedPlace);
      } else {
        Place toSave = updatedPlace;
        if (coordinatesChanged) {
          final addr = await GeocodingService.getAddress(
            updatedPlace.lat,
            updatedPlace.lng,
          );
          toSave = Place(
            id: updatedPlace.id,
            lat: updatedPlace.lat,
            lng: updatedPlace.lng,
            note: updatedPlace.note,
            timestamp: updatedPlace.timestamp,
            address: addr,
            isLocal: false,
          );
        }
        updated[i] = toSave;
      }
      final json = jsonEncode(updated.map((p) => p.toJson()).toList());
      final success = await writeJsonFile(json);
      if (success) {
        await clearCache();
        changeNotifier.value++;
      }
      return success;
    } catch (_) {
      return false;
    }
  }

  /// Merges imported places into existing Pod places.
  Future<bool> mergeImportedPlaces(
    List<Place> imported,
    BuildContext context,
    Widget returnWidget, {
    void Function(int, int)? onProgress,
  }) async {
    try {
      if (!await checkLoggedIn()) return false;
      final existing = await fetchPodPlaces();
      final existingIds = existing.map((p) => p.id).toSet();
      final newPlaces = imported
          .where((p) => !existingIds.contains(p.id))
          .toList();
      if (newPlaces.isEmpty && imported.isNotEmpty) return true;
      final withAddresses = <Place>[];
      for (int i = 0; i < newPlaces.length; i++) {
        final p = newPlaces[i];
        onProgress?.call(i + 1, newPlaces.length);
        final addr = await GeocodingService.getAddress(p.lat, p.lng);
        withAddresses.add(
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
      final merged = [...withAddresses, ...existing];
      final json = jsonEncode(merged.map((p) => p.toJson()).toList());
      final success = await writeJsonFile(json);
      if (success) {
        await clearCache();
        changeNotifier.value++;
      }
      return success;
    } catch (_) {
      return false;
    }
  }
}
