/// Service for managing encrypted places data in the user's Solid Pod.
///
/// Encrypted places are stored in the 'encryption data' directory
/// using the solidpod encryption mechanisms.
///
// Time-stamp: <2026-01-14>
///
/// Copyright (C) 2025-2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

// ignore_for_file: use_build_context_synchronously

library;

import 'package:flutter/material.dart';

import 'package:solidpod/solidpod.dart';
import 'package:solidui/solidui.dart' show SecurityKeyStatusChangedNotification;

import 'package:geopod/models/place.dart';
import 'package:geopod/services/places/encrypted_places_io.dart';
import 'package:geopod/widgets/encryption/security_key_dialog.dart';

/// Service for managing encrypted places.
class EncryptedPlacesService {
  EncryptedPlacesService._();

  /// Cache for encrypted places.
  static List<Place>? _cachedEncryptedPlaces;

  /// Flag to track if directory has been verified this session.
  static bool _directoryVerified = false;

  /// Flag to track if security key has been verified this session.
  static bool _securityKeyVerified = false;

  /// Reset session state (call on logout).
  static void resetSessionState() {
    _cachedEncryptedPlaces = null;
    _directoryVerified = false;
    _securityKeyVerified = false;
  }

  /// Check if security key is available for encryption operations.
  static Future<bool> isSecurityKeyAvailable() async {
    try {
      return await KeyManager.hasSecurityKey();
    } catch (_) {
      return false;
    }
  }

