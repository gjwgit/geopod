/// Data model for a map marker.
///
// Time-stamp: <2026-09-07 Amogh>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program.  If not, see <https://opensource.org/license/gpl-3-0>.
///
/// Authors: Graham Williams, Miduo, Amogh

library;

import 'package:flutter/material.dart';

import 'package:latlong2/latlong.dart';

import 'package:geopod/models/place.dart';
import 'package:geopod/services/map_settings_service.dart';
import 'package:geopod/services/media/media_pod_service.dart';

/// Data model for a map marker.

class MarkerData {
  final LatLng position;
  final String title;
  final String description;
  final String? address;

  /// Unique identifier for this place (needed for delete operation).
  final String id;

  /// Whether this marker is from local assets (canned examples).
  final bool isLocal;

  /// Whether this marker is currently being saved.
  final bool isSaving;

  /// Custom color for this marker (from settings).
  final Color color;

  /// Whether this marker is from encrypted storage.
  final bool isEncrypted;

  /// Optional date of interest (formatted) for display.
  final String? dateOfInterest;

  /// Tags on this place.
  final List<String> tags;

  /// Number of photos linked to this place.
  final int photoCount;

  /// Whether this place has at least one photo attached.
  final bool hasPhotos;

  MarkerData({
    required this.position,
    required this.title,
    required this.description,
    required this.id,
    this.address,
    this.isLocal = false,
    this.isSaving = false,
    this.color = Colors.blue,
    this.isEncrypted = false,
    this.dateOfInterest,
    this.tags = const [],
    this.photoCount = 0,
    bool? hasPhotos,
  }) : hasPhotos = hasPhotos ?? (photoCount > 0);

  String get coordinates =>
      '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
}

/// Converts places to filtered marker data based on settings.

List<MarkerData> buildFilteredMarkers({
  required List<Place> allPlaces,
  required MapSettings mapSettings,
  required Set<String> savingPlaceIds,
  Map<String, int> photoCounts = const {},
}) {
  // If hideAllMarkers is enabled, return empty list
  if (mapSettings.hideAllMarkers) return [];

  final visible = allPlaces.where((p) {
    // Filter out local places if disabled.
    if (p.isLocal && !mapSettings.showLocalPlaces) return false;
    return true;
  }).toList();

  return visible.map((p) {
    final count = photoCounts.containsKey(p.id)
        ? photoCounts[p.id]!
        : MediaPodService.getLinkedPhotoCountSync(p.id);
    final hasPhoto =
        count > 0 || (MediaPodService.hasLinkedPhotoSync(p.id) == true);
    return MarkerData(
      id: p.id,
      position: LatLng(p.lat, p.lng),
      title: p.displayTitle,
      description: p.note,
      address: p.address,
      isLocal: p.isLocal,
      isSaving: savingPlaceIds.contains(p.id),
      color: p.isLocal
          ? mapSettings.localPlacesColor
          : mapSettings.userPlacesColor,
      isEncrypted: p.isEncrypted,
      dateOfInterest: p.formattedDateOfInterest,
      tags: p.tags,
      photoCount: count,
      hasPhotos: hasPhoto,
    );
  }).toList();
}
