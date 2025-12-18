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
    markers: markers.asMap().entries.map((e) {
      final i = e.key;
      final m = e.value;
      return Marker(
        point: m.position,
        width: 40,
        height: 40,
        child: MarkerWithAnimation(
          index: i,
          shouldAnimate: shouldAnimate,
          child: GestureDetector(
            onTap: () =>
                showMarkerDetailsSheet(context, m, onDelete: () => onDelete(m)),
            child: m.isSaving
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 40,
                        color: Colors.orange.shade400,
                      ),
                      const Positioned(
                        top: 8,
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  )
                : Icon(Icons.location_on, size: 40, color: m.color),
          ),
        ),
      );
    }).toList(),
  );
}
