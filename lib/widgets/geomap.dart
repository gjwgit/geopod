/// The primary map widget.
///
// Time-stamp: <2025-12-04 Miduo>
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

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:geopod/services/places_service.dart';
import 'package:geopod/widgets/add_place_form.dart';

/// A map widget displaying points of interest with the ability to add new places.
///
/// Users can:
/// - Tap on the map to add a new place at that location
/// - Long press on the map as an alternative way to add a place
/// - Tap on markers to view details
/// - Use the FAB to add a place without coordinates
class GeoMap extends StatefulWidget {
  const GeoMap({super.key});

  @override
  State<GeoMap> createState() => _GeoMapState();
}

class _GeoMapState extends State<GeoMap> {
  final MapController _mapController = MapController();
  String? _selectedMarkerText;

  /// Places loaded from the Pod.
  List<Place> _podPlaces = [];

  /// Whether places are being loaded.
  bool _isLoadingPlaces = false;

  // Define your points of interest - Larrakia significant sites near Darwin
  final List<MarkerData> _defaultMarkers = [
    MarkerData(
      position: const LatLng(-12.4634, 130.8456), // Darwin city center
      title: 'Garramilla (Darwin)',
      description:
          'The traditional Larrakia name for Darwin, meaning "white stone"',
      isDefault: true,
    ),
    MarkerData(
      position: const LatLng(-12.4686, 130.8403),
      title: 'Stokes Hill',
      description:
          'A site where the Larrakia people believe the spiritual ancestor '
          '"Chinute Chinute" lives, manifesting as a tawny frogmouth.',
      isDefault: true,
    ),
    MarkerData(
      position: const LatLng(-12.4294, 130.8350),
      title: 'Mindil Beach',
      description:
          'One of several popular sites around Darwin that holds specific '
          'cultural meaning for the Larrakia people.',
      isDefault: true,
    ),
    MarkerData(
      position: const LatLng(-12.3771, 130.8765),
      title: 'Rapid Creek',
      description: 'An important Larrakia cultural site in Darwin.',
      isDefault: true,
    ),
    MarkerData(
      position: const LatLng(-12.3589, 130.8655),
      title: 'Casuarina Beach',
      description: 'Significant coastal site for Larrakia people',
      isDefault: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadPodPlaces();
  }

  /// Loads places from the user's Pod.
  Future<void> _loadPodPlaces() async {
    setState(() {
      _isLoadingPlaces = true;
    });

    try {
      final places = await PlacesService.fetchPlaces();
      if (mounted) {
        setState(() {
          _podPlaces = places;
          _isLoadingPlaces = false;
        });
      }
    } catch (e) {
      debugPrint('GeoMap: Error loading places: $e');
      if (mounted) {
        setState(() {
          _isLoadingPlaces = false;
        });
      }
    }
  }

  /// Returns all markers (default + from Pod).
  List<MarkerData> get _allMarkers {
    final podMarkers = _podPlaces.map(
      (place) => MarkerData(
        position: LatLng(place.lat, place.lng),
        title: place.displayTitle,
        description: place.note,
        isDefault: false,
      ),
    );
    return [..._defaultMarkers, ...podMarkers];
  }

  /// Shows the Add Place dialog with optional pre-filled coordinates.
  Future<void> _showAddPlaceDialog({
    double? latitude,
    double? longitude,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddPlaceForm(
        initialLatitude: latitude,
        initialLongitude: longitude,
        returnWidget: const GeoMap(),
      ),
    );

    // If a place was saved successfully, refresh markers.
    if (result == true) {
      _loadPodPlaces();
    }
  }

  /// Shows options when user taps on the map.
  void _onMapTap(TapPosition tapPosition, LatLng latLng) {
    // First, dismiss any selected marker popup.
    if (_selectedMarkerText != null) {
      setState(() {
        _selectedMarkerText = null;
      });
      return;
    }

    // Show a quick dialog to add place at tapped location.
    _showAddPlaceDialog(
      latitude: latLng.latitude,
      longitude: latLng.longitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(-12.4634, 130.8456), // Darwin
              initialZoom: 12.0,
              minZoom: 3.0,
              maxZoom: 18.0,
              // Tap to add a new place.
              onTap: _onMapTap,
              // Long press as alternative.
              onLongPress: (tapPosition, latLng) {
                _showAddPlaceDialog(
                  latitude: latLng.latitude,
                  longitude: latLng.longitude,
                );
              },
            ),
            children: [
              // OpenStreetMap tile layer
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.togaware.geopod',
              ),
              // Marker layer
              MarkerLayer(
                markers: _allMarkers.map((markerData) {
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
                      child: Icon(
                        Icons.location_on,
                        size: 40,
                        // Default markers are red, user's markers are green.
                        color: markerData.isDefault ? Colors.red : Colors.green,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          // Loading indicator for places.
          if (_isLoadingPlaces)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Loading places...'),
                  ],
                ),
              ),
            ),
          // Hint for tap interaction.
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Tap map to add place',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          // Popup for selected marker
          if (_selectedMarkerText != null)
            Positioned(
              bottom: 80,
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
          // Refresh button
          FloatingActionButton.small(
            heroTag: 'refresh',
            onPressed: _loadPodPlaces,
            tooltip: 'Refresh Places',
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            child: const Icon(Icons.refresh),
          ),
          const SizedBox(height: 8),
          // Add place button
          FloatingActionButton(
            heroTag: 'add',
            onPressed: () => _showAddPlaceDialog(),
            tooltip: 'Add Place',
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add_location),
          ),
        ],
      ),
    );
  }
}

/// Data model for a map marker.
class MarkerData {
  final LatLng position;
  final String title;
  final String description;
  final bool isDefault;

  MarkerData({
    required this.position,
    required this.title,
    required this.description,
    this.isDefault = false,
  });
}
