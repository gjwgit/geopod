/// Place loading and encrypted places handling for GeoMap.
///
// Time-stamp: <Tuesday 2026-01-14 +1100>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.
///
/// Authors: Miduo

library;

import 'package:flutter/material.dart';

import 'package:geopod/models/place.dart';
import 'package:geopod/services/places/encrypted_places_service.dart';
import 'package:geopod/services/places_service.dart'
    show PlacesCacheManager, PlacesService;
import 'package:geopod/widgets/map/geomap_state_logic.dart';

/// Result of loading places.
class LoadPlacesResult {
  final List<Place> places;
  final bool showLoading;
  final bool hasChanges;

  LoadPlacesResult({
    required this.places,
    required this.showLoading,
    required this.hasChanges,
  });
}

/// Loads all places (local and pod) with optional encrypted places.
Future<LoadPlacesResult> loadPlacesWithState({
  required List<Place> currentPlaces,
  required bool forceRefresh,
  required bool includeEncrypted,
}) async {
  final cacheManager = PlacesCacheManager();
  final showLoading = cacheManager.allPlaces == null;

  final places = await loadAllPlaces(
    forceRefresh: forceRefresh,
    includeEncrypted: includeEncrypted,
  );

  // Check if data actually changed to avoid unnecessary rebuild
  final hasChanges =
      currentPlaces.length != places.length ||
      !currentPlaces.every((p) => places.any((np) => np.id == p.id));

  return LoadPlacesResult(
    places: places,
    showLoading: showLoading,
    hasChanges: hasChanges || showLoading,
  );
}

/// Result of loading encrypted places.
class LoadEncryptedPlacesResult {
  final List<Place> encryptedPlaces;
  final bool cancelled;
  final String? error;

  LoadEncryptedPlacesResult({
    required this.encryptedPlaces,
    this.cancelled = false,
    this.error,
  });
}

/// Load encrypted places on demand when user enables the setting.
/// If [skipKeyVerification] is true, assumes security key is already verified.
Future<LoadEncryptedPlacesResult> loadEncryptedPlacesData({
  required BuildContext context,
  required Widget widget,
  required bool isLoggedIn,
  required bool skipKeyVerification,
}) async {
  if (!isLoggedIn) {
    return LoadEncryptedPlacesResult(encryptedPlaces: [], cancelled: true);
  }

  if (!skipKeyVerification) {
    // Ensure security key is available (will prompt user if needed)
    final hasKey = await EncryptedPlacesService.ensureSecurityKey(
      context,
      widget,
    );
    if (!hasKey) {
      // User cancelled or key not available
      return LoadEncryptedPlacesResult(encryptedPlaces: [], cancelled: true);
    }
  }

  try {
    debugPrint('Loading encrypted places...');
    final encryptedPlaces = await PlacesService.fetchEncryptedPlaces(
      forceRefresh: true,
    );
    debugPrint(
      'Fetched ${encryptedPlaces.length} encrypted places, '
      'isEncrypted flags: ${encryptedPlaces.map((p) => p.isEncrypted).toList()}',
    );
    return LoadEncryptedPlacesResult(encryptedPlaces: encryptedPlaces);
  } catch (e) {
    debugPrint('Error loading encrypted places: $e');
    return LoadEncryptedPlacesResult(encryptedPlaces: [], error: e.toString());
  }
}

/// Merges encrypted places into all places list.
List<Place> mergeEncryptedPlaces({
  required List<Place> allPlaces,
  required List<Place> encryptedPlaces,
}) {
  // Remove any existing encrypted places first
  final result = allPlaces.where((p) => !p.isEncrypted).toList();
  // Add newly loaded encrypted places
  result.addAll(encryptedPlaces);
  debugPrint(
    'Merged places: total=${result.length}, '
    'encrypted=${result.where((p) => p.isEncrypted).length}',
  );
  return result;
}

/// Removes encrypted places from all places list.
List<Place> removeEncryptedPlaces({required List<Place> allPlaces}) {
  return allPlaces.where((p) => !p.isEncrypted).toList();
}
