/// State management for GeoMap widget.
///
// Time-stamp: <Tuesday 2026-01-29 Miduo>
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
  LatLng? get userLocation;
  set userLocation(LatLng? value);
}

/// Manages marker cache for performance.

mixin MarkerCacheMixin {
  List<MarkerData>? _cachedFilteredMarkers;
  int _lastPlacesHash = 0;
  int _lastSavingIdsHash = 0;
  bool _lastShowLocalPlaces = true;
  bool _lastHideAllMarkers = false;
  Color _lastUserPlacesColor = Colors.blue;
  Color _lastLocalPlacesColor = Colors.red;

  /// Get filtered markers with caching to avoid expensive rebuilds.

  List<MarkerData> getCachedFilteredMarkers({
    required List<Place> allPlaces,
    required MapSettings mapSettings,
    required Set<String> savingPlaceIds,
    required List<MarkerData> Function() builder,
  }) {
    final placesHash = Object.hashAll(
      allPlaces.map((p) => '${p.id}_${p.note}_${p.lat}_${p.lng}'),
    );
    final savingHash = Object.hashAll(savingPlaceIds);
    final showLocal = mapSettings.showLocalPlaces;
    final hideMarkers = mapSettings.hideAllMarkers;
    final userColor = mapSettings.userPlacesColor;
    final localColor = mapSettings.localPlacesColor;

    if (_cachedFilteredMarkers != null &&
        placesHash == _lastPlacesHash &&
        savingHash == _lastSavingIdsHash &&
        showLocal == _lastShowLocalPlaces &&
        hideMarkers == _lastHideAllMarkers &&
        userColor == _lastUserPlacesColor &&
        localColor == _lastLocalPlacesColor) {
      return _cachedFilteredMarkers!;
    }

    _lastPlacesHash = placesHash;
    _lastSavingIdsHash = savingHash;
    _lastShowLocalPlaces = showLocal;
    _lastHideAllMarkers = hideMarkers;
    _lastUserPlacesColor = userColor;
    _lastLocalPlacesColor = localColor;
    _cachedFilteredMarkers = builder();
    return _cachedFilteredMarkers!;
  }

  /// Clear marker cache.

  void clearMarkerCache() {
    _cachedFilteredMarkers = null;
  }
}
