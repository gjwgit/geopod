/// Encrypted places management for GeoMap.
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

import 'package:geopod/models/place.dart';
import 'package:geopod/services/map_settings_service.dart';
import 'package:geopod/utils/widget_utils.dart';
import 'package:geopod/widgets/map/geomap_places_loader.dart';

/// Handles places loading for GeoMap. All places are stored encrypted.

mixin GeoMapEncryptedPlacesLoader<T extends StatefulWidget> on State<T> {
  bool get isLoggedIn;
  MapSettings get mapSettings;
  List<Place> get allPlaces;
  set allPlaces(List<Place> value);

  /// Load all places (always including encrypted).

  Future<void> loadAllPlaces({
    bool forceRefresh = false,
    bool? includeEncrypted,
  }) async {
    final result = await loadPlacesWithState(
      currentPlaces: allPlaces,
      forceRefresh: forceRefresh,
      includeEncrypted: includeEncrypted ?? true,
    );

    if (!mounted) return;

    if (result.showLoading) safeSetState(this, () {});

    if (result.hasChanges) {
      safeSetState(this, () {
        allPlaces = List.from(result.places);
      });
    }
  }

  /// Load encrypted places (called on login / forced refresh).

  Future<void> loadEncryptedPlaces({bool skipKeyVerification = false}) async {
    if (!isLoggedIn || !mounted) return;

    final result = await loadEncryptedPlacesData(
      context: context,
      widget: widget,
      isLoggedIn: isLoggedIn,
      skipKeyVerification: skipKeyVerification,
    );

    if (mounted && result.encryptedPlaces.isNotEmpty) {
      safeSetState(this, () {
        allPlaces = mergeEncryptedPlaces(
          allPlaces: allPlaces,
          encryptedPlaces: result.encryptedPlaces,
        );
      });
    }
  }
}
