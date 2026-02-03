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
import 'package:geopod/widgets/map/user_location_marker_layer.dart';

/// Builds the core FlutterMap widget with all layers.
///
/// Performance optimizations:
/// - Uses RepaintBoundary to isolate map repaints from overlay UI
/// - Defers marker layer updates when not animating.

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
  required LatLng initialCenter,
  required double initialZoom,
  required LatLng? userLocation,
  double? maxZoom,
}) {
  return RepaintBoundary(
    child: FadeTransition(
      opacity: fadeAnimation,
      child: FlutterMap(
        // Remove key to allow FlutterMap to properly handle tileProvider changes
        // The TileLayer's ObjectKey will handle proper recreation when needed.
        mapController: mapController,
        options: MapOptions(
          initialCenter: initialCenter,
          initialZoom: initialZoom,
          minZoom: 3.0,
          maxZoom: maxZoom ?? mapSettings.mapSource.maxNativeZoom.toDouble(),

          // Constrain latitude to ±85.11° (Web Mercator projection limits)
          // Longitude is unrestricted to allow horizontal map wrapping.
          cameraConstraint: const CameraConstraint.containLatitude(
            85.051129,
            -85.051129,
          ),
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

          // Wrap marker layer in RepaintBoundary to isolate marker animations.
          RepaintBoundary(
            child: buildPlacesMarkerLayer(
              context: context,
              markers: filteredMarkers,
              shouldAnimate: shouldAnimate,
              onDelete: onDeletePlace,
            ),
          ),
          if (showNewsMarkers)
            RepaintBoundary(
              child: buildNewsMarkerLayer(
                context: context,
                newsMarkers: visibleNewsMarkers,
              ),
            ),

          // User location marker layer (always on top)
          ...() {
            final userLocationLayer = buildUserLocationMarkerLayer(
              userLocation: userLocation,
            );
            if (userLocationLayer == null) return const <Widget>[];
            return [RepaintBoundary(child: userLocationLayer)];
          }(),
        ],
      ),
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
