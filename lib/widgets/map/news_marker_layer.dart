/// News marker layer widget for GeoMap.
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

import 'package:geopod/services/gdelt_news_service.dart';
import 'package:geopod/widgets/map/news_marker_details_sheet.dart';

/// Builds a marker layer for news markers.

MarkerLayer buildNewsMarkerLayer({
  required BuildContext context,
  required List<NewsMarker> newsMarkers,
}) {
  return MarkerLayer(
    markers: newsMarkers
        .map(
          (n) => Marker(
            point: n.location,
            width: 36,
            height: 36,
            child: GestureDetector(
              onTap: () => showNewsMarkerDetailsSheet(context, n),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.article, size: 20, color: Colors.white),
              ),
            ),
          ),
        )
        .toList(),
  );
}
