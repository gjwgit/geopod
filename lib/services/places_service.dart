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

import 'package:flutter/material.dart';

import 'package:geopod/models/place.dart';
import 'package:geopod/services/places/places_cache_service.dart';
import 'package:geopod/services/places/places_fetch_service.dart';
import 'package:geopod/services/places/places_import_export.dart';
import 'package:geopod/services/places/places_write_service.dart';

export 'package:geopod/models/place.dart';
export 'package:geopod/services/places/encrypted_places_service.dart'
    show EncryptedPlacesService;
export 'package:geopod/services/places/places_cache_manager.dart';
export 'package:geopod/services/places/places_import_export.dart';
export 'package:geopod/services/places/places_notifier.dart'
    show placesChangeNotifier;

/// Facade that coordinates [PlacesFetchService], [PlacesCacheService], and
/// [PlacesWriteService].
///
/// All public static methods preserve the original API so callers require no
/// changes.  Implementation details live in the sub-services under
/// `lib/services/places/`.

class PlacesService {
  //  Fetch

  /// Get local example places synchronously (compiled into the binary).

  static List<Place> getLocalPlacesSync() =>
      PlacesFetchService.getLocalPlacesSync();

  /// Load local example places.
  /// NOTE: Prefer [getLocalPlacesSync]  local data is compiled into the app.

  @Deprecated('Use getLocalPlacesSync() instead - local data is compiled in')
  static Future<List<Place>> loadLocalPlaces() async =>
      PlacesFetchService.getLocalPlacesSync();

  /// Fetch all places: local, Pod, and optionally encrypted.

  static Future<List<Place>> fetchPlaces({
    bool forceRefresh = false,
    bool includeEncrypted = false,
  }) => PlacesFetchService.fetchPlaces(
    forceRefresh: forceRefresh,
    includeEncrypted: includeEncrypted,
  );

  /// Fetch encrypted places from the Pod without prompting for a security key.

  static Future<List<Place>> fetchEncryptedPlaces({
    bool forceRefresh = false,
  }) => PlacesFetchService.fetchEncryptedPlaces(forceRefresh: forceRefresh);

  /// Fetch places stored in the user's Solid Pod.

  static Future<List<Place>> fetchPodPlaces({bool forceRefresh = false}) =>
      PlacesFetchService.fetchPodPlaces(forceRefresh: forceRefresh);

  //  Cache

  /// Clears all caches (in-memory, persisted, and encrypted session state).

  static Future<void> clearCache() => PlacesCacheService.clearCache();

  /// Clears only the Pod (non-encrypted) portion of the cache.

  static Future<void> clearPodCacheOnly() =>
      PlacesCacheService.clearPodCacheOnly();

  /// Forces a fresh Pod fetch and returns merged Pod + local places.

  static Future<List<Place>> refreshPodDataOnly() =>
      PlacesCacheService.refreshPodDataOnly();

  //  Write / Mutate

  /// Adds [place] to the user's Pod and updates all caches.

  static Future<bool> addPlace(
    Place place,
    BuildContext context,
    Widget returnWidget,
  ) => PlacesWriteService.addPlace(place, context, returnWidget);

  /// Deletes the place identified by [placeId] from the user's Pod.

  static Future<bool> deletePlace(
    String placeId,
    BuildContext context,
    Widget returnWidget,
  ) => PlacesWriteService.deletePlace(placeId, context, returnWidget);

  /// Deletes a place, routing to encrypted or regular storage automatically.

  static Future<bool> deletePlaceByPlace(
    Place place,
    BuildContext context,
    Widget returnWidget,
  ) => PlacesWriteService.deletePlaceByPlace(place, context, returnWidget);

  /// Deletes a place by its individual file path (e.g. from the file browser).

  static Future<bool> deletePlaceByFilePath(
    String filePath,
    BuildContext context,
    Widget returnWidget,
  ) =>
      PlacesWriteService.deletePlaceByFilePath(filePath, context, returnWidget);

  /// Updates [updated] in the Pod, optionally re-geocoding its address.

  static Future<bool> updatePlace(
    Place updated,
    BuildContext context,
    Widget returnWidget, {
    bool coordinatesChanged = false,
  }) => PlacesWriteService.updatePlace(
    updated,
    context,
    returnWidget,
    coordinatesChanged: coordinatesChanged,
  );

  /// Removes all places from the user's Pod (regular and encrypted).

  static Future<bool> clearAllPlaces(
    BuildContext context,
    Widget returnWidget,
  ) => PlacesWriteService.clearAllPlaces(context, returnWidget);

  //  Import / Export

  /// Exports [places] to a local file.

  static Future<bool> exportPlaces(List<Place> places) =>
      PlacesWriteService.exportPlaces(places);

  /// Opens a file picker and imports places from the selected file.

  static Future<ImportResult> importPlaces() =>
      PlacesWriteService.importPlaces();

  /// Merges [imported] places into the user's Pod, skipping duplicates.

  static Future<bool> mergeImportedPlaces(
    List<Place> imported,
    BuildContext context,
    Widget returnWidget, {
    void Function(int, int)? onProgress,
  }) => PlacesWriteService.mergeImportedPlaces(
    imported,
    context,
    returnWidget,
    onProgress: onProgress,
  );

  //  Utilities

  /// Returns `true` if [filePath] points to the main `places.json` file.

  static bool isMainPlacesFile(String filePath) {
    return filePath.endsWith('/places.json') ||
        filePath.endsWith('\\places.json');
  }

  /// Returns `true` if [filePath] points to an individual place file
  /// (`place_<id>.json`).

  static bool isIndividualPlaceFile(String filePath) {
    final fileName = filePath.split('/').last.split('\\').last;
    return RegExp(r'^place_.+\.json$').hasMatch(fileName);
  }
}
