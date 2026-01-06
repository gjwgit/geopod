/// Service for managing encrypted places data in the user's Solid Pod.
///
/// Encrypted places are stored in the 'encryption data' directory
/// using the solidpod encryption mechanisms.
///
// Time-stamp: <2026-01-06>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

// ignore_for_file: use_build_context_synchronously

library;

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:solidpod/solidpod.dart';
import 'package:solidui/solidui.dart' show getKeyFromUserIfRequired;

import 'package:geopod/models/place.dart';

/// Directory name for encrypted places data.
/// Using underscore instead of space to avoid URL encoding issues.
const String encryptedPlacesDirName = 'encrypted_data';

/// File name for encrypted places.
const String encryptedPlacesFileName = 'encrypted_places.json';

/// Service for managing encrypted places.
class EncryptedPlacesService {
  EncryptedPlacesService._();

  /// Cache for encrypted places.
  static List<Place>? _cachedEncryptedPlaces;

  /// Flag to track if directory has been verified this session.
  static bool _directoryVerified = false;

  /// Get the directory path for encrypted places (relative to data dir).
  /// This is used with PathType.relativeToData, so just the subdirectory name.
  static String getEncryptedPlacesDirPath() {
    return encryptedPlacesDirName;
  }

  /// Get the file path for encrypted places (relative to data dir).
  /// This is used with PathType.relativeToData.
  static String getEncryptedPlacesFilePath() {
    return '$encryptedPlacesDirName/$encryptedPlacesFileName';
  }

  /// Get the full file path for encrypted places (relative to POD root).
  /// This is used with functions like getFileUrl that expect full path.
  static Future<String> getFullEncryptedPlacesFilePath() async {
    final dataPath = await getDataDirPath();
    return '$dataPath/$encryptedPlacesDirName/$encryptedPlacesFileName';
  }

  /// Get the full directory path for encrypted places (relative to POD root).
  static Future<String> getFullEncryptedPlacesDirPath() async {
    final dataPath = await getDataDirPath();
    return '$dataPath/$encryptedPlacesDirName';
  }

  /// Reset session state (call on logout).
  static void resetSessionState() {
    _cachedEncryptedPlaces = null;
    _directoryVerified = false;
    _securityKeyVerified = false;
  }

