/// Service for managing encrypted places data in the user's Solid Pod.
///
/// Encrypted places are stored in the 'encryption data' directory
/// using the solidpod encryption mechanisms.
///
// Time-stamp: <2026-02-28 Miduo>
///
/// Copyright (C) 2025-2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

// ignore_for_file: use_build_context_synchronously

library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:solidpod/solidpod.dart';
import 'package:solidui/solidui.dart';

import 'package:geopod/models/place.dart';
import 'package:geopod/services/places/encrypted_places_io.dart';
import 'package:geopod/services/places_service.dart' show placesChangeNotifier;
import 'package:geopod/services/pod/pod_directory_service.dart';
import 'package:geopod/widgets/encryption/security_key_dialog.dart';

/// Service for managing encrypted places.

class EncryptedPlacesService {
  EncryptedPlacesService._();

  /// SharedPreferences key for directory verification flag.

  static const _keyDirVerified = 'encrypted_places_dir_verified';

  /// Cache for encrypted places.

  static List<Place>? _cachedEncryptedPlaces;

  // ── Write-lock: serialises concurrent writes to the aggregate file ─────────
  //
  // Each call to [writeEncryptedPlaces] chains off the previous operation so
  // that concurrent callers never race to overwrite each other's data.
  // (Dart is single-threaded, so the assignment is atomic between await points.)

  static Future<void>? _writeLock;

  /// Runs [fn] after any pending write has completed, then registers itself as
  /// the new pending operation so the next caller waits for it.

