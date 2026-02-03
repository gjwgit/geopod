/// In-memory cache manager for instant access to places data.
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

import 'package:solidpod/solidpod.dart';

import 'package:geopod/models/place.dart';

/// In-memory cache manager for instant access to places data.

class PlacesCacheManager {
  // Singleton pattern.
  static final PlacesCacheManager _instance = PlacesCacheManager._internal();
  factory PlacesCacheManager() => _instance;
  PlacesCacheManager._internal();

  /// Cached all places (local + Pod)

  List<Place>? _allPlacesCache;

  /// Cached Pod-only places.

  List<Place>? _podPlacesCache;

  /// Last cache update timestamp.

  DateTime? _lastCacheTime;

  /// Login state when cache was created (to prevent guest using logged-in user's cache)

  bool? _wasLoggedInWhenCached;

  /// Cache validity duration (in-memory cache, should be long enough for login)

  static const Duration _memoryCacheExpiry = Duration(minutes: 30);

  /// Gets all cached places (local + Pod)

  List<Place>? get allPlaces {
    if (_allPlacesCache == null || _isCacheExpired()) {
      return null;
    }
    return List.unmodifiable(_allPlacesCache!);
  }

  /// Gets the login state when cache was created.

  bool? get wasLoggedInWhenCached => _wasLoggedInWhenCached;

  /// Gets cached Pod places only.

  List<Place>? get podPlaces {
    if (_podPlacesCache == null || _isCacheExpired()) {
      return null;
    }
    return List.unmodifiable(_podPlacesCache!);
  }

  /// Caches all places data with current login state.

  void cacheAllPlaces(List<Place> places) {
    _allPlacesCache = List.from(places);
    _lastCacheTime = DateTime.now();
    _wasLoggedInWhenCached = authStateNotifier.value;
  }

  /// Caches Pod places data.

  void cachePodPlaces(List<Place> places) {
    _podPlacesCache = List.from(places);
    _lastCacheTime = DateTime.now();
  }

  /// Checks if in-memory cache is expired.

  bool _isCacheExpired() {
    if (_lastCacheTime == null) return true;
    return DateTime.now().difference(_lastCacheTime!) > _memoryCacheExpiry;
  }

  /// Clears all in-memory cache.

  void clearCache() {
    _allPlacesCache = null;
    _podPlacesCache = null;
    _lastCacheTime = null;
    _wasLoggedInWhenCached = null;
  }

  /// Clears only Pod-related cache, preserves local places structure
  /// allPlaces cache is cleared because it contains merged data.

  void clearPodCacheOnly() {
    _allPlacesCache = null; // Clear merged cache (will be rebuilt)
    _podPlacesCache = null; // Clear Pod cache
    _lastCacheTime = null;
    _wasLoggedInWhenCached = null;

    // Note: Local places are cached in PlacesService._cachedLocalPlaces, not here.
  }

  /// Forces cache refresh on next fetch.

  void invalidateCache() {
    _lastCacheTime = null;
  }
}
