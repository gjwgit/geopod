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

import 'package:shared_preferences/shared_preferences.dart';
import 'package:solidpod/solidpod.dart';
import 'package:solidui/solidui.dart' show SecurityKeyStatusChangedNotification;

import 'package:geopod/models/place.dart';
import 'package:geopod/services/places/encrypted_places_io.dart';
import 'package:geopod/services/places_service.dart' show placesChangeNotifier;
import 'package:geopod/widgets/encryption/security_key_dialog.dart';

/// Service for managing encrypted places.
class EncryptedPlacesService {
  EncryptedPlacesService._();

  /// SharedPreferences key for directory verification flag.
  static const _keyDirVerified = 'encrypted_places_dir_verified';

  /// Cache for encrypted places.
  static List<Place>? _cachedEncryptedPlaces;

  /// Flag to track if directory has been verified.
  static bool _directoryVerified = false;

  /// Flag to track if security key has been verified this session.
  static bool _securityKeyVerified = false;

  /// Cached security key availability status.
  static bool? _securityKeyAvailableCache;

  /// Load persistent flags from storage.
  static Future<void> _loadPersistentFlags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _directoryVerified = prefs.getBool(_keyDirVerified) ?? false;
    } catch (e) {
      debugPrint('Failed to load persistent flags: $e');
    }
  }

  /// Save directory verified flag to storage.
  static Future<void> _saveDirVerifiedFlag(bool verified) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyDirVerified, verified);
      _directoryVerified = verified;
    } catch (e) {
      debugPrint('Failed to save dir verified flag: $e');
    }
  }

  /// Initialize service - load persistent flags.
  /// Call this once at app startup for better performance.
  static Future<void> initialize() async {
    await _loadPersistentFlags();
  }

  /// Reset session state (call on logout).
  static Future<void> resetSessionState() async {
    _cachedEncryptedPlaces = null;
    _securityKeyVerified = false;
    _securityKeyAvailableCache = null;
    // Clear persistent directory flag on logout
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyDirVerified);
      _directoryVerified = false;
    } catch (e) {
      debugPrint('Failed to reset persistent flags: $e');
    }
  }

  /// Check if security key is available for encryption operations.
  /// Uses cache to avoid repeated KeyManager calls.
  static Future<bool> isSecurityKeyAvailable() async {
    // Return cached value if available
    if (_securityKeyAvailableCache != null) {
      return _securityKeyAvailableCache!;
    }

    try {
      final available = await KeyManager.hasSecurityKey();
      _securityKeyAvailableCache = available;
      return available;
    } catch (_) {
      _securityKeyAvailableCache = false;
      return false;
    }
  }

  /// Clear security key cache (call when key is added/removed).
  static void clearSecurityKeyCache() {
    _securityKeyAvailableCache = null;
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
      _securityKeyAvailableCache = true; // Update cache
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
  /// Optimized: Uses persistent directoryVerified flag to skip repeated
  /// directory status checks across app sessions.
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
    // The directoryVerified flag (loaded from persistent storage) prevents
    // repeated checkResourceStatus calls for the directory
    final (success, dirCreated) = await writeEncryptedPlacesToPod(
      places,
      _directoryVerified,
    );
    if (success) {
      // Update and persist directory verification flag if write succeeded
      if (!_directoryVerified) {
        await _saveDirVerifiedFlag(true);
      }
      _cachedEncryptedPlaces = places;

      // Notify places change to trigger UI refresh
      placesChangeNotifier.value++;

      // If directory was newly created, update security key cache and notify UI
      // (directory creation confirms encryption keys are available)
      if (dirCreated) {
        _securityKeyAvailableCache = true; // Keys are now known to be available
        if (context.mounted) {
          const SecurityKeyStatusChangedNotification(
            isKeySaved: true,
          ).dispatch(context);
          debugPrint(
            'Directory created, security key status notification dispatched',
          );
        }
      }
    } else {
      // If write failed while assuming directory was verified,
      // clear the persisted flag so next attempt will re-verify and
      // recreate the directory if needed.
      if (_directoryVerified) {
        await _saveDirVerifiedFlag(false);
        debugPrint('Write failed, cleared directory verified flag for retry');
      }
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
    return addEncryptedPlacesBatch([place], context, child);
  }

  /// Add multiple encrypted places in a single batch operation.
  /// More efficient than calling addEncryptedPlace multiple times.
  /// Uses local cache to avoid fetching from server if available.
  static Future<bool> addEncryptedPlacesBatch(
    List<Place> places,
    BuildContext context,
    Widget child,
  ) async {
    if (places.isEmpty) return true;

    try {
      // Load persistent flags first
      if (!_directoryVerified) {
        await _loadPersistentFlags();
      }

      // If no cached data, we MUST ensure security key is available first
      // before fetching existing places. Otherwise, fetchEncryptedPlaces()
      // might return empty list and we'd overwrite existing data.
      if (_cachedEncryptedPlaces == null) {
        if (!await ensureSecurityKey(context, child)) {
          debugPrint(
            'Security key not available, cannot safely add encrypted places',
          );
          return false;
        }
      }

      // Now safe to get existing places (either from cache or fetch with key)
      final existingPlaces =
          _cachedEncryptedPlaces ?? await fetchEncryptedPlaces();
      final updatedPlaces = [...places, ...existingPlaces];
      return await writeEncryptedPlaces(updatedPlaces, context, child);
    } catch (e) {
      debugPrint('Error adding encrypted places batch: $e');
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
