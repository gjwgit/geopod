/// Sharing service: fetches external places shared with the user.
///
// Time-stamp: <2026-09-07 Amogh>
///
/// Copyright (C) 2025-2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:solidpod/solidpod.dart';

import 'package:geopod/models/external_place.dart';
import 'package:geopod/models/external_places_call_result.dart';
import 'package:geopod/models/place.dart';

/// In-memory cache for external places to reduce network traffic.

ExternalPlacesCallResult? _cachedResult;
DateTime? _cacheTime;
const Duration _cacheTtl = Duration(minutes: 2);

/// Notifier incremented when shared places cache is refreshed or invalidated.

final sharedPlacesChangeNotifier = ValueNotifier<int>(0);

/// Invalidate the external places cache and notify listeners.

void invalidateExternalPlaceCache() {
  _cachedResult = null;
  _cacheTime = null;
  sharedPlacesChangeNotifier.value++;
}

/// Reads the shared-resources permission log and returns external places.
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
      } else if (predicate.contains(
        PermissionLogLiteral.recepient.toString(),
      )) {
        permissionRecepient = value;
      } else if (predicate.contains(PermissionLogLiteral.type.toString())) {
        permissionType = value;
      } else if (predicate.contains(
        PermissionLogLiteral.permissions.toString(),
      )) {
        permissionList = value;
      }
    }

    if (sharedTime == null ||
        placeUrl == null ||
        placeOwner == null ||
        permissionGranter == null ||
        permissionRecepient == null ||
        permissionType == null ||
        permissionList == null) {
      return null;
    }

    return ExternalPlace(
      sharedTime: sharedTime,
      placeUrl: placeUrl,
      placeFileName: placeFileName,
      placeOwner: placeOwner,
      permissionGranter: permissionGranter,
      permissionRecepient: permissionRecepient,
      permissionType: permissionType,
      permissionList: permissionList,
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
    final raw = await readPod(place.placeUrl, pathType: PathType.absoluteUrl);

    // If readPod returned raw encrypted TTL (decryption key missing on
    // recipient's Pod), detect it before attempting JSON decode.
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
/// Only entries whose URL contains `/places/place_` or
/// `/encrypted_data/enc_place_` are considered geopod place files.

Future<ExternalPlacesCallResult> getExternalPlaceList({
  bool hasCurrentAccess = true,
  bool forceRefresh = false,
}) async {
  if (forceRefresh) {
    invalidateExternalPlaceCache();
  } else if (_cachedResult != null &&
      _cacheTime != null &&
      DateTime.now().difference(_cacheTime!) < _cacheTtl) {
    debugPrint(
      '[SharingService] Returning cached result '
      '(${_cachedResult!.places?.length ?? 0} places).',
    );
    return _cachedResult!;
  }

  final logMap = await scanPermLogFile();
  if (logMap.isEmpty) return const ExternalPlacesCallResult();

  final List<ExternalPlace> places = [];

  for (final fileUrl in logMap.keys) {
    final urlStr = fileUrl.toString();

    final isPlainPlace = urlStr.contains('/places/place_');
    final isEncPlace = urlStr.contains('/encrypted_data/enc_place_');
    if (!isPlainPlace && !isEncPlace) continue;

    final logRecord = logMap[fileUrl] as Map;

    // Skip revoked entries if caller only wants current access.
    final typeEntry = logRecord.entries.firstWhere(
      (e) => e.key.toString().contains(PermissionLogLiteral.type.toString()),
      orElse: () => const MapEntry('', ''),
    );
    if (hasCurrentAccess && typeEntry.value.toString() == 'revoke') {
      continue;
    }

    try {
      final place = extPlaceDetailsFromLog(
        logRecordOfFile: logRecord,
        fileUrl: urlStr,
      );
      if (place != null) {
        places.add(place);
      }
    } catch (e) {
      debugPrint('[SharingService] Error parsing log record: $e');
    }
  }

  if (places.isEmpty) return const ExternalPlacesCallResult();

  // Concurrently fetch places in bounded batches of 5 to avoid overloading network.
  const concurrentBatchSize = 5;
  final List<dynamic> results = [];
  for (var i = 0; i < places.length; i += concurrentBatchSize) {
    final end = (i + concurrentBatchSize).clamp(0, places.length);
    final batch = places.sublist(i, end);
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

  final callResult = ExternalPlacesCallResult(
    places: fullPlaces,
    nonExistentPlaces: nonExistentPlaces,
    forbiddenPlaces: forbiddenPlaces,
    encryptionErrorPlaces: encryptionErrorPlaces,
    unparseablePlaces: unparseablePlaces,
  );

  _cachedResult = callResult;
  _cacheTime = DateTime.now();

  return callResult;
}

/// Status codes for internal call handling.

enum FileCallStatus {
  success,
  fail,
  fileNotExists,
  accessForbidden,
  decryptionKeyMissing,
  securityKeyNotAvailable,
  parsingFail,
}
