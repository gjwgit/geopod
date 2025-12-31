/// Service for managing places data in the user's Solid Pod.
///
// Time-stamp: <2025-12-04 Miduo>
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
///
/// Authors: Graham Williams, Miduo

library;

import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solidpod/solidpod.dart';

import 'package:geopod/models/place.dart';
import 'package:geopod/services/geocoding_service.dart';
import 'package:geopod/services/places/places_cache_manager.dart';
import 'package:geopod/services/places/places_import_export.dart';
import 'package:geopod/services/pod/pod_directory_service.dart';

export 'package:geopod/models/place.dart';
export 'package:geopod/services/places/places_cache_manager.dart';
export 'package:geopod/services/places/places_import_export.dart';

final placesChangeNotifier = ValueNotifier<int>(0);

const String _placesFileName = 'places.json';
const String _keyPodPlacesCache = 'pod_places_cache';
const String _keyPodPlacesCacheTimestamp = 'pod_places_cache_timestamp';
const Duration _cacheExpiry = Duration(minutes: 5);

class PlacesService {
  static List<Place>? _cachedLocalPlaces;

  static Future<String> _getFullFilePath() async {
    final path = await getDataDirPath();
    return '$path/places/$_placesFileName';
  }

  static Future<List<Place>> loadLocalPlaces() async {
    if (_cachedLocalPlaces != null) return _cachedLocalPlaces!;
    final places = <Place>[];
    try {
      final json = await rootBundle.loadString('assets/data/places.json');
      final decoded = jsonDecode(json);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            try {
              places.add(Place.fromJson(item, isLocalSource: true));
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
    _cachedLocalPlaces = places;
    return places;
  }

  static Future<String?> _readJsonFile() async {
    try {
      final fp = await _getFullFilePath();
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

  static Future<bool> _writeJsonFile(String content) async {
    try {
      final fp = await _getFullFilePath();
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

  static Future<List<Place>> fetchPlaces({bool forceRefresh = false}) async {
    final cm = PlacesCacheManager();
    if (!forceRefresh) {
      final c = cm.allPlaces;
      if (c != null) return c;
    }
    final results = await Future.wait([
      loadLocalPlaces(),
      fetchPodPlaces(forceRefresh: forceRefresh),
    ]);
    final all = <Place>[...results[1], ...results[0]];
    cm.cacheAllPlaces(all);
    return all;
  }

  static Future<List<Place>> fetchPodPlaces({bool forceRefresh = false}) async {
    final places = <Place>[];
    final cm = PlacesCacheManager();
    try {
      if (!await checkLoggedIn()) return places;
      if (!forceRefresh) {
        final mc = cm.podPlaces;
        if (mc != null) {
          _refreshPodPlacesInBackground();
          return mc;
        }
      }
      if (!forceRefresh) {
        final c = await _getCachedPodPlaces();
        if (c != null) {
          cm.cachePodPlaces(c);
          _refreshPodPlacesInBackground();
          return c;
        }
      }
      final content = await _readJsonFile();
      if (content == null || content.trim().isEmpty) return places;
      final decoded = jsonDecode(content);
      if (decoded is List) {
        for (final i in decoded) {
          if (i is Map<String, dynamic>) {
            try {
              places.add(Place.fromJson(i, isLocalSource: false));
            } catch (_) {}
          }
        }
      } else if (decoded is Map<String, dynamic>) {
        try {
          places.add(Place.fromJson(decoded, isLocalSource: false));
        } catch (_) {}
      }
      places.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      await _cachePodPlaces(content);
      cm.cachePodPlaces(places);
    } catch (_) {}
    return places;
  }

  static Future<List<Place>?> _getCachedPodPlaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_keyPodPlacesCache);
      final ts = prefs.getInt(_keyPodPlacesCacheTimestamp);
      if (json == null || ts == null) return null;
      if (DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts)) >
          _cacheExpiry) {
        return null;
      }
      final places = <Place>[];
      final decoded = jsonDecode(json);
      if (decoded is List) {
        for (final i in decoded) {
          if (i is Map<String, dynamic>) {
            try {
              places.add(Place.fromJson(i, isLocalSource: false));
            } catch (_) {}
          }
        }
      }
      places.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return places;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _cachePodPlaces(String json) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_keyPodPlacesCache, json);
      await p.setInt(
        _keyPodPlacesCacheTimestamp,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  static void _refreshPodPlacesInBackground() {
    Future(() async {
      try {
        if (!await checkLoggedIn()) return;
        final c = await _readJsonFile();
        if (c != null && c.trim().isNotEmpty) await _cachePodPlaces(c);
      } catch (_) {}
    });
  }

  static Future<void> clearCache() async {
    try {
      PlacesCacheManager().clearCache();
      final p = await SharedPreferences.getInstance();
      await p.remove(_keyPodPlacesCache);
      await p.remove(_keyPodPlacesCacheTimestamp);
    } catch (_) {}
  }

  static Future<void> clearPodCacheOnly() async {
    try {
      PlacesCacheManager().clearPodCacheOnly();
      final p = await SharedPreferences.getInstance();
      await p.remove(_keyPodPlacesCache);
      await p.remove(_keyPodPlacesCacheTimestamp);
    } catch (_) {}
  }

  static Future<List<Place>> refreshPodDataOnly() async {
    final cm = PlacesCacheManager();
    final local = await loadLocalPlaces();
    await clearPodCacheOnly();
    final pod = await fetchPodPlaces(forceRefresh: true);
    final all = <Place>[...pod, ...local];
    cm.cacheAllPlaces(all);
    return all;
  }

  static Future<bool> addPlace(
    Place place,
    BuildContext context,
    Widget returnWidget,
  ) async {
    try {
      if (!await checkLoggedIn()) return false;
      final cm = PlacesCacheManager();
      var existing = cm.podPlaces ?? await fetchPodPlaces();
      final updated = List<Place>.from(existing)..insert(0, place);
      final success = await _writeJsonFile(
        jsonEncode(updated.map((p) => p.toJson()).toList()),
      );
      if (success) {
        await clearCache();
        placesChangeNotifier.value++;
        // Notify file browser to update
        PodDirectoryService.notifyChange();
      }
      return success;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deletePlace(
    String placeId,
    BuildContext context,
    Widget returnWidget,
  ) async {
    try {
      if (!await checkLoggedIn()) return false;
      final cm = PlacesCacheManager();
      var existing = cm.podPlaces ?? await fetchPodPlaces();
      final updated = List<Place>.from(existing)
        ..removeWhere((p) => p.id == placeId);
      final success = await _writeJsonFile(
        jsonEncode(updated.map((p) => p.toJson()).toList()),
      );
      if (success) {
        await clearCache();
        placesChangeNotifier.value++;
        // Notify file browser to update
        PodDirectoryService.notifyChange();
      }
      return success;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> exportPlaces(List<Place> places) =>
      PlacesImportExport.exportPlaces(places);
  static Future<ImportResult> importPlaces() =>
      PlacesImportExport.importPlaces();

  static Future<bool> mergeImportedPlaces(
    List<Place> imported,
    BuildContext context,
    Widget returnWidget, {
    void Function(int, int)? onProgress,
  }) async {
    try {
      if (!await checkLoggedIn()) return false;
      final existing = await fetchPodPlaces();
      final ids = existing.map((p) => p.id).toSet();
      final newPlaces = imported.where((p) => !ids.contains(p.id)).toList();
      if (newPlaces.isEmpty && imported.isNotEmpty) return true;
      final withAddr = <Place>[];
      for (int i = 0; i < newPlaces.length; i++) {
        final p = newPlaces[i];
        onProgress?.call(i + 1, newPlaces.length);
        final addr = await GeocodingService.getAddress(p.lat, p.lng);
        withAddr.add(
          Place(
            id: p.id,
            lat: p.lat,
            lng: p.lng,
            note: p.note,
            timestamp: p.timestamp,
            address: addr,
            isLocal: false,
          ),
        );
      }
      final merged = [...withAddr, ...existing];
      final success = await _writeJsonFile(
        jsonEncode(merged.map((p) => p.toJson()).toList()),
      );
      if (success) {
        await clearCache();
        placesChangeNotifier.value++;
        // Notify file browser to update
        PodDirectoryService.notifyChange();
      }
      return success;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> clearAllPlaces(
    BuildContext context,
    Widget returnWidget,
  ) async {
    try {
      if (!await checkLoggedIn()) return false;
      final success = await _writeJsonFile('[]');
      if (success) {
        await clearCache();
        placesChangeNotifier.value++;
        // Notify file browser to update
        PodDirectoryService.notifyChange();
      }
      return success;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> updatePlace(
    Place updated,
    BuildContext context,
    Widget returnWidget, {
    bool coordinatesChanged = false,
  }) async {
    try {
      if (!await checkLoggedIn()) return false;
      final existing = await fetchPodPlaces();
      final list = List<Place>.from(existing);
      final i = list.indexWhere((p) => p.id == updated.id);
      if (i == -1) {
        list.insert(0, updated);
      } else {
        var toSave = updated;
        if (coordinatesChanged) {
          final addr = await GeocodingService.getAddress(
            updated.lat,
            updated.lng,
          );
          toSave = Place(
            id: updated.id,
            lat: updated.lat,
            lng: updated.lng,
            note: updated.note,
            timestamp: updated.timestamp,
            address: addr,
            isLocal: false,
          );
        }
        list[i] = toSave;
      }
      final success = await _writeJsonFile(
        jsonEncode(list.map((p) => p.toJson()).toList()),
      );
      if (success) {
        await clearCache();
        placesChangeNotifier.value++;
        // Notify file browser to update
        PodDirectoryService.notifyChange();
      }
      return success;
    } catch (_) {
      return false;
    }
  }
}

Future<void> preloadPlacesData() async {
  try {
    unawaited(
      PlacesService.fetchPlaces(
        forceRefresh: false,
      ).catchError((_) => <Place>[]),
    );
  } catch (_) {}
}
