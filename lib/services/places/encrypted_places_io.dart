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
import 'package:geopod/services/pod/pod_file_system.dart';

/// Ensure the encrypted places directory's ACL and encryption key are set up.
/// Uses persistent caching flag to avoid repeated server calls.
/// Returns (success, dirCreated) tuple.
/// - success: true if directory is ready for encrypted writes
/// - dirCreated: always false (directory is created at Pod initialisation)
///
/// Since geopod/data/encrypted_data/ is created during Pod initialisation,
/// this function only needs to ensure the ACL file and individual encryption
/// key are present (first call per installation only). Subsequent calls are
/// skipped via the directoryVerified flag.
Future<(bool success, bool dirCreated)> ensureEncryptedPlacesDir(
  bool directoryVerified,
) async {
  // Skip all setup if already verified (from persistent storage or session).
  if (directoryVerified) {
    return (true, false);
  }

  try {
    // Directory always exists (created at Pod initialisation via initPod).
    // Call setInheritKeyDir to ensure the ACL file and individual encryption
    // key exist for the directory — each is only created if still absent.
    final fullDirPath = await getFullEncryptedPlacesDirPath();
    final dirUrl = await getDirUrl(fullDirPath);
    await setInheritKeyDir(dirUrl, createAcl: true);
    return (true, false);
  } catch (e) {
    debugPrint('Failed to set up encrypted places directory: $e');
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

    // Handle non-existent file or errors gracefully
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
Future<(bool success, bool dirCreated)> writeEncryptedPlacesToPod(
  List<Place> places,
  bool directoryVerified,
) async {
  try {
    // Ensure directory exists
    final (dirExists, dirCreated) = await ensureEncryptedPlacesDir(
      directoryVerified,
    );
    if (!dirExists) {
      return (false, false);
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

    await writePod(
      filePath,
      jsonContent,
      encrypted: false,
      overwrite: true,
      inheritKeyFrom: dirPath,
    );

    // writePod returns void in 0.9.x, assume success if no exception
    return (true, dirCreated);
  } catch (e) {
    debugPrint('Error writing encrypted places: $e');
    return (false, false);
  }
}

// ── Individual encrypted place file helpers ──────────────────────────────────

/// Write an individual encrypted place file.
///
/// Uses the directory's inherited encryption key (same as the aggregate).
/// File path (relative to data dir): `encrypted_data/enc_place_<id>.ttl`
///
/// Returns `true` on success.

Future<bool> writeIndividualEncryptedPlaceFile(Place place) async {
  try {
    final filePath = getEncryptedIndividualPlaceFilePath(place.id);
    final dirPath = getEncryptedPlacesDirPath();
    final jsonContent = jsonEncode(place.toJson());

    await writePod(
      filePath,
      jsonContent,
      encrypted: false,
      overwrite: true,
      inheritKeyFrom: dirPath,
    );
    return true;
  } catch (e) {
    debugPrint(
      'Error writing individual encrypted place file (${place.id}): $e',
    );
    return false;
  }
}

/// Delete an individual encrypted place file from Pod.
///
/// Returns `true` if the file was deleted or did not exist (404).

Future<bool> deleteIndividualEncryptedPlaceFile(String placeId) async {
  try {
    final relPath = getDataRelativeEncryptedIndividualPlaceFilePath(placeId);
    return await PodFileSystem.deleteFile(relPath);
  } catch (e) {
    debugPrint('Error deleting individual encrypted place file ($placeId): $e');
    return false;
  }
}

/// Delete all individual encrypted place files for the given IDs.
///
/// All deletions run in parallel (fire-and-forget per file).

Future<void> deleteAllIndividualEncryptedPlaceFiles(List<String> ids) async {
  if (ids.isEmpty) return;
  await Future.wait(ids.map((id) => deleteIndividualEncryptedPlaceFile(id)));
}
