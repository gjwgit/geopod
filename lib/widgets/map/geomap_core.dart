/// Core map widget builder for GeoMapWidget.
///
// Time-stamp: <Wednesday 2025-12-18 08:22:27 +1100 Graham Williams>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:geopod/services/gdelt_news_service.dart';
import 'package:geopod/services/map_settings_service.dart';
import 'package:geopod/widgets/map/map_tile_layer.dart';
import 'package:geopod/widgets/map/marker_data.dart';
import 'package:geopod/widgets/map/news_marker_layer.dart';
import 'package:geopod/widgets/map/places_marker_layer.dart';

/// Builds the core FlutterMap widget with all layers.
Widget buildFlutterMapWidget({
  required MapController mapController,
  required Animation<double> fadeAnimation,
  required MapSettings mapSettings,
  required TileProvider tileProvider,
  required bool applyFilter,
  required List<MarkerData> filteredMarkers,
  required bool shouldAnimate,
  required bool showNewsMarkers,
  required List<NewsMarker> visibleNewsMarkers,
  required void Function(TapPosition, LatLng) onTap,
  required void Function(TapPosition, LatLng) onLongPress,
  required void Function(MapCamera, bool) onPositionChanged,
  required void Function(MarkerData) onDeletePlace,
  required BuildContext context,
}) {
  return FadeTransition(
    opacity: fadeAnimation,
    child: FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: const LatLng(-12.46, 130.84),
        initialZoom: 13.0,
        minZoom: 3.0,
        maxZoom: 18.0,
        onTap: onTap,
        onLongPress: onLongPress,
        onPositionChanged: onPositionChanged,
      ),
      children: [
        buildMapTileLayer(
          mapSettings: mapSettings,
          tileProvider: tileProvider,
          applyFilter: applyFilter,
        ),
        buildPlacesMarkerLayer(
          context: context,
          markers: filteredMarkers,
          shouldAnimate: shouldAnimate,
          onDelete: onDeletePlace,
        ),
        if (showNewsMarkers)
          buildNewsMarkerLayer(
            context: context,
            newsMarkers: visibleNewsMarkers,
          ),
      ],
    ),
  );
}

/// Builds the loading indicator overlay.
Widget buildLoadingIndicator({required bool isLoading}) {
  if (!isLoading) return const SizedBox.shrink();
  return const Positioned(
    top: 0,
    left: 0,
    right: 0,
    child: LinearProgressIndicator(
      backgroundColor: Colors.transparent,
      color: Colors.green,
    ),
  );
}
