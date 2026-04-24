/// Service for managing the places cache lifecycle.
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

import 'package:geopod/models/place.dart';
import 'package:geopod/services/places/encrypted_places_service.dart';
import 'package:geopod/services/places/places_cache_manager.dart';
import 'package:geopod/services/places/places_cache_persistence.dart';
import 'package:geopod/services/places/places_fetch_service.dart';

/// Handles cache clearing and data-refresh helpers.
///
/// These operations sit above raw network I/O (handled by
/// [PlacesFetchService]) but below the mutation methods (handled by
/// [PlacesWriteService]).

class PlacesCacheService {
  /// Clears all in-memory and persisted caches, including the encrypted
  /// places session state.

  static Future<void> clearCache() async {
    try {
      PlacesCacheManager().clearCache();
      PlacesFetchService.clearInFlight();
      // Both are independent — run in parallel.
      await Future.wait([
        PlacesCachePersistence.clearPodPlacesCache(),
        EncryptedPlacesService.resetSessionState(),
      ]);
    } catch (_) {}
  }

  /// Clears only the Pod (non-encrypted) portion of the cache.

  static Future<void> clearPodCacheOnly() async {
    try {
      PlacesCacheManager().clearPodCacheOnly();
      PlacesFetchService.clearInFlight();
      await PlacesCachePersistence.clearPodPlacesCache();
    } catch (_) {}
  }

  /// Forces a fresh fetch from the Pod while keeping local and encrypted
  /// places intact.
  ///
  /// Returns the merged list of Pod + local places after the refresh.

  static Future<List<Place>> refreshPodDataOnly() async {
    final cm = PlacesCacheManager();

    // Local places are synchronous (compiled into binary).
    final local = PlacesFetchService.getLocalPlacesSync();
    await clearPodCacheOnly();
    final pod = await PlacesFetchService.fetchPodPlaces(forceRefresh: true);
    final all = <Place>[...pod, ...local];
    cm.cacheAllPlaces(all);
    return all;
  }
}
