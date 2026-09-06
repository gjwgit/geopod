/// Data model for an externally owned place shared with the user.
///
// Time-stamp: <2026-09-07 Amogh>
///
/// Copyright (C) 2025-2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:geopod/models/place.dart';

/// Data model for an externally owned place shared with the user.

class ExternalPlace {
  /// The deserialized place data, populated after fetching the remote file.
  Place? content;

  /// ISO-8601 timestamp when the permission was granted.
  final String sharedTime;

  /// Full URL of the remote place file.
  final String placeUrl;

  /// Filename component (e.g. `place_<uuid>.json` or `enc_place_<uuid>.ttl`).
  final String placeFileName;

  /// WebID of the Pod owner of the place.
  final String placeOwner;

  /// WebID of the user who granted the permission.
  final String permissionGranter;

  /// WebID of the user who received the permission.
  final String permissionRecepient;

  /// Permission type string (e.g. `grant` or `revoke`).
  final String permissionType;

  /// Comma-separated list of access modes (e.g. `read,write`).
  final String permissionList;

  ExternalPlace({
    this.content,
    required this.sharedTime,
    required this.placeUrl,
    required this.placeFileName,
    required this.placeOwner,
    required this.permissionGranter,
    required this.permissionRecepient,
    required this.permissionType,
    required this.permissionList,
  });

  /// Returns a copy with the [content] field replaced.
  ExternalPlace withContent(Place? newContent) => ExternalPlace(
    content: newContent,
    sharedTime: sharedTime,
    placeUrl: placeUrl,
    placeFileName: placeFileName,
    placeOwner: placeOwner,
    permissionGranter: permissionGranter,
    permissionRecepient: permissionRecepient,
    permissionType: permissionType,
    permissionList: permissionList,
  );

  /// Returns a copy promoted to a [FoundExternalPlace].
  FoundExternalPlace toFound({bool isSelected = false}) => FoundExternalPlace(
    content: content,
    sharedTime: sharedTime,
    placeUrl: placeUrl,
    placeFileName: placeFileName,
    placeOwner: placeOwner,
    permissionGranter: permissionGranter,
    permissionRecepient: permissionRecepient,
    permissionType: permissionType,
    permissionList: permissionList,
    isSelected: isSelected,
  );
}

/// An [ExternalPlace] that carries an additional [isSelected] flag,
/// used by list widgets for multi-selection UI.

class FoundExternalPlace extends ExternalPlace {
  bool isSelected;

  FoundExternalPlace({
    required super.sharedTime,
    required super.placeUrl,
    required super.placeFileName,
    required super.placeOwner,
    required super.permissionGranter,
    required super.permissionRecepient,
    required super.permissionType,
    required super.permissionList,
    super.content,
    this.isSelected = false,
  });
}

/// Extension to convert a list of [ExternalPlace] to [FoundExternalPlace].

extension ExternalPlaceListExtension on List<ExternalPlace> {
  List<FoundExternalPlace> toListFoundExternalPlace() =>
      map((p) => p.toFound()).toList();
}
