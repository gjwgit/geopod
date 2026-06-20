/// Event handlers for GeoMap authentication and data changes.
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
import 'package:solidpod/solidpod.dart' show authStateNotifier;

import 'package:geopod/services/map_settings_service.dart';
import 'package:geopod/services/places_service.dart';

/// Handles authentication and places change events.

mixin GeoMapEventHandlers<T extends StatefulWidget> on State<T> {
  MapController get mapController;
  List<Place> get allPlaces;
  set allPlaces(List<Place> value);
  bool get isLoggedIn;
  set isLoggedIn(bool value);
  bool get skipPlacesChangeNotification;
  set skipPlacesChangeNotification(bool value);
  bool get viewportInitialized;
  set viewportInitialized(bool value);
  LatLng get initialCenter;
  set initialCenter(LatLng value);
  double get initialZoom;
  set initialZoom(double value);
  MapSettings get mapSettings;

  /// Handle authentication state changes.

  Future<void> onAuthStateChanged() async {
    if (!mounted) return;

    final wasLoggedIn = isLoggedIn;
    final nowLoggedIn = authStateNotifier.value;

    if (wasLoggedIn != nowLoggedIn) {
      if (!mounted) return;
      setState(() => isLoggedIn = nowLoggedIn);

      if (nowLoggedIn) {
        await handleLogin();
      } else {
        await handleLogout();
      }
    }
  }

  /// Handle login event.

  Future<void> handleLogin() async {
    if (!mounted) return;
    setState(() {
      if (viewportInitialized && mapController.camera.center != initialCenter) {
        initialCenter = mapController.camera.center;
        initialZoom = mapController.camera.zoom;
      }
    });
    await verifyLoginStateAndLoadData();
  }

  /// Handle logout event.

  Future<void> handleLogout() async {
    // Force refresh to ensure we don't use any stale cache after logout
    // This is critical for non-web platforms where SharedPreferences cleanup may be async.
    final places = await PlacesService.fetchPlaces(
      forceRefresh: true,
      includeEncrypted: false,
    );
    if (mounted) {
      setState(() {
        allPlaces = places;
      });
    }
  }

  /// Handle places changes from services.

  Future<void> onPlacesChanged() async {
    if (skipPlacesChangeNotification) {
      return;
    }

    if (mounted) {
      await loadAllPlaces();
    }
  }

  /// Load all places from services.

  Future<void> loadAllPlaces() async {
    final places = await PlacesService.fetchPlaces(
      forceRefresh: false,
      includeEncrypted: true,
    );

    if (mounted) {
      setState(() {
        allPlaces = places;
      });
    }
  }

  /// Verify login state and reload encrypted places if needed.

  Future<void> verifyLoginStateAndLoadData() async {
    if (!mounted || !isLoggedIn) return;

    if (isLoggedIn) {
      // Fetch encrypted places - this will reload from pod if needed.
      await EncryptedPlacesService.fetchEncryptedPlaces(forceRefresh: true);
      if (!mounted) return;
      await loadAllPlaces();
    }
  }
}
