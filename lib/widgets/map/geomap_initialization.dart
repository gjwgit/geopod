/// Initialization and lifecycle management for GeoMap.
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

/// Initializes animation controller and listeners for map widget.
void initializeMapState({
  required AnimationController animationController,
  required Animation<double> fadeAnimation,
  required VoidCallback onAnimationComplete,
  required VoidCallback onAuthStateChanged,
  required VoidCallback onPlacesChanged,
  required ValueNotifier<bool> authStateNotifier,
  required ValueNotifier<void> placesChangeNotifier,
}) {
  animationController.addStatusListener((status) {
    if (status == AnimationStatus.completed) {
      onAnimationComplete();
    }
  });

  authStateNotifier.addListener(onAuthStateChanged);
  placesChangeNotifier.addListener(onPlacesChanged);
}

/// Initializes map widget after first frame.
void initializeMapPostFrame({
  required BuildContext context,
  required AnimationController animationController,
  required VoidCallback loadSettingsSync,
  required VoidCallback verifyLoginStateAndLoadData,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;

    animationController.forward();

    // Defer settings loading slightly to not block animation
    Future.microtask(() {
      if (context.mounted) loadSettingsSync();
    });

    // Defer login verification even more
    Future.delayed(const Duration(milliseconds: 50), () {
      if (context.mounted) verifyLoginStateAndLoadData();
    });
  });
}

/// Handles app lifecycle changes for map widget.
void handleMapLifecycleChange({
  required AppLifecycleState state,
  required VoidCallback onResume,
  required VoidCallback onPauseOrInactive,
}) {
  if (state == AppLifecycleState.resumed) {
    onResume();
  } else if (state == AppLifecycleState.paused ||
      state == AppLifecycleState.inactive) {
    onPauseOrInactive();
  }
}

/// Creates tile provider for map tiles.
TileProvider createTileProvider() {
  return CancellableNetworkTileProvider();
}