  /// Check if verification key exists (meaning encryption was set up).
  static Future<bool> hasEncryptionSetup() async {
    try {
      final verificationKey = await KeyManager.getVerificationKey();
      return verificationKey.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Prompt user for security key if not available.
  /// Returns true if key is now available, false otherwise.
  /// Uses session caching to avoid repeated checks.
  /// Uses dialog mode instead of full-screen to avoid navigation issues on cancel.
  static Future<bool> ensureSecurityKey(
    BuildContext context,
    Widget child,
  ) async {
    // Skip if already verified this session
    if (_securityKeyVerified) {
      return true;
    }

    if (await isSecurityKeyAvailable()) {
      _securityKeyVerified = true;
      return true;
    }

    // Check if encryption has been set up
    if (!await hasEncryptionSetup()) {
      if (!context.mounted) return false;
      await showEncryptionNotSetupDialog(context);
      return false;
    }

    // Prompt for security key using dialog mode (not full-screen)
    // This avoids navigation issues when user cancels
    if (!context.mounted) return false;
    final result = await showSecurityKeyDialog(context);
    if (result) {
      _securityKeyVerified = true;
      // Notify the status bar that security key is now available
      if (context.mounted) {
        const SecurityKeyStatusChangedNotification(
          isKeySaved: true,
        ).dispatch(context);
        debugPrint('Security key status notification dispatched');
      }
    }
    return result;
  }

  /// Read encrypted places from Pod.
  static Future<List<Place>> fetchEncryptedPlaces({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedEncryptedPlaces != null) {
      return _cachedEncryptedPlaces!;
    }

    final places = await fetchEncryptedPlacesFromPod();
    _cachedEncryptedPlaces = places;
    return places;
  }

  /// Write encrypted places to Pod.
  static Future<bool> writeEncryptedPlaces(
    List<Place> places,
    BuildContext context,
    Widget child,
  ) async {
    // Ensure security key is available
    if (!await ensureSecurityKey(context, child)) {
      return false;
    }

    // Write to Pod using IO helper
    final success = await writeEncryptedPlacesToPod(places, _directoryVerified);
    if (success) {
      // Update directory verification flag if write succeeded
      _directoryVerified = true;
      _cachedEncryptedPlaces = places;
    }
    return success;
  }

  /// Add a single encrypted place.
  /// Uses local cache to avoid fetching from server if available.
  /// IMPORTANT: If cache is empty, ensures security key is available before
  /// fetching existing places to prevent data loss.
  static Future<bool> addEncryptedPlace(
    Place place,
    BuildContext context,
    Widget child,
  ) async {
    try {
      // If no cached data, we MUST ensure security key is available first
      // before fetching existing places. Otherwise, fetchEncryptedPlaces()
      // might return empty list and we'd overwrite existing data.
      if (_cachedEncryptedPlaces == null) {
        if (!await ensureSecurityKey(context, child)) {
          debugPrint(
            'Security key not available, cannot safely add encrypted place',
          );
          return false;
        }
      }

      // Now safe to get existing places (either from cache or fetch with key)
      final existingPlaces =
          _cachedEncryptedPlaces ?? await fetchEncryptedPlaces();
      final updatedPlaces = [place, ...existingPlaces];
      return await writeEncryptedPlaces(updatedPlaces, context, child);
    } catch (e) {
      debugPrint('Error adding encrypted place: $e');
      return false;
    }
  }

  /// Delete an encrypted place by ID.
  /// Ensures security key is available before modifying encrypted data.
  static Future<bool> deleteEncryptedPlace(
    String placeId,
    BuildContext context,
    Widget child,
  ) async {
    try {
      // Ensure security key is available before fetching/modifying data
      if (_cachedEncryptedPlaces == null) {
        if (!await ensureSecurityKey(context, child)) {
          debugPrint(
            'Security key not available, cannot safely delete encrypted place',
          );
          return false;
        }
      }

      final existingPlaces =
          _cachedEncryptedPlaces ?? await fetchEncryptedPlaces();
      final updatedPlaces = existingPlaces
          .where((p) => p.id != placeId)
          .toList();
      return await writeEncryptedPlaces(updatedPlaces, context, child);
    } catch (e) {
      debugPrint('Error deleting encrypted place: $e');
      return false;
    }
  }

  /// Update an encrypted place.
  /// Ensures security key is available before modifying encrypted data.
  static Future<bool> updateEncryptedPlace(
    Place updatedPlace,
    BuildContext context,
    Widget child,
  ) async {
    try {
      // Ensure security key is available before fetching/modifying data
      if (_cachedEncryptedPlaces == null) {
        if (!await ensureSecurityKey(context, child)) {
          debugPrint(
            'Security key not available, cannot safely update encrypted place',
          );
          return false;
        }
      }

      final existingPlaces =
          _cachedEncryptedPlaces ?? await fetchEncryptedPlaces();
      final updatedPlaces = existingPlaces.map((p) {
        return p.id == updatedPlace.id ? updatedPlace : p;
      }).toList();
      return await writeEncryptedPlaces(updatedPlaces, context, child);
    } catch (e) {
      debugPrint('Error updating encrypted place: $e');
      return false;
    }
  }

  /// Clear the cache.
  static void clearCache() {
    _cachedEncryptedPlaces = null;
  }

  /// Merge imported places into encrypted storage.
  static Future<bool> mergeImportedEncryptedPlaces(
    List<Place> importedPlaces,
    BuildContext context,
    Widget child, {
    void Function(int current, int total)? onProgress,
  }) async {
    try {
      // Ensure security key
      if (!await ensureSecurityKey(context, child)) {
        return false;
      }

      final existingPlaces = await fetchEncryptedPlaces();
      final existingIds = existingPlaces.map((p) => p.id).toSet();

      // Filter out duplicates
      final newPlaces = importedPlaces
          .where((p) => !existingIds.contains(p.id))
          .toList();

      if (newPlaces.isEmpty && importedPlaces.isNotEmpty) {
        // All were duplicates
        return true;
      }

      // Report progress
      for (int i = 0; i < newPlaces.length; i++) {
        onProgress?.call(i + 1, newPlaces.length);
      }

      // Merge and write
      final allPlaces = [...newPlaces, ...existingPlaces];
      return await writeEncryptedPlaces(allPlaces, context, child);
    } catch (e) {
      debugPrint('Error merging imported encrypted places: $e');
      return false;
    }
  }
}
