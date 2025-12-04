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

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';

import 'package:geopod/services/geocoding_service.dart';
import 'package:geopod/services/places_service.dart';
import 'package:geopod/widgets/add_place_form.dart';

/// A map widget displaying points of interest with the ability to add new places.
///
/// Features:
/// - Optimistic updates: Places appear instantly before save completes
/// - Background saving: Geocoding + writePod happens without blocking UI
/// - Pre-loaded data: Places are fetched once and cached for instant access
class GeoMap extends StatefulWidget {
  const GeoMap({super.key});

  @override
  State<GeoMap> createState() => _GeoMapState();
}

class _GeoMapState extends State<GeoMap> {
  final MapController _mapController = MapController();

  /// Places loaded from the Pod (cached in memory for instant access).
  List<Place> _podPlaces = [];

  /// IDs of places currently being saved in background.
  final Set<String> _savingPlaceIds = {};

  /// Whether initial load is in progress.
  bool _isLoadingPlaces = false;

  /// Default markers for notable locations in Canberra.
  final List<MarkerData> _defaultMarkers = [
    MarkerData(
      position: const LatLng(-35.2809, 149.1300),
      title: 'Parliament House',
      description:
          'The meeting place of the Parliament of Australia, opened in 1988.',
      isDefault: true,
    ),
    MarkerData(
      position: const LatLng(-35.2835, 149.1245),
      title: 'Old Parliament House',
      description:
          'The former seat of Australian government from 1927 to 1988, '
          'now home to the Museum of Australian Democracy.',
      isDefault: true,
    ),
    MarkerData(
      position: const LatLng(-35.3016, 149.1245),
      title: 'Australian National University',
      description:
          'Australia\'s national research university, '
          'consistently ranked among the world\'s best.',
      isDefault: true,
    ),
    MarkerData(
      position: const LatLng(-35.2920, 149.1410),
      title: 'National Gallery of Australia',
      description:
          'Australia\'s national art museum, housing over 166,000 works of art.',
      isDefault: true,
    ),
    MarkerData(
      position: const LatLng(-35.2955, 149.1501),
      title: 'Lake Burley Griffin',
      description:
          'An artificial lake in the centre of Canberra, '
          'created in 1963 as part of Walter Burley Griffin\'s design.',
      isDefault: true,
    ),
  ];

