/// Sharing service: fetches external places shared with the user.
///
// Time-stamp: <2026-04-08 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program.  If not, see <https://opensource.org/license/gpl-3-0>.

library;

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:solidpod/solidpod.dart';

import 'package:geopod/models/external_place.dart';
import 'package:geopod/models/external_places_call_result.dart';
import 'package:geopod/models/place.dart';

// ── In-memory result cache ─────────────────────────────────────────────────
// Avoids repeating all Pod network requests every time the sharing page is
// opened within a short period.
ExternalPlacesCallResult? _cachedResult;
DateTime? _cacheTime;
const _cacheTtl = Duration(minutes: 5);

/// Invalidates the in-memory cache, forcing the next call to
/// [getExternalPlaceList] to re-fetch from the Pod.
void invalidateExternalPlaceCache() {
  _cachedResult = null;
  _cacheTime = null;
}

/// Reads the shared-resources permission log and returns external places
/// whose URLs look like geopod place files (`/places/place_`).
///
/// Returns an empty map on any error or when logged out.

Future<Map<dynamic, dynamic>> scanPermLogFile() async {
  try {
    final result = await sharedResources();
    if (result == SolidFunctionCallStatus.notLoggedIn) return {};
    return result as Map<dynamic, dynamic>;
  } catch (e) {
    debugPrint('[SharingService] scanPermLogFile error: $e');
    return {};
  }
}

/// Parses a single log entry into an [ExternalPlace].
///
/// Returns `null` if any required field is missing.

ExternalPlace? extPlaceDetailsFromLog({
  required Map logRecordOfFile,
  required String fileUrl,
}) {
  try {
    String? sharedTime;
    String? placeUrl;
    String? placeOwner;
    String? permissionGranter;
    String? permissionRecepient;
    String? permissionType;
    String? permissionList;

    final placeFileName = fileUrl.split('/').last;

    for (final entry in logRecordOfFile.entries) {
      final predicate = entry.key.toString();
      final value = entry.value.toString();

      if (predicate.contains(PermissionLogLiteral.logtime.toString())) {
        sharedTime = value;
      } else if (predicate.contains(PermissionLogLiteral.resource.toString())) {
        placeUrl = value;
      } else if (predicate.contains(PermissionLogLiteral.owner.toString())) {
        placeOwner = value;
      } else if (predicate.contains(PermissionLogLiteral.granter.toString())) {
        permissionGranter = value;
      } else if (predicate
          .contains(PermissionLogLiteral.recepient.toString())) {
        permissionRecepient = value;
      } else if (predicate.contains(PermissionLogLiteral.type.toString())) {
        permissionType = value;
      } else if (predicate
          .contains(PermissionLogLiteral.permissions.toString())) {
        permissionList = value;
      }
    }

    return ExternalPlace(
      sharedTime: sharedTime!,
      placeUrl: placeUrl!,
      placeFileName: placeFileName,
      placeOwner: placeOwner!,
      permissionGranter: permissionGranter!,
      permissionRecepient: permissionRecepient!,
      permissionType: permissionType!,
      permissionList: permissionList!,
    );
  } catch (e) {
    debugPrint('[SharingService] extPlaceDetailsFromLog error: $e');
    return null;
  }
}

/// Fetches the content of an external place file and returns the populated
/// [ExternalPlace] on success, or a [FileCallStatus] on failure.

