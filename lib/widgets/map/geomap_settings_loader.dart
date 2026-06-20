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

import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:geopod/services/map_settings_service.dart';
import 'package:geopod/utils/widget_utils.dart';
import 'package:geopod/widgets/map/geomap_settings.dart';

/// Handles settings loading and viewport restoration for GeoMap.

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

  /// Load settings synchronously with viewport restoration.
  ///
  /// [onComplete] is called after the viewport has been restored so it can
  /// safely override the view.

  void loadSettingsSync({VoidCallback? onComplete}) {
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

          if (result.initialCenter != null) {
            mapController.move(result.initialCenter!, result.initialZoom!);
          }

          onComplete?.call();
        })
        .catchError((_) {});
  }
}
