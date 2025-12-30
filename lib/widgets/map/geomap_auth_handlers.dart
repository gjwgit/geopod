/// Authentication handlers for GeoMapWidget.
///
// Time-stamp: <Wednesday 2025-12-31 08:22:27 +1100 Graham Williams>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.
///
/// Authors: Graham Williams, Miduo

library;

import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';

import 'package:geopod/models/place.dart';
import 'package:geopod/services/map_settings_service.dart';
import 'package:geopod/widgets/map/geomap_state_logic.dart';

/// Mixin that provides authentication-related functionality for GeoMapWidget.
mixin GeoMapAuthMixin<T extends StatefulWidget> on State<T> {
  /// Override these in the main state class
  bool get isLoggedIn;
  set isLoggedIn(bool value);
  List<Place> get allPlaces;
  set allPlaces(List<Place> value);
  bool get isPostLoginRefresh;
  set isPostLoginRefresh(bool value);
  bool get initialAnimationComplete;
  set initialAnimationComplete(bool value);

  /// Handles login event.
  Future<void> handleLogin() async {
    if (!mounted) return;
    isPostLoginRefresh = true;
    initialAnimationComplete = false;
    setState(() => isLoggedIn = true);
    final places = await handleLoginStateChange(
      wasLoggedIn: false,
      isNowLoggedIn: true,
    );
    if (mounted) setState(() => allPlaces = places);
  }

  /// Handles logout event.
  Future<void> handleLogout() async {
    final places = await handleLoginStateChange(
      wasLoggedIn: true,
      isNowLoggedIn: false,
    );
    if (!mounted) return;
    isPostLoginRefresh = false;
    initialAnimationComplete = false;
    setState(() {
      isLoggedIn = false;
      allPlaces = places;
    });
  }
}

/// Mixin that provides lifecycle-related functionality for GeoMapWidget.
mixin GeoMapLifecycleMixin<T extends StatefulWidget> on State<T> {
  /// Override these in the main state class
  TileProvider get tileProvider;
  set tileProvider(TileProvider value);
  MapSettings get mapSettings;
  MapController get mapController;

  /// Saves current viewport position to persistent storage.
  void saveViewportOnPause() {
    if (mapSettings.rememberViewport) {
      final center = mapController.camera.center;
      final zoom = mapController.camera.zoom;
      MapSettingsService.saveLastViewport(
        lat: center.latitude,
        lng: center.longitude,
        zoom: zoom,
      );
    }
  }

  /// Handles app lifecycle state changes.
  void handleLifecycleChange(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => tileProvider = CancellableNetworkTileProvider());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      saveViewportOnPause();
    }
  }
}

/// Handles settings loading and viewport initialization.
Future<void> loadSettingsAndViewport({
  required bool mounted,
  required bool viewportInitialized,
  required MapController mapController,
  required void Function(MapSettings) setSettings,
  required void Function(LatLng center, double zoom) setViewport,
  required void Function() markViewportInitialized,
}) async {
  final settings = await MapSettingsService.loadSettings();
  if (!mounted) return;
  setSettings(settings);

  if (!viewportInitialized) {
    final viewport = await MapSettingsService.getStartupViewport(settings);
    if (!mounted) return;
    setViewport(LatLng(viewport.lat, viewport.lng), viewport.zoom);
    markViewportInitialized();
    mapController.move(LatLng(viewport.lat, viewport.lng), viewport.zoom);
  }
}
