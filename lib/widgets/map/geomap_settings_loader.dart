/// Settings loading and validation for GeoMap.
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
import 'package:latlong2/latlong.dart';

import 'package:geopod/models/place.dart';
import 'package:geopod/services/map_settings_service.dart';
import 'package:geopod/utils/widget_utils.dart';
import 'package:geopod/widgets/map/geomap_settings.dart';

/// Handles settings loading and validation.

mixin GeoMapSettingsLoader<T extends StatefulWidget> on State<T> {
  MapController get mapController;
  MapSettings get mapSettings;
  set mapSettings(MapSettings value);
  LatLng get initialCenter;
  set initialCenter(LatLng value);
  double get initialZoom;
  set initialZoom(double value);
  bool get viewportInitialized;
  set viewportInitialized(bool value);
  bool get isLoggedIn;
  List<Place> get allPlaces;

  /// Load settings synchronously with viewport restoration.

  void loadSettingsSync(VoidCallback onLoadEncrypted) {
    loadMapSettingsSync(viewportInitialized: viewportInitialized)
        .then((result) {
          if (!mounted) return;

          safeSetState(this, () {
            mapSettings = result.settings;
            if (result.initialCenter != null) {
              initialCenter = result.initialCenter!;
              initialZoom = result.initialZoom!;
              viewportInitialized = result.viewportInitialized;
            }
          });

          // Move map after state update if viewport was loaded.

          if (result.initialCenter != null) {
            mapController.move(result.initialCenter!, result.initialZoom!);
          }

          // Validate encrypted setting if enabled.

          if (result.settings.showEncryptedPlaces) {
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) {
                validateSavedEncryptedSettingAndLoad(onLoadEncrypted);
              }
            });
          }
        })
        .catchError((_) {});
  }

  /// Validate saved encrypted setting and load if valid.

  Future<void> validateSavedEncryptedSettingAndLoad(
    VoidCallback onLoadEncrypted,
  ) async {
    final shouldLoad = await validateSavedEncryptedSetting(
      mapSettings: mapSettings,
      isLoggedIn: isLoggedIn,
      allPlaces: allPlaces,
    );

    if (!shouldLoad) {
      // Reset setting if validation failed.
      if (!isLoggedIn) {
        safeSetState(this, () {
          mapSettings = mapSettings.copyWith(showEncryptedPlaces: false);
        });
      }
      return;
    }

    // Load encrypted places, then reset the in-progress guard.

    onLoadEncrypted();
    // Allow a new load after 5 s to handle race conditions during initial auth.
    Future.delayed(const Duration(seconds: 5), encryptedLoadInProgressReset);
  }
}
