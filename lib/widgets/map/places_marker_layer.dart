/// Places marker layer widget for GeoMap.
///
// Time-stamp: <2025-12-18 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';

import 'package:geopod/widgets/map/marker_data.dart';
import 'package:geopod/widgets/map/marker_details_sheet.dart';
import 'package:geopod/widgets/map/marker_with_animation.dart';

/// Builds a marker layer for places.
MarkerLayer buildPlacesMarkerLayer({
  required BuildContext context,
  required List<MarkerData> markers,
  required bool shouldAnimate,
  required void Function(MarkerData) onDelete,
}) {
  return MarkerLayer(
    markers: [
      for (int i = 0; i < markers.length; i++)
        _buildMarker(
          context: context,
          marker: markers[i],
          index: i,
          shouldAnimate: shouldAnimate,
          onDelete: onDelete,
        ),
    ],
  );
}

/// Builds a single marker widget.
Marker _buildMarker({
  required BuildContext context,
  required MarkerData marker,
  required int index,
  required bool shouldAnimate,
  required void Function(MarkerData) onDelete,
}) {
  // Skip entrance animation for markers being saved (they have their own indicator)
  final animate = shouldAnimate && !marker.isSaving;
  
  return Marker(
    key: ValueKey('marker_${marker.id}'),
    point: marker.position,
    width: 40,
    height: 40,
    child: MarkerWithAnimation(
      key: ValueKey('anim_${marker.id}'),
      index: index,
      shouldAnimate: animate,
      child: GestureDetector(
        onTap: () => showMarkerDetailsSheet(
          context,
          marker,
          onDelete: () => onDelete(marker),
        ),
        child: marker.isSaving
            ? _buildSavingMarker()
            : Icon(Icons.location_on, size: 40, color: marker.color),
      ),
    ),
  );
}

/// Builds the saving state marker with lightweight pulse indicator.
Widget _buildSavingMarker() {
  return Stack(
    alignment: Alignment.center,
    children: [
      Icon(Icons.location_on, size: 40, color: Colors.orange.shade400),
      // Use a simple static indicator instead of animated spinner
      // This avoids animation overhead during save
      const Positioned(
        top: 6,
        child: Icon(
          Icons.cloud_upload_outlined,
          size: 14,
          color: Colors.white,
        ),
      ),
    ],
  );
}
