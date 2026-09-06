/// Result model for external places future call.
///
// Time-stamp: <2026-09-07 Amogh>
///
/// Copyright (C) 2025-2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:geopod/models/external_place.dart';

/// Return value of [getExternalPlaceList].
///
/// - [places] - successfully loaded external places.
/// - [nonExistentPlaces] - places where access is still logged but the
///   remote file has already been deleted by its owner.
/// - [forbiddenPlaces] - places the current user has no permission to read.
/// - [encryptionErrorPlaces] - encrypted places whose decryption key is
///   unavailable or whose security key was not yet ready.
/// - [unparseablePlaces] - places whose file content could not be parsed.

class ExternalPlacesCallResult {
  final List<ExternalPlace>? places;
  final List<ExternalPlace>? nonExistentPlaces;
  final List<ExternalPlace>? forbiddenPlaces;
  final List<ExternalPlace>? encryptionErrorPlaces;
  final List<ExternalPlace>? unparseablePlaces;

  const ExternalPlacesCallResult({
    this.places = const [],
    this.nonExistentPlaces = const [],
    this.forbiddenPlaces = const [],
    this.encryptionErrorPlaces = const [],
    this.unparseablePlaces = const [],
  });
}