  static Future<T> _withWriteLock<T>(Future<T> Function() fn) {
    final previous = _writeLock ?? Future<void>.value();
    final completer = Completer<T>();
    // Register this operation as the new "pending" lock so the next caller
    // chains after it, regardless of success or failure.
    _writeLock = completer.future.then<void>((_) {}).catchError((_) {});
    previous.whenComplete(() async {
      try {
        completer.complete(await fn());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

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

    // Clear persistent directory flag on logout.

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyDirVerified);
      _directoryVerified = false;
    } catch (e) {
      debugPrint('Failed to reset persistent flags: $e');
    }
  }

  /// Check if security key is available for encryption operations.
  /// Only caches positive (true) results to avoid stale 'no key' responses
  /// during async key verification at startup.

  static Future<bool> isSecurityKeyAvailable() async {
    // Only return cached value when it's a confirmed positive.
    if (_securityKeyAvailableCache == true) return true;

    try {
      final available = await KeyManager.hasSecurityKey();
      // Only cache true — false may be temporary (key not yet verified).
      if (available) _securityKeyAvailableCache = true;
      return available;
    } catch (_) {
      // Do not cache errors to allow retry.
      return false;
    }
  }

  /// Clear security key cache (call when key is added/removed).

  static void clearSecurityKeyCache() {
    _securityKeyAvailableCache = null;
  }

  /// Whether encrypted places have been successfully loaded this session.

  static bool get hasLoadedEncryptedPlaces =>
      _cachedEncryptedPlaces != null && _cachedEncryptedPlaces!.isNotEmpty;

  /// Returns the in-memory cache of encrypted places, or null if not yet loaded.

  static List<Place>? getCachedEncryptedPlaces() => _cachedEncryptedPlaces;

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
    // Skip if already verified this session.
    if (_securityKeyVerified) {
      return true;
    }

    if (await isSecurityKeyAvailable()) {
      _securityKeyVerified = true;
      return true;
    }

    // Check if encryption has been set up.

    if (!await hasEncryptionSetup()) {
      if (!context.mounted) return false;
      await showEncryptionNotSetupDialog(context);
      return false;
    }

    // Prompt for security key using dialog mode (not full-screen)
    // This avoids navigation issues when user cancels.

    if (!context.mounted) return false;
    final result = await showSecurityKeyDialog(context);
    if (result) {
      _securityKeyVerified = true;
      _securityKeyAvailableCache = true; // Update cache

      // Directly update the global notifier so the status bar refreshes
      // immediately.  This is more reliable than dispatching a Notification
      // (which only works when context is still in the exact subtree that
      // contains the NotificationListener, which can fail after async gaps).
      securityKeyNotifier.updateStatus(true);

      // Also dispatch the notification for any other listeners that react to it.
      if (context.mounted) {
        const SecurityKeyStatusChangedNotification(
          isKeySaved: true,
        ).dispatch(context);
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
  ) {
    return _withWriteLock(
      () => _doWriteEncryptedPlaces(places, context, child),
    );
  }

  /// Internal (non-locked) implementation of [writeEncryptedPlaces].
  /// Must only be called from within [_withWriteLock].

  static Future<bool> _doWriteEncryptedPlaces(
    List<Place> places,
    BuildContext context,
    Widget child,
  ) async {
    // Ensure security key is available.
    if (!await ensureSecurityKey(context, child)) {
      return false;
    }

    // Snapshot the OLD place list before overwriting the cache so we can
    // compute which individual files need to be deleted.
    final oldPlaces = _cachedEncryptedPlaces ?? <Place>[];

    // Write to Pod using IO helper.
    // The directoryVerified flag (loaded from persistent storage) skips the
    // setInheritKeyDir call once the ACL and encryption key are known to exist.
    final (success, dirCreated) = await writeEncryptedPlacesToPod(
      places,
      _directoryVerified,
    );
    if (success) {
      // Persist the verification flag after first successful write.
      if (!_directoryVerified) {
        await _saveDirVerifiedFlag(true);
      }

      // ── Sync individual encrypted place files ──────────────────────────────
      // Run individual-file sync concurrently with cache update.
      // Deletions and writes are fire-and-forgot independently (Pod is
      // eventually consistent; the aggregate is the source of truth).
      _syncIndividualEncryptedFiles(places, oldPlaces);

      _cachedEncryptedPlaces = places;

      // Notify places change to trigger UI refresh.

      placesChangeNotifier.value++;

      // Notify file browser that encrypted_data directory has changed.
      PodDirectoryService.invalidateCache('data/encrypted_data');
      PodDirectoryService.notifyChange();

      // If directory was newly created, update security key cache and notify UI
      // (directory creation confirms encryption keys are available)

      if (dirCreated) {
        _securityKeyAvailableCache = true; // Keys are now known to be available
        if (context.mounted) {
          const SecurityKeyStatusChangedNotification(
            isKeySaved: true,
          ).dispatch(context);
        }
      }
    } else {
      // Error recovery: If write failed while assuming directory was verified,
      // clear the persisted flag to force re-verification on next attempt.
      // This handles cases where the directory was deleted on the server side
      // (e.g., manual cleanup or by another client) without the app knowing.
      if (_directoryVerified) {
        await _saveDirVerifiedFlag(false);
        debugPrint('Write failed, cleared directory verified flag for retry');
      }
    }
    return success;
  }

  /// Synchronises individual encrypted place files with the new [places] list.
  ///
  /// - Writes (or overwrites) individual files for new/changed places.
  /// - Deletes individual files for places that have been removed.
  ///
  /// This runs fire-and-forget in the background; callers do not need to await.

  static void _syncIndividualEncryptedFiles(
    List<Place> newPlaces,
    List<Place> oldPlaces,
  ) {
    // Build lookup maps.
    final oldById = {for (final p in oldPlaces) p.id: p};
    final newById = {for (final p in newPlaces) p.id: p};

    // Places that were removed → delete their individual files.
    final removedIds = oldById.keys
        .where((id) => !newById.containsKey(id))
        .toList();

    // Places that are new or whose JSON has changed → write individual files.
    final toWrite = newPlaces.where((p) {
      final old = oldById[p.id];
      if (old == null) return true; // New place.
      // Compare serialised JSON to detect changes.
      return jsonEncode(p.toJson()) != jsonEncode(old.toJson());
    }).toList();

    // Fire-and-forget parallel operations.
    if (removedIds.isNotEmpty) {
      deleteAllIndividualEncryptedPlaceFiles(removedIds);
    }
    for (final place in toWrite) {
      writeIndividualEncryptedPlaceFile(place);
    }
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
      // Load persistent flags first.
      if (!_directoryVerified) {
        await _loadPersistentFlags();
      }

      // If no cached data, we MUST ensure security key is available first
      // before fetching existing places. Otherwise, fetchEncryptedPlaces()
      // might return empty list and we'd overwrite existing data.

      if (_cachedEncryptedPlaces == null) {
        if (!await ensureSecurityKey(context, child)) {
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
      // Ensure security key is available before fetching/modifying data.
      if (_cachedEncryptedPlaces == null) {
        if (!await ensureSecurityKey(context, child)) {
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
      // Ensure security key is available before fetching/modifying data.
      if (_cachedEncryptedPlaces == null) {
        if (!await ensureSecurityKey(context, child)) {
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

  /// Delete an encrypted place by its individual file path.
  ///
  /// Called when a user deletes an `enc_place_<id>.ttl` file from the file
  /// browser. Removes the corresponding entry from the aggregate file too.

  static Future<bool> deleteEncryptedPlaceByFilePath(
    String filePath,
    BuildContext context,
    Widget returnWidget,
  ) async {
    final fileName = filePath.split('/').last;
    final match = RegExp(r'^enc_place_(.+)\.ttl$').firstMatch(fileName);
    if (match == null) return false;

    final placeId = match.group(1)!;
    return deleteEncryptedPlace(placeId, context, returnWidget);
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
      // Ensure security key.
      if (!await ensureSecurityKey(context, child)) {
        return false;
      }

      final existingPlaces = await fetchEncryptedPlaces();
      final existingIds = existingPlaces.map((p) => p.id).toSet();

      // Filter out duplicates.
      final newPlaces = importedPlaces
          .where((p) => !existingIds.contains(p.id))
          .toList();

      if (newPlaces.isEmpty && importedPlaces.isNotEmpty) {
        // All were duplicates.
        return true;
      }

      // Report progress.

      for (int i = 0; i < newPlaces.length; i++) {
        onProgress?.call(i + 1, newPlaces.length);
      }

      // Merge and write.
      final allPlaces = [...newPlaces, ...existingPlaces];
      return await writeEncryptedPlaces(allPlaces, context, child);
    } catch (e) {
      debugPrint('Error merging imported encrypted places: $e');
      return false;
    }
  }
}
