/// Functions for loading encrypted places.
///
// Time-stamp: <2026-01-07 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';

import 'package:geopod/models/place.dart';
import 'package:geopod/services/map_settings_service.dart';
import 'package:geopod/services/places/encrypted_places_service.dart';
import 'package:geopod/services/places_service.dart' show PlacesService;

/// Result of loading encrypted places.
class EncryptedPlacesResult {
  /// The loaded encrypted places.
  final List<Place> places;

  /// Whether the operation was successful.
  final bool success;

  /// Whether the user cancelled the operation.
  final bool cancelled;

  const EncryptedPlacesResult({
    required this.places,
    required this.success,
    this.cancelled = false,
  });

  /// Creates a cancelled result.
  const EncryptedPlacesResult.cancelled()
    : places = const [],
      success = false,
      cancelled = true;

  /// Creates a failed result.
  const EncryptedPlacesResult.failed()
    : places = const [],
      success = false,
      cancelled = false;
}

/// Loads encrypted places if security key is available.
///
/// Returns [EncryptedPlacesResult] with the loaded places or failure status.
/// If user cancels key entry, returns cancelled result.
Future<EncryptedPlacesResult> loadEncryptedPlaces({
  required BuildContext context,
  required Widget widget,
  required bool isLoggedIn,
}) async {
  if (!isLoggedIn) {
    return const EncryptedPlacesResult.failed();
  }

  // First ensure security key is available (will prompt user if needed)
  final hasKey = await EncryptedPlacesService.ensureSecurityKey(
    context,
    widget,
  );
  if (!hasKey) {
    // User cancelled or key not available
    return const EncryptedPlacesResult.cancelled();
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
    return EncryptedPlacesResult(places: encryptedPlaces, success: true);
  } catch (e) {
    debugPrint('Error loading encrypted places: $e');
    return const EncryptedPlacesResult.failed();
  }
}

/// Handles the result of loading encrypted places and updates state.
///
/// Call this after [loadEncryptedPlaces] to apply the result.
void applyEncryptedPlacesResult({
  required EncryptedPlacesResult result,
  required List<Place> allPlaces,
  required MapSettings mapSettings,
  required void Function(void Function()) setState,
  required void Function(MapSettings) saveSettings,
}) {
  if (result.cancelled) {
    // Revert setting
    final newSettings = mapSettings.copyWith(showEncryptedPlaces: false);
    setState(() {});
    saveSettings(newSettings);
    return;
  }

  if (result.success && result.places.isNotEmpty) {
    setState(() {
      // Remove any existing encrypted places first
      allPlaces.removeWhere((p) => p.isEncrypted);
      // Add newly loaded encrypted places
      allPlaces.addAll(result.places);
      debugPrint(
        'All places now: ${allPlaces.length}, '
        'encrypted count: ${allPlaces.where((p) => p.isEncrypted).length}',
      );
    });
  }
}
