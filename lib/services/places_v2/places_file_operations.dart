/// File operations for PlacesServiceV2.
///
/// Handles reading/writing individual place files to POD.
///
// Time-stamp: <2026-01-01 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:geopod/models/place.dart';
import 'package:geopod/services/pod/pod.dart';

/// Places directory path relative to the data directory.
const String placesDir = 'places';

/// Generate filename for a place.
String placeFileName(String placeId) => 'place_$placeId.json';

/// Generate full path for a place file.
String placeFilePath(String placeId) => '$placesDir/${placeFileName(placeId)}';

/// Extract place ID from filename.
String? extractPlaceId(String filename) {
  // place_{id}.json -> {id}
  if (filename.startsWith('place_') && filename.endsWith('.json')) {
    return filename.substring(6, filename.length - 5);
  }
  return null;
}

/// Read a single place from its file.
Future<Place?> readPlaceFile(String placeId) async {
  try {
    final content = await PodFileSystem.readFile(placeFilePath(placeId));
    if (content == null || content.trim().isEmpty) return null;
    final decoded = jsonDecode(content);
    if (decoded is Map<String, dynamic>) {
      return Place.fromJson(decoded, isLocalSource: false);
    }
  } catch (e) {
    debugPrint('readPlaceFile($placeId) error: $e');
  }
  return null;
}

/// Write a single place to its file.
Future<bool> writePlaceFile(Place place) async {
  try {
    final content = jsonEncode(place.toJson());
    final success = await PodFileSystem.writeFile(
      placeFilePath(place.id),
      content,
      contentType: PodContentType.json,
      createParentDirs: true,
    );
    if (success) {
      // Invalidate directory cache so listPlaceFiles() gets fresh data
      PodDirectoryService.invalidateCache(placesDir);
    }
    return success;
  } catch (e) {
    debugPrint('writePlaceFile() error: $e');
    return false;
  }
}

/// Delete a place file.
Future<bool> deletePlaceFile(String placeId) async {
  try {
    final success = await PodFileSystem.deleteFile(placeFilePath(placeId));
    if (success) {
      // Invalidate directory cache so listPlaceFiles() gets fresh data
      PodDirectoryService.invalidateCache(placesDir);
    }
    return success;
  } catch (e) {
    debugPrint('deletePlaceFile() error: $e');
    return false;
  }
}

/// List all place files in the places directory.
Future<List<String>> listPlaceFiles({bool forceRefresh = false}) async {
  try {
    final items = await PodDirectoryService.listDirectory(
      placesDir,
      forceRefresh: forceRefresh,
    );
    // Filter for place_*.json files
    return items
        .where(
          (item) =>
              !item.isDirectory &&
              item.name.startsWith('place_') &&
              item.name.endsWith('.json'),
        )
        .map((item) => item.name)
        .toList();
  } catch (e) {
    debugPrint('listPlaceFiles() error: $e');
    return [];
  }
}
