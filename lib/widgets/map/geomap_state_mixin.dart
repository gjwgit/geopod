/// State management for GeoMap widget.
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

import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:geopod/models/place.dart';
import 'package:geopod/services/gdelt_news_service.dart';
import 'package:geopod/services/map_settings_service.dart';
import 'package:geopod/widgets/map/marker_data.dart';

/// Manages map state variables.
mixin GeoMapStateMixin {
  MapController get mapController;
  TileProvider get tileProvider;
  set tileProvider(TileProvider value);
  List<Place> get allPlaces;
  set allPlaces(List<Place> value);
  Set<String> get savingPlaceIds;
  bool get isLoadingPlaces;
  set isLoadingPlaces(bool value);
  MapSettings get mapSettings;
  set mapSettings(MapSettings value);
  bool get isLoggedIn;
  set isLoggedIn(bool value);
  AnimationController get animationController;
  Animation<double> get fadeAnimation;
  bool get initialAnimationComplete;
  set initialAnimationComplete(bool value);
  bool get isPostLoginRefresh;
  set isPostLoginRefresh(bool value);
  GdeltNewsService get newsService;
  List<NewsMarker> get newsMarkers;
  set newsMarkers(List<NewsMarker> value);
  bool get showNewsMarkers;
  set showNewsMarkers(bool value);
  bool get isLoadingNews;
  set isLoadingNews(bool value);
  LatLng get initialCenter;
  set initialCenter(LatLng value);
  double get initialZoom;
  set initialZoom(double value);
  bool get viewportInitialized;
  set viewportInitialized(bool value);
  bool get skipPlacesChangeNotification;
  set skipPlacesChangeNotification(bool value);
  bool get isLocating;
  set isLocating(bool value);
}

/// Manages marker cache for performance.
mixin MarkerCacheMixin {
  List<MarkerData>? _cachedFilteredMarkers;
  int _lastPlacesHash = 0;
  int _lastSavingIdsHash = 0;
  bool _lastShowLocalPlaces = true;
  bool _lastShowEncryptedPlaces = false;

  /// Get filtered markers with caching to avoid expensive rebuilds.
  List<MarkerData> getCachedFilteredMarkers({
    required List<Place> allPlaces,
    required MapSettings mapSettings,
    required Set<String> savingPlaceIds,
    required List<MarkerData> Function() builder,
  }) {
    // Compute hashes to detect changes
    final placesHash = Object.hashAll(allPlaces.map((p) => p.id));
    final savingHash = Object.hashAll(savingPlaceIds);
    final showLocal = mapSettings.showLocalPlaces;
    final showEncrypted = mapSettings.showEncryptedPlaces;

    // Return cached if nothing changed
    if (_cachedFilteredMarkers != null &&
        placesHash == _lastPlacesHash &&
        savingHash == _lastSavingIdsHash &&
        showLocal == _lastShowLocalPlaces &&
        showEncrypted == _lastShowEncryptedPlaces) {
      return _cachedFilteredMarkers!;
    }

    // Rebuild and cache
    _lastPlacesHash = placesHash;
    _lastSavingIdsHash = savingHash;
    _lastShowLocalPlaces = showLocal;
    _lastShowEncryptedPlaces = showEncrypted;
    _cachedFilteredMarkers = builder();
    return _cachedFilteredMarkers!;
  }

  /// Clear marker cache.
  void clearMarkerCache() {
    _cachedFilteredMarkers = null;
  }
}
