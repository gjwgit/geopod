/// State management logic for GeoMapWidget.
///
// Time-stamp: <Wednesday 2025-12-18 08:22:27 +1100 Graham Williams>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:solidpod/solidpod.dart';

import 'package:geopod/models/place.dart';
import 'package:geopod/services/places_service_v2.dart'
    show PlacesServiceV2, PlacesCacheManager;

/// Handles login state change.
Future<List<Place>> handleLoginStateChange({
  required bool wasLoggedIn,
  required bool isNowLoggedIn,
}) async {
  if (isNowLoggedIn && !wasLoggedIn) {
    return await PlacesServiceV2.refreshPodDataOnly();
  } else if (!isNowLoggedIn && wasLoggedIn) {
    await PlacesServiceV2.clearPodCacheOnly();
    return await PlacesServiceV2.loadLocalPlaces();
  }
  return [];
}

/// Verifies login state and returns appropriate places.
Future<VerifyLoginResult> verifyLoginStateAndLoadData({
  required bool currentIsLoggedIn,
}) async {
  final actuallyLoggedIn = await checkLoggedIn();
  final loginStateChanged = currentIsLoggedIn != actuallyLoggedIn;

  if (loginStateChanged) {
    authStateNotifier.value = actuallyLoggedIn;
    PlacesServiceV2.clearCache();
  }

  final cm = PlacesCacheManager();
  final cached = cm.allPlaces;
  final cacheState = cm.wasLoggedInWhenCached;

  List<Place>? places;
  bool needsRefresh = false;

  if (cached != null && cacheState == actuallyLoggedIn) {
    places = List.from(cached);
  } else {
    if (cached != null && cacheState != actuallyLoggedIn) {
      PlacesServiceV2.clearCache();
    }
    needsRefresh = true;
  }

  return VerifyLoginResult(
    actuallyLoggedIn: actuallyLoggedIn,
    loginStateChanged: loginStateChanged,
    places: places,
    needsRefresh: needsRefresh,
  );
}

/// Result of login state verification.
class VerifyLoginResult {
  final bool actuallyLoggedIn;
  final bool loginStateChanged;
  final List<Place>? places;
  final bool needsRefresh;

  const VerifyLoginResult({
    required this.actuallyLoggedIn,
    required this.loginStateChanged,
    required this.places,
    required this.needsRefresh,
  });
}

/// Loads all places with optional force refresh.
Future<List<Place>> loadAllPlaces({bool forceRefresh = false}) async {
  return await PlacesServiceV2.fetchPlaces(forceRefresh: forceRefresh);
}