  @override
  void initState() {
    super.initState();

    // Pre-load data after first frame for instant sidebar access.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPodPlaces();
    });
  }

  /// Loads places from the user's Pod (called once, cached).
  Future<void> _loadPodPlaces() async {
    setState(() => _isLoadingPlaces = true);

    try {
      final places = await PlacesService.fetchPlaces();

      if (mounted) {
        setState(() {
          _podPlaces = places;
          _isLoadingPlaces = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingPlaces = false);
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
        address: place.address,
        isDefault: false,
        isSaving: _savingPlaceIds.contains(place.id),
      ),
    );
    return [..._defaultMarkers, ...podMarkers];
  }

  /// Shows the Add Place dialog with optional pre-filled coordinates.
  Future<void> _showAddPlaceDialog({
    double? latitude,
    double? longitude,
  }) async {
    final result = await showDialog<AddPlaceResult>(
      context: context,
      builder: (context) => AddPlaceForm(
        initialLatitude: latitude,
        initialLongitude: longitude,
        returnWidget: const GeoMap(),
      ),
    );

    if (result != null && mounted) {
      _handleOptimisticSave(result.place);
    }
  }

  /// Handles optimistic update and background save.
  void _handleOptimisticSave(Place optimisticPlace) {
    // Add to local list immediately.
    setState(() {
      _podPlaces.insert(0, optimisticPlace);
      _savingPlaceIds.add(optimisticPlace.id);
    });

    // Show feedback snackbar.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Saving "${optimisticPlace.displayTitle}"...'),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );

    // Fire background task.
    unawaited(_performBackgroundSave(optimisticPlace));
  }

  /// Performs the heavy save operations in background.
  Future<void> _performBackgroundSave(Place optimisticPlace) async {
    try {
      // Geocoding.
      final address = await GeocodingService.getAddress(
        optimisticPlace.lat,
        optimisticPlace.lng,
      );

      // Create updated place with real address.
      final updatedPlace = Place(
        id: optimisticPlace.id,
        lat: optimisticPlace.lat,
        lng: optimisticPlace.lng,
        note: optimisticPlace.note,
        timestamp: optimisticPlace.timestamp,
        address: address,
      );

      // Check mounted before using context.
      if (!mounted) return;

      // Write to Pod.
      final success = await PlacesService.addPlace(
        updatedPlace,
        context,
        const GeoMap(),
      );

      if (!mounted) return;

      if (success) {
        setState(() {
          final index = _podPlaces.indexWhere(
            (p) => p.id == optimisticPlace.id,
          );
          if (index != -1) {
            _podPlaces[index] = updatedPlace;
          }
          _savingPlaceIds.remove(optimisticPlace.id);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Place saved successfully!')),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('WritePod failed');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _podPlaces.removeWhere((p) => p.id == optimisticPlace.id);
        _savingPlaceIds.remove(optimisticPlace.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Failed to save: $e')),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Shows options when user taps on the map.
  void _onMapTap(TapPosition tapPosition, LatLng latLng) {
    _showAddPlaceDialog(latitude: latLng.latitude, longitude: latLng.longitude);
  }

  /// Shows detailed information about a marker in a bottom sheet.
  void _showMarkerDetails(MarkerData marker) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: marker.isDefault
                        ? Colors.red.shade50
                        : marker.isSaving
                        ? Colors.orange.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: marker.isSaving
                      ? SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.orange.shade600,
                          ),
                        )
                      : Icon(
                          Icons.place,
                          color: marker.isDefault ? Colors.red : Colors.green,
                          size: 28,
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        marker.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (marker.isDefault)
                        Text(
                          'Default Location',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        )
                      else if (marker.isSaving)
                        Text(
                          'Saving...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            if (marker.description.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes, size: 20, color: Colors.grey.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      marker.description,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.home_outlined,
                  size: 20,
                  color: marker.isSaving
                      ? Colors.orange.shade600
                      : Colors.blue.shade600,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    marker.address ?? 'Address not available',
                    style: TextStyle(
                      fontSize: 14,
                      color: marker.isSaving
                          ? Colors.orange.shade600
                          : marker.address != null
                          ? Colors.blue.shade700
                          : Colors.grey.shade500,
                    ),
                  ),
    ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Icon(Icons.location_on, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 12),
                Text(
                  marker.coordinates,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
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
              initialCenter: const LatLng(-35.2809, 149.1300),
              initialZoom: 13.0,
            minZoom: 3.0,
            maxZoom: 18.0,
              onTap: _onMapTap,
              onLongPress: (tapPosition, latLng) {
                _showAddPlaceDialog(
                  latitude: latLng.latitude,
                  longitude: latLng.longitude,
                );
            },
          ),
          children: [
            TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.togaware.geopod',
                tileProvider: CancellableNetworkTileProvider(),
            ),
            MarkerLayer(
                markers: _allMarkers.map((markerData) {
                return Marker(
                  point: markerData.position,
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                      onTap: () => _showMarkerDetails(markerData),
                      child: markerData.isSaving
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
                          : Icon(
                      Icons.location_on,
                      size: 40,
                              color: markerData.isDefault
                                  ? Colors.red
                                  : Colors.green,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
          if (_isLoadingPlaces)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: Colors.green,
              ),
            ),
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.touch_app, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    _isLoadingPlaces
                        ? 'Loading places...'
                        : 'Tap map to add place',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
      ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'refresh',
            onPressed: _isLoadingPlaces ? null : _loadPodPlaces,
            tooltip: 'Refresh Places',
            backgroundColor: _isLoadingPlaces ? Colors.grey : Colors.blue,
            foregroundColor: Colors.white,
            child: _isLoadingPlaces
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
          ),
          const SizedBox(height: 8),
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
  final String? address;
  final bool isDefault;
  final bool isSaving;

  MarkerData({
    required this.position,
    required this.title,
    required this.description,
    this.address,
    this.isDefault = false,
    this.isSaving = false,
  });

  String get coordinates =>
      '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
}