Future<dynamic> getExternalPlaceContent(ExternalPlace place) async {
  try {
    final raw = await readPod(
      place.placeUrl,
      pathType: PathType.absoluteUrl,
    );

    // If readPod returned raw encrypted TTL (decryption key missing on
    // recipient's pod — shared-keys.ttl absent or key not found), detect it
    // before attempting JSON decode.
    final trimmed = raw.trimLeft();
    if (trimmed.startsWith('@prefix') || trimmed.startsWith('@base')) {
      debugPrint(
        '[SharingService] Encrypted TTL returned undecrypted '
        '(shared key missing): ${place.placeUrl}',
      );
      return FileCallStatus.decryptionKeyMissing;
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final content = Place.fromJson(decoded);
    return place.withContent(content);
  } on ResourceNotExistException catch (e) {
    debugPrint('[SharingService] Resource not found: $e');
    return FileCallStatus.fileNotExists;
  } on AccessForbiddenException catch (e) {
    debugPrint('[SharingService] Access forbidden (ACL not granted?): $e');
    return FileCallStatus.accessForbidden;
  } catch (e) {
    // Detect security key not yet set (thrown as plain Exception, not typed).
    if (e.toString().toLowerCase().contains('security key')) {
      debugPrint('[SharingService] Security key not available yet: $e');
      return FileCallStatus.securityKeyNotAvailable;
    }
    debugPrint('[SharingService] getExternalPlaceContent error: $e');
    return FileCallStatus.parsingFail;
  }
}

/// Returns the full list of external places shared with the current user.
///
/// Only entries whose URL contains `/places/place_` are considered geopod
/// place files; all others are silently ignored.
///
/// Skips entries whose access has been revoked (`permissionType == 'revoke'`).
///
/// Results are cached in memory for [_cacheTtl] to avoid redundant Pod
/// requests when the sharing page is reopened repeatedly.
/// Pass [forceRefresh] = true (or call [invalidateExternalPlaceCache]) to
/// bypass the cache.

Future<ExternalPlacesCallResult> getExternalPlaceList({
  bool hasCurrentAccess = true,
  bool forceRefresh = false,
}) async {
  // Return cached result if still fresh.
  if (!forceRefresh &&
      _cachedResult != null &&
      _cacheTime != null &&
      DateTime.now().difference(_cacheTime!) < _cacheTtl) {
    debugPrint('[SharingService] Returning cached result (${_cachedResult!.places?.length ?? 0} places).');
    return _cachedResult!;
  }
  final logMap = await scanPermLogFile();
  if (logMap.isEmpty) return const ExternalPlacesCallResult();

  final List<ExternalPlace> places = [];
  final List<String> unparseableLogRecords = [];

  for (final fileUrl in logMap.keys) {
    final urlStr = fileUrl.toString();

    // Filter only geopod place files (plain or encrypted).
    final isPlainPlace = urlStr.contains('/places/place_');
    final isEncPlace = urlStr.contains('/encrypted_data/enc_place_');
    if (!isPlainPlace && !isEncPlace) continue;

    final logRecord =
        logMap[fileUrl] as Map<PermissionLogLiteral, dynamic>;

    // Skip revoked entries if caller only wants current access.
    if (hasCurrentAccess &&
        logRecord[PermissionLogLiteral.type] == 'revoke') {
      continue;
    }

    try {
      final place = extPlaceDetailsFromLog(
        logRecordOfFile: logRecord,
        fileUrl: urlStr,
      );
      if (place != null) {
        places.add(place);
      } else {
        unparseableLogRecords.add(urlStr);
      }
    } catch (e) {
      debugPrint('[SharingService] Error parsing log record: $e');
    }
  }

  if (places.isEmpty) return const ExternalPlacesCallResult();

  // Fetch each place's content with a bounded concurrency (5 at a time) to
  // avoid overwhelming the Pod server or the device's network stack.
  const concurrentBatchSize = 5;
  final List<dynamic> results = [];
  for (var i = 0; i < places.length; i += concurrentBatchSize) {
    final batch = places.sublist(
      i,
      (i + concurrentBatchSize).clamp(0, places.length),
    );
    results.addAll(await Future.wait(batch.map(getExternalPlaceContent)));
  }

  final List<ExternalPlace> fullPlaces = [];
  final List<ExternalPlace> nonExistentPlaces = [];
  final List<ExternalPlace> forbiddenPlaces = [];
  final List<ExternalPlace> encryptionErrorPlaces = [];
  final List<ExternalPlace> unparseablePlaces = [];

  for (int i = 0; i < results.length; i++) {
    final r = results[i];
    if (r is ExternalPlace) {
      fullPlaces.add(r);
    } else if (r == FileCallStatus.fileNotExists) {
      nonExistentPlaces.add(places[i]);
    } else if (r == FileCallStatus.accessForbidden) {
      forbiddenPlaces.add(places[i]);
    } else if (r == FileCallStatus.decryptionKeyMissing ||
        r == FileCallStatus.securityKeyNotAvailable) {
      encryptionErrorPlaces.add(places[i]);
    } else {
      unparseablePlaces.add(places[i]);
    }
  }

  debugPrint(
    '[SharingService] Loaded ${fullPlaces.length} external places, '
    '${nonExistentPlaces.length} non-existent, '
    '${encryptionErrorPlaces.length} encryption-error, '
    '${unparseablePlaces.length} unparseable.',
  );

  final callResult = ExternalPlacesCallResult(
    places: fullPlaces,
    nonExistentPlaces: nonExistentPlaces,
    forbiddenPlaces: forbiddenPlaces,
    encryptionErrorPlaces: encryptionErrorPlaces,
    unparseablePlaces: unparseablePlaces,
  );

  // Update cache.
  _cachedResult = callResult;
  _cacheTime = DateTime.now();

  return callResult;
}

/// Status codes recycled from solidpod for internal use.
enum FileCallStatus {
  success,
  fail,
  fileNotExists,
  accessForbidden,
  /// The resource is an encrypted TTL file but the decryption key is not
  /// available on this user's pod (shared-keys.ttl absent or key not found).
  decryptionKeyMissing,
  /// The security key has not been set / cached yet when the read was
  /// attempted.  Refreshing after the key is ready should resolve this.
  securityKeyNotAvailable,
  parsingFail,
}
