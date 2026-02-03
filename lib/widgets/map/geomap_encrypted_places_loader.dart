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

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:geopod/models/place.dart';
import 'package:geopod/services/map_settings_service.dart';
import 'package:geopod/utils/widget_utils.dart';
import 'package:geopod/widgets/map/geomap_places_loader.dart';

/// Handles encrypted places loading.

mixin GeoMapEncryptedPlacesLoader<T extends StatefulWidget> on State<T> {
  bool get isLoggedIn;
  MapSettings get mapSettings;
  set mapSettings(MapSettings value);
  List<Place> get allPlaces;
  set allPlaces(List<Place> value);

  /// Load all places including encrypted if enabled.

  Future<void> loadAllPlaces({
    bool forceRefresh = false,
    bool? includeEncrypted,
  }) async {
    final result = await loadPlacesWithState(
      currentPlaces: allPlaces,
      forceRefresh: forceRefresh,
      includeEncrypted: includeEncrypted ?? mapSettings.showEncryptedPlaces,
    );

    if (!mounted) return;

    if (result.showLoading) {
      safeSetState(this, () {});
    }

    if (result.hasChanges) {
      safeSetState(this, () {
        allPlaces = List.from(result.places);
      });
    }
  }

  /// Load encrypted places with optional key verification.

  Future<void> loadEncryptedPlaces({bool skipKeyVerification = false}) async {
    if (!isLoggedIn || !mounted) return;

    final result = await loadEncryptedPlacesData(
      context: context,
      widget: widget,
      isLoggedIn: isLoggedIn,
      skipKeyVerification: skipKeyVerification,
    );

    if (result.cancelled && mounted) {
      safeSetState(this, () {
        mapSettings = mapSettings.copyWith(showEncryptedPlaces: false);
      });
      MapSettingsService.saveSettings(mapSettings);
      return;
    }

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
