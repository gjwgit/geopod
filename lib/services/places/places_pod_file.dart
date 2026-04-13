/// POD file operations for places service.
///
/// Contains low-level file read/write operations for places data.
///
// Time-stamp: <2026-01-02 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;
import 'package:solidpod/solidpod.dart';

import 'package:geopod/models/place.dart';

const String placesFileName = 'places.json';

/// Get the full file path for places.json.

Future<String> getPlacesFilePath() async {
  final path = await getDataDirPath();
  return '$path/places/$placesFileName';
}

/// Get the directory path for places.

Future<String> getPlacesDirPath() async {
  final path = await getDataDirPath();
  return '$path/places';
}

/// Get file path for individual place file.

Future<String> getIndividualPlaceFilePath(String placeId) async {
  final dirPath = await getPlacesDirPath();
  return '$dirPath/place_$placeId.json';
}

/// Read the main places.json file.

Future<String?> readPlacesJsonFile() async {
  try {
    final fp = await getPlacesFilePath();
    final url = await getFileUrl(fp);
    final (:accessToken, :dPopToken) = await getTokensForResource(url, 'GET');
    final r = await http.get(
      Uri.parse(url),
      headers: {
        'Accept': 'application/json, */*',
        'Authorization': 'DPoP $accessToken',
        'Connection': 'keep-alive',
        'DPoP': dPopToken,
      },
    );
    return r.statusCode == 200 ? r.body : null;
  } catch (_) {
    return null;
  }
}

/// Write content to places.json file.

Future<bool> writePlacesJsonFile(String content) async {
  try {
    final fp = await getPlacesFilePath();
    final url = await getFileUrl(fp);
    final (:accessToken, :dPopToken) = await getTokensForResource(url, 'PUT');
    final r = await http.put(
      Uri.parse(url),
      headers: {
        'Accept': '*/*',
        'Authorization': 'DPoP $accessToken',
        'Connection': 'keep-alive',
        'Content-Type': 'application/json',
        'DPoP': dPopToken,
      },
      body: content,
    );
    return r.statusCode >= 200 && r.statusCode < 300;
  } catch (_) {
    return false;
  }
}

/// Write an individual place file.
///
/// Uses solidpod's [writePod] so that:
/// - The file is created or overwritten via an authenticated PUT.
/// - A `.acl` file is automatically created when it doesn't exist yet,
///   which is required before the file can be shared via [GrantPermissionUi].

Future<bool> writeIndividualPlaceFile(
  Place place, {
  bool createAcl = true,
}) async {
  try {
    await writePod(
      'places/place_${place.id}.json',
      jsonEncode(place.toJson()),
      encrypted: false,
      createAcl: createAcl,
      overwrite: true,
    );
    debugPrint('Write individual place file: places/place_${place.id}.json');
    return true;
  } catch (e) {
    debugPrint('Error writing individual place file: $e');
    return false;
  }
}

/// Delete an individual place file.

Future<bool> deleteIndividualPlaceFile(String placeId) async {
  try {
    final fp = await getIndividualPlaceFilePath(placeId);
    final url = await getFileUrl(fp);
    final (:accessToken, :dPopToken) = await getTokensForResource(
      url,
      'DELETE',
    );
    final r = await http.delete(
      Uri.parse(url),
      headers: {
        'Accept': '*/*',
        'Authorization': 'DPoP $accessToken',
        'Connection': 'keep-alive',
        'DPoP': dPopToken,
      },
    );

    // 404 means file doesn't exist, which is fine.
    return r.statusCode >= 200 && r.statusCode < 300 || r.statusCode == 404;
  } catch (_) {
    return false;
  }
}

/// Delete all individual place files for given place IDs.

Future<void> deleteAllIndividualPlaceFiles(List<String> ids) async {
  await Future.wait(ids.map((id) => deleteIndividualPlaceFile(id)));
}
