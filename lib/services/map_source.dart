/// Map tile source definitions and extensions.
///
// Time-stamp: <2026-01-02 Miduo>
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
/// Authors: Graham Williams, Miduo

library;

import 'package:flutter/material.dart';

/// Available map tile sources.

enum MapSource {
  /// OpenStreetMap - Standard street map (day default)
  openStreetMap,

  /// CartoDB Voyager - Colorful detailed map.
  cartoVoyager,

  /// CartoDB Dark Matter - Night-optimized dark map.
  cartoDarkMatter,

  /// CartoDB Positron - Light grayscale map.
  cartoPositron,

  /// Esri World Street Map - Professional street map.
  esriWorldStreetMap,

  /// Esri World Imagery - Satellite imagery.
  esriWorldImagery,

  /// Esri World Topo - Topographic map.
  esriWorldTopo,

  /// OpenTopoMap - Free topographic map.
  openTopoMap,

  /// CyclOSM - Optimized for cycling.
  cyclOSM,
}

/// Extension for MapSource to get tile URLs and metadata.

extension MapSourceExtension on MapSource {
  /// Returns the tile URL template for this map source.
  String get urlTemplate {
    switch (this) {
      case MapSource.openStreetMap:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case MapSource.cartoVoyager:
        return 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
      case MapSource.cartoDarkMatter:
        return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';
      case MapSource.cartoPositron:
        return 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';
      case MapSource.esriWorldStreetMap:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}';
      case MapSource.esriWorldImagery:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case MapSource.esriWorldTopo:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}';
      case MapSource.openTopoMap:
        return 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
      case MapSource.cyclOSM:
        return 'https://{s}.tile-cyclosm.openstreetmap.fr/cyclosm/{z}/{x}/{y}.png';
    }
  }

  /// Returns subdomains if applicable (for load balancing).

  List<String> get subdomains {
    switch (this) {
      case MapSource.cartoVoyager:
      case MapSource.cartoDarkMatter:
      case MapSource.cartoPositron:
        return ['a', 'b', 'c', 'd'];
      case MapSource.openTopoMap:
      case MapSource.cyclOSM:
        return ['a', 'b', 'c'];
      default:
        return [];
    }
  }

  /// Display name.

  String get displayName {
    switch (this) {
      case MapSource.openStreetMap:
        return 'OpenStreetMap';
      case MapSource.cartoVoyager:
        return 'CartoDB Voyager';
      case MapSource.cartoDarkMatter:
        return 'CartoDB Dark Matter';
      case MapSource.cartoPositron:
        return 'CartoDB Positron';
      case MapSource.esriWorldStreetMap:
        return 'Esri Street Map';
      case MapSource.esriWorldImagery:
        return 'Esri Satellite';
      case MapSource.esriWorldTopo:
        return 'Esri Topographic';
      case MapSource.openTopoMap:
        return 'OpenTopoMap';
      case MapSource.cyclOSM:
        return 'CyclOSM';
    }
  }

  /// Short description.

  String get description {
    switch (this) {
      case MapSource.openStreetMap:
        return 'Classic open source map';
      case MapSource.cartoVoyager:
        return 'Colorful and detailed';
      case MapSource.cartoDarkMatter:
        return 'Night-optimized dark theme';
      case MapSource.cartoPositron:
        return 'Light grayscale design';
      case MapSource.esriWorldStreetMap:
        return 'Professional street map';
      case MapSource.esriWorldImagery:
        return 'High-resolution satellite';
      case MapSource.esriWorldTopo:
        return 'Topographic with contours';
      case MapSource.openTopoMap:
        return 'Free topographic map';
      case MapSource.cyclOSM:
        return 'Optimized for cycling';
    }
  }

  /// Icon for this map source.

  IconData get icon {
    switch (this) {
      case MapSource.openStreetMap:
      case MapSource.cartoVoyager:
      case MapSource.esriWorldStreetMap:
      case MapSource.cyclOSM:
      case MapSource.cartoPositron:
        return Icons.map;
      case MapSource.cartoDarkMatter:
        return Icons.dark_mode;
      case MapSource.esriWorldImagery:
        return Icons.satellite_alt;
      case MapSource.esriWorldTopo:
      case MapSource.openTopoMap:
        return Icons.terrain;
    }
  }

  /// Whether this is a priority source (preload on startup).

  bool get isPriority {
    return this == MapSource.openStreetMap || this == MapSource.cartoDarkMatter;
  }

  /// Whether this is a dark/night-optimized map source.
  /// Dark sources don't need color matrix filter in dark mode.

  bool get isDarkSource {
    return this == MapSource.cartoDarkMatter;
  }

  /// Returns the maximum native zoom level for this map source.
  /// Beyond this level, tiles are upscaled from the max available.

  int get maxNativeZoom {
    switch (this) {
      case MapSource.openStreetMap:
        return 19;
      case MapSource.cartoVoyager:
      case MapSource.cartoDarkMatter:
      case MapSource.cartoPositron:
        return 20;
      case MapSource.esriWorldStreetMap:
        return 19;
      case MapSource.esriWorldImagery:
        return 17; // Esri satellite max native zoom is 17
      case MapSource.esriWorldTopo:
        return 18;
      case MapSource.openTopoMap:
        return 17; // OpenTopoMap max zoom is 17
      case MapSource.cyclOSM:
        return 18;
    }
  }
}
