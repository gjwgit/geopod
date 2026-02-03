/// I/O operations for encrypted places data.
///
// Time-stamp: <Thursday 2026-01-22 08:50:55 +1100 Graham Williams>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.
///
/// Authors: Miduo

library;

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:solidpod/solidpod.dart';

import 'package:geopod/models/place.dart';
import 'package:geopod/services/places/encrypted_places_paths.dart';

/// Ensure the encrypted places directory exists.
/// Uses persistent caching flag to avoid repeated server checks.
/// Returns (success, dirCreated) tuple.
/// - success: true if directory exists or was created successfully
/// - dirCreated: true if directory was newly created (false if already existed)
///
/// Optimization: If directoryVerified is true (from persistent storage),
/// skips all network checks - the directory is assumed to exist.
///
/// IMPORTANT: API parameter types in solidpod:
/// - checkResourceStatus() expects a full Pod URL
/// - setInheritKeyDir() expects a full Pod URL
/// - readPod/writePod expect relative paths (e.g., "encrypted_data/places")
///
/// Network calls breakdown (only when directoryVerified=false):
/// 1. checkResourceStatus(dirUrl) - check if directory exists [URL-based]
/// 2. If not exist, setInheritKeyDir(dirUrl) creates it [URL-based], which internally:
///    - Calls checkResourceStatus(dirUrl) again (solidpod internal, redundant)
///    - Checks ACL file status via checkResourceStatus(aclUrl)
///    - Creates directory and ACL resources if needed
/// This is why persistent caching is critical - it saves 3+ URL-based network calls!
///
/// Reliability note: If the directory is deleted on the server side (by manual
/// cleanup or another client), the persistent flag won't detect it until a write
/// operation fails. The app handles this by clearing the flag on write failures,
/// forcing re-verification on the next attempt (see encrypted_places_service.dart).

Future<(bool success, bool dirCreated)> ensureEncryptedPlacesDir(
  bool directoryVerified,
) async {
  // Skip all checks if already verified (from persistent storage or session)
  // This optimization eliminates 3+ network calls per operation!
  if (directoryVerified) {
    return (true, false);
  }

  try {
    // Only check directory if not yet verified
    // This network call happens only once per installation.
    final fullDirPath = await getFullEncryptedPlacesDirPath();
    final dirUrl = await getDirUrl(fullDirPath);

    final status = await checkResourceStatus(dirUrl, isFile: false);
    if (status == ResourceStatus.notExist) {
      // Create the directory with encryption key inheritance
      // WARNING: setInheritKeyDir internally calls checkResourceStatus again
      // (solidpod limitation - can't skip this redundant check)
      await setInheritKeyDir(dirUrl, createAcl: true);
      return (true, true); // Directory was created
    }

    // Directory exists, return success without creation
    return (true, false);
  } catch (e) {
    debugPrint('Failed to ensure encrypted places directory: $e');
    return (false, false);
  }
}

/// Read encrypted places from Pod.
/// Optimized: tries to read directly without checking existence first.

Future<List<Place>> fetchEncryptedPlacesFromPod() async {
  final places = <Place>[];

  try {
    if (!authStateNotifier.value) {
      return places;
    }

    // Read encrypted content directly using relative path
    // If file doesn't exist, readPod will return fail status
    final filePath = getEncryptedPlacesFilePath();
    final content = await readPod(filePath);

    // Handle non-existent file or errors gracefully.

    if (content == SolidFunctionCallStatus.notLoggedIn.toString() ||
        content == SolidFunctionCallStatus.fail.toString() ||
        content.isEmpty) {
      return places;
    }

    // Parse JSON content directly.

    try {
      final jsonList = jsonDecode(content);
      if (jsonList is List) {
        for (final item in jsonList) {
          if (item is Map<String, dynamic>) {
            final place = Place.fromJson(
              item,
              isLocalSource: false,
              isEncryptedSource: true,
            );
            places.add(place);
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to parse encrypted places JSON: $e');
    }

    places.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  } catch (e) {
    debugPrint('Error fetching encrypted places: $e');
  }

  return places;
}

/// Write encrypted places to Pod.
/// Returns (success, dirCreated) tuple.
///
/// Note: This function uses relative paths for writePod() which expects
/// paths relative to the data directory (e.g., "encrypted_data/places.json").
/// The inheritKeyFrom parameter also uses a relative directory path.
/// This differs from ensureEncryptedPlacesDir() which uses full URLs.

Future<(bool success, bool dirCreated)> writeEncryptedPlacesToPod(
  List<Place> places,
  bool directoryVerified,
) async {
  try {
    // Ensure directory exists.
    final (dirExists, dirCreated) = await ensureEncryptedPlacesDir(
      directoryVerified,
    );
    if (!dirExists) {
      return (false, false);
    }

    // Use relative paths (writePod uses PathType.relativeToData by default)

    final filePath = getEncryptedPlacesFilePath();
    final dirPath = getEncryptedPlacesDirPath();

    // Convert places to JSON.

    final jsonList = places.map((p) => p.toJson()).toList();
    final jsonContent = jsonEncode(jsonList);

    // Write encrypted file with key inheritance from directory
    // Note: When using inheritKeyFrom, the encryption is handled by the
    // directory's key, not by a file-specific individual key. So we set
    // encrypted: false to avoid the "encryption status changed" dialog.
    // The file will still be encrypted via the inherited directory key.

    await writePod(
      filePath,
      jsonContent,
      encrypted: false,
      overwrite: true,
      inheritKeyFrom: dirPath,
    );

    // writePod returns void in 0.9.x, assume success if no exception.
    return (true, dirCreated);
  } catch (e) {
    debugPrint('Error writing encrypted places: $e');
    return (false, false);
  }
}
