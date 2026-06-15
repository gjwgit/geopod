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
    // getResource handles DPoP/auth via solidpod; it throws when the file is
    // absent, which the catch treats as "no places file yet".
    final bytes = await getResource(url);
    return utf8.decode(bytes);
  } catch (_) {
    return null;
  }
}

/// Write content to places.json file.

Future<bool> writePlacesJsonFile(String content) async {
  try {
    final fp = await getPlacesFilePath();
    final url = await getFileUrl(fp);
    // createResource PUTs the content (replacing any existing file) with DPoP
    // handled by solidpod, and throws on failure. Places data is round-tripped
    // as JSON by geopod, so the stored content-type label is not significant.
    await createResource(url, content: content);
    return true;
  } catch (_) {
    return false;
  }
}

/// Write an individual place file.

Future<bool> writeIndividualPlaceFile(Place place) async {
  try {
    final fp = await getIndividualPlaceFilePath(place.id);
    final url = await getFileUrl(fp);
    await createResource(url, content: jsonEncode(place.toJson()));
    debugPrint('Write individual place file: $fp');
    return true;
  } catch (e) {
    debugPrint('Error writing individual place file: $e');
    return false;
  }
}

/// Delete an individual place file.
///
/// NOTE: still uses the raw HTTP path. solidpod's [deleteResource] requires a
/// (currently non-exported) ResourceContentType argument and throws on 404,
/// whereas here a missing file is treated as success. Convert to
/// [deleteResource] once solidpod exports ResourceContentType (same follow-up
/// as the media-upload MIME work).

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
