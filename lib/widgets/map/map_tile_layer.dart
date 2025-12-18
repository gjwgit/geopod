/// Map tile layer widget for GeoMap.
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

import 'package:geopod/services/map_settings_service.dart';

/// Midnight color matrix for dark mode.
const midnightMatrix = <double>[
  -0.33,
  -0.33,
  -0.33,
  0,
  255,
  -0.33,
  -0.33,
  -0.33,
  0,
  255,
  -0.33,
  -0.33,
  -0.33,
  0,
  255,
  0,
  0,
  0,
  1,
  0,
];

/// Builds the tile layer with optional dark mode filter.
Widget buildMapTileLayer({
  required MapSettings mapSettings,
  required TileProvider tileProvider,
  required bool applyFilter,
}) {
  return ColorFiltered(
    colorFilter: applyFilter
        ? const ColorFilter.matrix(midnightMatrix)
        : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
    child: TileLayer(
      key: ValueKey(mapSettings.mapSource),
      urlTemplate: mapSettings.mapSource.urlTemplate,
      subdomains: mapSettings.mapSource.subdomains,
      userAgentPackageName: 'com.togaware.geopod',
      tileProvider: tileProvider,
      evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
      keepBuffer: 5,
      panBuffer: 1,
      maxZoom: 19,
      maxNativeZoom: 18,
      tileSize: 256,
      retinaMode: false,
      errorImage: const AssetImage(
        'assets/images/tile_error.png',
        package: 'solidpod',
      ),
    ),
  );
}
