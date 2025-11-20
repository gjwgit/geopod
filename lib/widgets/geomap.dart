/// THe primary map widget.
///
// Time-stamp: <Friday 2025-11-21 08:37:45 +1100 Graham Williams>
///
/// Copyright (C) 2025, Software Innovation Institute ANU
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://opensource.org/license/gpl-3-0
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
/// Authors: Graham Williams

// Add the library directive as we have doc entries above. We publish the above
// meta doc lines in the docs.

library;

import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class GeoMap extends StatefulWidget {
  const GeoMap({super.key});

  @override
  State<GeoMap> createState() => _GeoMapState();
}

class _GeoMapState extends State<GeoMap> {
  final MapController _mapController = MapController();
  String? _selectedMarkerText;

  // Define your points of interest - Larrakia significant sites near Darwin
  final List<MarkerData> _markers = [
    MarkerData(
      position: const LatLng(-12.4634, 130.8456), // Darwin city center
      title: 'Garramilla (Darwin)',
      description:
          'The traditional Larrakia name for Darwin, meaning "white stone"',
    ),
    MarkerData(
      position: const LatLng(-12.4686, 130.8403),
      title: 'Stokes Hill',
      description:
          'A site where the Larrakia people believe the spiritual ancestor "Chinute Chinute" lives, manifesting as a tawny frogmouth.',
    ),
    MarkerData(
      position: const LatLng(-12.4294, 130.8350),
      title: 'Mindil Beach',
      description:
          'One of several popular sites around Darwin that holds specific cultural meaning for the Larrakia people.',
    ),
    MarkerData(
      position: const LatLng(-12.3771, 130.8765),
      title: 'Rapid Creek',
      description: 'An important Larrakia cultural site in Darwin.',
    ),
    MarkerData(
      position: const LatLng(-12.3589, 130.8655),
      title: 'Casuarina Beach',
      description: 'Significant coastal site for Larrakia people',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GeoPod'), elevation: 2),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(-12.4634, 130.8456), // Darwin
              initialZoom: 12.0,
              minZoom: 3.0,
              maxZoom: 18.0,
              onTap: (_, _) {
                setState(() {
                  _selectedMarkerText = null;
                });
              },
            ),
            children: [
              // OpenStreetMap tile layer
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/'
                    '{z}/{x}/{y}.png',
                userAgentPackageName: 'com.togaware.geopod',
              ),
              // Marker layer
              MarkerLayer(
                markers: _markers.map((markerData) {
                  return Marker(
                    point: markerData.position,
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMarkerText =
                              '${markerData.title}\n${markerData.description}';
                        });
                      },
                      child: const Icon(
                        Icons.location_on,
                        size: 40,
                        color: Colors.red,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          // Popup for selected marker
          if (_selectedMarkerText != null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Card(
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedMarkerText!,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _selectedMarkerText = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'zoom_in',
            mini: true,
            child: const Icon(Icons.add),
            onPressed: () {
              _mapController.move(
                _mapController.camera.center,
                _mapController.camera.zoom + 1,
              );
            },
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'zoom_out',
            mini: true,
            child: const Icon(Icons.remove),
            onPressed: () {
              _mapController.move(
                _mapController.camera.center,
                _mapController.camera.zoom - 1,
              );
            },
          ),
        ],
      ),
    );
  }
}

class MarkerData {
  final LatLng position;
  final String title;
  final String description;

  MarkerData({
    required this.position,
    required this.title,
    required this.description,
  });
}
