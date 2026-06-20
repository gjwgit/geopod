/// Service for fetching and reading places data.
///
// Time-stamp: <2026-01-07 Miduo>
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

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:solidpod/solidpod.dart';

import 'package:geopod/constants/example_places_data.dart';
import 'package:geopod/models/place.dart';
import 'package:geopod/services/places/encrypted_places_service.dart';
import 'package:geopod/services/places/places_cache_manager.dart';
import 'package:geopod/services/places/places_cache_persistence.dart';
import 'package:geopod/services/places/places_pod_file.dart';

/// Handles all read/fetch operations for places data.
///
/// This class is responsible for loading places from local compiled data,
/// the user's Solid Pod, and the encrypted places storage.

class PlacesFetchService {
  /// Cached local places (lazily initialised from compiled constants).
  static List<Place>? _cachedLocalPlaces;

  /// In-flight Pod fetch future — ensures only one network request is issued
  /// at a time even when multiple callers request concurrently (e.g. GeoMap
  /// and LocationsPage both reacting to the same authStateNotifier event).
  static Future<List<Place>>? _podFetch;

  /// Clears the in-flight future reference so the next call issues a fresh
  /// request.  Called by [PlacesCacheService.clearCache] on logout.
  static void clearInFlight() => _podFetch = null;

  /// Get local example places synchronously.

  static List<Place> getLocalPlacesSync() {
    _cachedLocalPlaces ??= kExamplePlacesData
        .map((json) => Place.fromJson(json, isLocalSource: true))
        .toList();
    return _cachedLocalPlaces!;
  }

  /// Load local example places (async wrapper for API compatibility).
  /// NOTE: Prefer using getLocalPlacesSync() directly as local places
  /// are now compiled into the app and don't require async loading.

  @Deprecated('Use getLocalPlacesSync() instead - local data is compiled in')
  static Future<List<Place>> loadLocalPlaces() async => getLocalPlacesSync();

  /// Fetch all places: local, Pod, and optionally encrypted.
  ///
  /// Uses [PlacesCacheManager] to avoid redundant network requests.
  /// Pass [forceRefresh] to bypass in-memory and persisted caches.

  static Future<List<Place>> fetchPlaces({
    bool forceRefresh = false,
    bool includeEncrypted = false,
  }) async {
    final cm = PlacesCacheManager();
    if (!forceRefresh) {
      final c = cm.allPlaces;
      if (c != null) {
        // If cached but need encrypted and none present, try fast-merge from
        // EncryptedPlacesService in-memory cache before any network call.
        if (includeEncrypted && !c.any((p) => p.isEncrypted)) {
          final cachedEnc = EncryptedPlacesService.getCachedEncryptedPlaces();
          if (cachedEnc != null && cachedEnc.isNotEmpty) {
            final merged = [...c, ...cachedEnc];
            cm.cacheAllPlaces(merged);
            return merged;
          }
          // No encrypted cache — fall through to network fetch.
        } else {
          return c;
        }
      }
    }

    // Local places are synchronous (compiled into binary) - get them immediately.
    final localPlaces = getLocalPlacesSync();

    // Fetch network data in parallel for better performance.
    final results = await Future.wait([
      fetchPodPlaces(forceRefresh: forceRefresh),
      includeEncrypted
          ? fetchEncryptedPlaces(forceRefresh: forceRefresh)
          : Future.value(<Place>[]),
    ]);

    final podPlaces = results[0];
    final encryptedPlaces = results[1];

    final all = <Place>[...podPlaces, ...encryptedPlaces, ...localPlaces];
    cm.cacheAllPlaces(all);
    return all;
  }

  /// Fetch encrypted places from Pod.
  ///
  /// Returns an empty list if not logged in or no security key is available.
  /// NOTE: Will not prompt for security key — use [EncryptedPlacesService]
  /// directly if you need to prompt the user.

  static Future<List<Place>> fetchEncryptedPlaces({
    bool forceRefresh = false,
  }) async {
    try {
      if (!authStateNotifier.value) return [];

      // Fast path: data already in memory — skip the async key check entirely.
      if (!forceRefresh && EncryptedPlacesService.hasLoadedEncryptedPlaces) {
        return EncryptedPlacesService.getCachedEncryptedPlaces()!;
      }

      // Check if security key is available - don't try to load if not.
      final hasKey = await EncryptedPlacesService.isSecurityKeyAvailable();
      if (!hasKey) {
        return [];
      }

      final encPlaces = await EncryptedPlacesService.fetchEncryptedPlaces(
        forceRefresh: forceRefresh,
      );
      return encPlaces;
    } catch (e) {
      debugPrint('PlacesFetchService.fetchEncryptedPlaces error: $e');
      return [];
    }
  }

  /// Fetch places stored in the user's Solid Pod.
  ///
  /// Checks in-memory cache, then persisted disk cache, before making a
  /// network request.  A background refresh is also kicked off when serving
  /// from cache so stale data is kept fresh.

  static Future<List<Place>> fetchPodPlaces({bool forceRefresh = false}) async {
    final cm = PlacesCacheManager();
    if (!authStateNotifier.value) return [];

    // Fast path: in-memory cache hit (no network needed).
    if (!forceRefresh) {
      final mc = cm.podPlaces;
      if (mc != null) {
        _refreshPodPlacesInBackground();
        return mc;
      }
      final c = await PlacesCachePersistence.getCachedPodPlaces();
      if (c != null) {
        cm.cachePodPlaces(c);
        _refreshPodPlacesInBackground();
        return c;
      }
    }

    // In-flight dedup: if a network fetch is already running, await it instead
    // of issuing a second parallel request (e.g. GeoMap + LocationsPage both
    // reacting to the same authStateNotifier change).
    if (_podFetch != null) return _podFetch!;

    _podFetch = _fetchPodPlacesFromNetwork(cm);
    try {
      return await _podFetch!;
    } finally {
      _podFetch = null;
    }
  }

  static Future<List<Place>> _fetchPodPlacesFromNetwork(
    PlacesCacheManager cm,
  ) async {
    final places = <Place>[];
    try {
      final content = await readPlacesJsonFile();
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
      await PlacesCachePersistence.cachePodPlaces(content);
      cm.cachePodPlaces(places);

      // Log any plain (unencrypted) places found — migration to encrypted
      // storage requires a BuildContext and is handled at the call site.
      final plainCount = places.where((p) => !p.isEncrypted).length;
      if (plainCount > 0) {
        debugPrint(
          'PlacesFetchService: $plainCount plain place(s) found; '
          'migrate them by re-saving from the Locations page.',
        );
      }
    } catch (_) {}
    return places;
  }

  static void _refreshPodPlacesInBackground() {
    Future(() async {
      try {
        if (!authStateNotifier.value) return;
        final c = await readPlacesJsonFile();
        if (c != null && c.trim().isNotEmpty) {
          await PlacesCachePersistence.cachePodPlaces(c);
        }
      } catch (_) {}
    });
  }
}