  /// Flag to track if security key has been verified this session.
  static bool _securityKeyVerified = false;

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
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 8),
              Text('Encryption Not Set Up'),
            ],
          ),
          content: const Text(
            'Encryption has not been set up for your Pod. '
            'Please set up encryption first through the initial setup process.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return false;
    }

    // Prompt for security key
    try {
      await getKeyFromUserIfRequired(context, child);
      final available = await isSecurityKeyAvailable();
      if (available) {
        _securityKeyVerified = true;
      }
      return available;
    } catch (_) {
      return false;
    }
  }

  /// Ensure the encrypted places directory exists.
  /// Uses session caching to avoid repeated server checks.
  static Future<bool> ensureEncryptedPlacesDir() async {
    // Skip if already verified this session
    if (_directoryVerified) {
      return true;
    }

    try {
      // Use full path for getDirUrl (it expects path relative to POD root)
      final fullDirPath = await getFullEncryptedPlacesDirPath();
      final dirUrl = await getDirUrl(fullDirPath);

      final status = await checkResourceStatus(dirUrl, isFile: false);
      if (status == ResourceStatus.notExist) {
        // Create the directory with encryption key inheritance
        // setInheritKeyDir uses PathType.relativeToData by default
        final dirPath = getEncryptedPlacesDirPath();
        await setInheritKeyDir(dirPath);
        debugPrint('Created encrypted places directory: $dirPath');
      }
      _directoryVerified = true;
      return true;
    } catch (e) {
      debugPrint('Failed to ensure encrypted places directory: $e');
      return false;
    }
  }

  /// Read encrypted places from Pod.
  static Future<List<Place>> fetchEncryptedPlaces({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedEncryptedPlaces != null) {
      return _cachedEncryptedPlaces!;
    }

    final places = <Place>[];

    try {
      if (!AuthDataManager.isLoggedInSync()) {
        return places;
      }

      // Use full path for getFileUrl (it expects path relative to POD root)
      final fullFilePath = await getFullEncryptedPlacesFilePath();
      final fileUrl = await getFileUrl(fullFilePath);

      // Check if file exists
      final status = await checkResourceStatus(fileUrl);
      if (status != ResourceStatus.exist) {
        return places;
      }

      // Read encrypted content using relative path (readPod uses relativeToData)
      final filePath = getEncryptedPlacesFilePath();
      final content = await readPod(filePath);

      if (content == SolidFunctionCallStatus.notLoggedIn.toString() ||
          content == SolidFunctionCallStatus.fail.toString()) {
        return places;
      }

      // Parse JSON content directly
      try {
        final jsonList = jsonDecode(content);
        if (jsonList is List) {
          for (final item in jsonList) {
            if (item is Map<String, dynamic>) {
              places.add(Place.fromJson(item, isLocalSource: false));
            }
          }
        }
      } catch (_) {
        debugPrint('Failed to parse encrypted places JSON');
      }

      places.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _cachedEncryptedPlaces = places;
    } catch (e) {
      debugPrint('Error fetching encrypted places: $e');
    }

    return places;
  }

  /// Write encrypted places to Pod.
  static Future<bool> writeEncryptedPlaces(
    List<Place> places,
    BuildContext context,
    Widget child,
  ) async {
    try {
      // Ensure security key is available
      if (!await ensureSecurityKey(context, child)) {
        return false;
      }

      // Ensure directory exists
      if (!await ensureEncryptedPlacesDir()) {
        return false;
      }

      // Use relative paths (writePod uses PathType.relativeToData by default)
      final filePath = getEncryptedPlacesFilePath();
      final dirPath = getEncryptedPlacesDirPath();

      // Convert places to JSON
      final jsonList = places.map((p) => p.toJson()).toList();
      final jsonContent = jsonEncode(jsonList);

      // Write encrypted file with key inheritance from directory
      // Note: When using inheritKeyFrom, the encryption is handled by the
      // directory's key, not by a file-specific individual key. So we set
      // encrypted: false to avoid the "encryption status changed" dialog.
      // The file will still be encrypted via the inherited directory key.
      final result = await writePod(
        filePath,
        jsonContent,
        context,
        child,
        encrypted: false,
        inheritKeyFrom: dirPath,
      );

      if (result == SolidFunctionCallStatus.success) {
        _cachedEncryptedPlaces = places;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error writing encrypted places: $e');
      return false;
    }
  }

  /// Add a single encrypted place.
  /// Uses local cache to avoid fetching from server if available.
  static Future<bool> addEncryptedPlace(
    Place place,
    BuildContext context,
    Widget child,
  ) async {
    try {
      // Use cached data if available to avoid network roundtrip
      final existingPlaces = _cachedEncryptedPlaces ?? await fetchEncryptedPlaces();
      final updatedPlaces = [place, ...existingPlaces];
      return await writeEncryptedPlaces(updatedPlaces, context, child);
    } catch (e) {
      debugPrint('Error adding encrypted place: $e');
      return false;
    }
  }

  /// Delete an encrypted place by ID.
  static Future<bool> deleteEncryptedPlace(
    String placeId,
    BuildContext context,
    Widget child,
  ) async {
    try {
      final existingPlaces = await fetchEncryptedPlaces();
      final updatedPlaces =
          existingPlaces.where((p) => p.id != placeId).toList();
      return await writeEncryptedPlaces(updatedPlaces, context, child);
    } catch (e) {
      debugPrint('Error deleting encrypted place: $e');
      return false;
    }
  }

  /// Update an encrypted place.
  static Future<bool> updateEncryptedPlace(
    Place updatedPlace,
    BuildContext context,
    Widget child,
  ) async {
    try {
      final existingPlaces = await fetchEncryptedPlaces();
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
      final newPlaces =
          importedPlaces.where((p) => !existingIds.contains(p.id)).toList();

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
