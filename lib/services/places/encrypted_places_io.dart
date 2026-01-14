/// I/O operations for encrypted places data.
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

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:solidpod/solidpod.dart';

import 'package:geopod/models/place.dart';
import 'package:geopod/services/places/encrypted_places_paths.dart';

/// Ensure the encrypted places directory exists.
/// Uses session caching flag to avoid repeated server checks.
Future<bool> ensureEncryptedPlacesDir(bool directoryVerified) async {
  // Skip if already verified this session
  if (directoryVerified) {
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
    return true;
  } catch (e) {
    debugPrint('Failed to ensure encrypted places directory: $e');
    return false;
  }
}

/// Read encrypted places from Pod.
Future<List<Place>> fetchEncryptedPlacesFromPod() async {
  final places = <Place>[];

  try {
    if (!authStateNotifier.value) {
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
            final place = Place.fromJson(
              item,
              isLocalSource: false,
              isEncryptedSource: true,
            );
            debugPrint(
              'Loaded encrypted place: ${place.id}, isEncrypted=${place.isEncrypted}',
            );
            places.add(place);
          }
        }
      }
      debugPrint('Total encrypted places loaded: ${places.length}');
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
Future<bool> writeEncryptedPlacesToPod(
  List<Place> places,
  bool directoryVerified,
) async {
  try {
    // Ensure directory exists
    final dirExists = await ensureEncryptedPlacesDir(directoryVerified);
    if (!dirExists) {
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
    await writePod(
      filePath,
      jsonContent,
      encrypted: false,
      inheritKeyFrom: dirPath,
    );

    // writePod returns void in 0.9.x, assume success if no exception
    return true;
  } catch (e) {
    debugPrint('Error writing encrypted places: $e');
    return false;
  }
}
