/// The primary map widget.
///
// Time-stamp: <Monday 2025-12-08 08:22:27 +1100 Graham Williams>
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
import 'package:geopod/services/map_settings_service.dart';
import 'package:geopod/services/places_service.dart';
import 'package:geopod/widgets/add_place_form.dart';
import 'package:geopod/widgets/map_settings_dialog.dart';

/// A map widget displaying points of interest with the ability to add new places.
///
/// Features:
/// - Optimistic updates: Places appear instantly before save completes
/// - Background saving: Geocoding + writePod happens without blocking UI
/// - Pre-loaded data: Places are fetched once and cached for instant access
class GeoMapWidget extends StatefulWidget {
  const GeoMapWidget({super.key});

  @override
  State<GeoMapWidget> createState() => GeoMapWidgetState();
}

class GeoMapWidgetState extends State<GeoMapWidget> {
  final MapController _mapController = MapController();

  /// All places (local + Pod) loaded and cached for instant access.
  List<Place> _allPlaces = [];

  /// IDs of places currently being saved in background.
  final Set<String> _savingPlaceIds = {};

  /// Whether initial load is in progress.
  bool _isLoadingPlaces = false;

  /// Map display settings (colors, visibility, map source).
  MapSettings _mapSettings = MapSettings(
    mapSource: MapSettings.getDefaultMapSource(),
  );

  @override
  void initState() {
    super.initState();

    // Pre-load data after first frame for instant sidebar access.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
      _loadAllPlaces();
    });
  }

  /// Loads map settings from SharedPreferences.
  Future<void> _loadSettings() async {
    final settings = await MapSettingsService.loadSettings();
    if (mounted) {
      setState(() => _mapSettings = settings);
    }
  }

  /// Shows the settings dialog.
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => MapSettingsDialog(
        currentSettings: _mapSettings,
        onSettingsChanged: (newSettings) {
          setState(() => _mapSettings = newSettings);
        },
      ),
    );
  }

  /// Public method to show settings dialog (called from app bar).
  void showSettingsDialog() {
    _showSettingsDialog();
  }

  /// Loads all places (local + Pod) using cache-aware fetch.
  /// This will be instant if data is already cached in memory.
  Future<void> _loadAllPlaces({bool forceRefresh = false}) async {
    setState(() => _isLoadingPlaces = true);

    try {
      // Use cache-aware fetch - instant if cached, slow if not
      final places = await PlacesService.fetchPlaces(
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          // Create a mutable copy to avoid reference issues
          _allPlaces = List.from(places);
          _isLoadingPlaces = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingPlaces = false);
      }
    }
  }

  /// Returns filtered markers based on visibility settings.
  ///
  /// Color scheme (customizable via settings):
  /// - Local (canned examples): localPlacesColor (default: Orange)
  /// - Pod (user data): userPlacesColor (default: Blue)
  /// - Saving in progress: Orange with spinner
  List<MarkerData> get _filteredMarkers {
    // Filter places based on visibility settings.
    final visiblePlaces = _mapSettings.showLocalPlaces
        ? _allPlaces
        : _allPlaces.where((p) => !p.isLocal).toList();

    return visiblePlaces
        .map(
          (place) => MarkerData(
            id: place.id,
            position: LatLng(place.lat, place.lng),
            title: place.displayTitle,
            description: place.note,
            address: place.address,
            isLocal: place.isLocal,
            isSaving: _savingPlaceIds.contains(place.id),
            // Use custom colors from settings.
            color: place.isLocal
                ? _mapSettings.localPlacesColor
                : _mapSettings.userPlacesColor,
          ),
        )
        .toList();
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
        returnWidget: const GeoMapWidget(),
      ),
    );

    if (result != null && mounted) {
      _handleOptimisticSave(result.place);
    }
  }

  /// Handles optimistic update and background save.
  void _handleOptimisticSave(Place optimisticPlace) {
    // Add to local list immediately (at the beginning, before local places).
    setState(() {
      _allPlaces.insert(0, optimisticPlace);
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
        const GeoMapWidget(),
      );

      if (!mounted) return;

      if (success) {
        setState(() {
          final index = _allPlaces.indexWhere(
            (p) => p.id == optimisticPlace.id,
          );
          if (index != -1) {
            _allPlaces[index] = updatedPlace;
          }
          _savingPlaceIds.remove(optimisticPlace.id);
        });

        // Update in-memory cache so LocationsPage sees the new data immediately
        PlacesCacheManager().cacheAllPlaces(_allPlaces);

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
        _allPlaces.removeWhere((p) => p.id == optimisticPlace.id);
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

  /// Zooms in the map by one level.
  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    final newZoom = (currentZoom + 0.6).clamp(3.0, 18.0);
    _mapController.move(_mapController.camera.center, newZoom);
  }

  /// Zooms out the map by one level.
  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    final newZoom = (currentZoom - 0.6).clamp(3.0, 18.0);
    _mapController.move(_mapController.camera.center, newZoom);
  }

  /// Shows detailed information about a marker in a bottom sheet.
  void _showMarkerDetails(MarkerData marker) {
    // Use marker's custom color for UI elements.
    final markerColor = marker.color;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => Padding(
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
                    color: marker.isSaving
                        ? Colors.orange.shade50
                        : markerColor.withValues(alpha: 0.1),
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
                      : Icon(Icons.place, color: markerColor, size: 28),
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
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (marker.isSaving)
                        Text(
                          'Saving...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade600,
                          ),
                        )
                      else if (marker.isLocal)
                        Text(
                          'Example Location',
                          style: TextStyle(fontSize: 12, color: markerColor),
                        )
                      else
                        Text(
                          'Your Saved Place',
                          style: TextStyle(fontSize: 12, color: markerColor),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(sheetContext),
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
                  color: marker.isSaving ? Colors.orange.shade600 : markerColor,
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
                          ? markerColor
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

            // Delete button for user's saved places only.
            if (!marker.isLocal && !marker.isSaving) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _confirmAndDeletePlace(marker);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete This Place'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// Shows confirmation dialog and deletes the place if confirmed.
  Future<void> _confirmAndDeletePlace(MarkerData marker) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Place'),
        content: SingleChildScrollView(
          child: Text(
            'Are you sure you want to delete "${marker.title}"?\n\n'
            'This action cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Find the place and its index before deletion
    final removedIndex = _allPlaces.indexWhere((p) => p.id == marker.id);

    // Safety check: ensure place exists before deletion
    if (removedIndex == -1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Place not found'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final removedPlace = _allPlaces[removedIndex];

    setState(() {
      _allPlaces.removeAt(removedIndex);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Deleting place...'),
        duration: Duration(seconds: 1),
      ),
    );

    // Perform actual delete.
    final success = await PlacesService.deletePlace(
      marker.id,
      context,
      const GeoMapWidget(),
    );

    if (!mounted) return;

    if (success) {
      // Update in-memory cache so LocationsPage sees the deletion immediately
      PlacesCacheManager().cacheAllPlaces(_allPlaces);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Place deleted successfully')),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      // Rollback on failure.
      setState(() {
        if (removedIndex >= 0 && removedIndex <= _allPlaces.length) {
          _allPlaces.insert(removedIndex, removedPlace);
        } else {
          _allPlaces.add(removedPlace);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Failed to delete place')),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Detect if app is in dark mode
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Check if current map source is already dark
    final isMapAlreadyDark = _mapSettings.mapSource.isDarkSource;

    // Midnight blue color matrix for dark mode
    // Transforms bright maps into eye-friendly night vision
    const midnightMatrix = <double>[
      -0.33, -0.33, -0.33, 0, 255, // Red
      -0.33, -0.33, -0.33, 0, 255, // Green
      -0.33, -0.33, -0.33, 0, 255, // Blue
      0, 0, 0, 1, 0,
    ];
    // Apply color filter only if:
    // 1. App is in dark mode, AND
    // 2. Map source is NOT already a dark map
    final shouldApplyFilter = isDarkMode && !isMapAlreadyDark;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(-12.46, 130.84), // Darwin
              // initialCenter: const LatLng(-35.2809, 149.1300), // Canberra
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
              // Apply color filter ONLY to tile layer, not markers
              ColorFiltered(
                colorFilter: shouldApplyFilter
                    ? const ColorFilter.matrix(midnightMatrix)
                    : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                child: TileLayer(
                  key: ValueKey(_mapSettings.mapSource),
                  urlTemplate: _mapSettings.mapSource.urlTemplate,
                  subdomains: _mapSettings.mapSource.subdomains,
                  userAgentPackageName: 'com.togaware.geopod',
                  tileProvider: CancellableNetworkTileProvider(),
                  keepBuffer: 3,
                  maxZoom: 19,
                  maxNativeZoom: 18,
                ),
              ),

              // Marker layer - NOT affected by color filter
              MarkerLayer(
                markers: _filteredMarkers.map((markerData) {
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
                              // Use custom color from settings.
                              color: markerData.color,
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
          // Zoom In button
          FloatingActionButton.small(
            heroTag: 'zoomIn',
            onPressed: _zoomIn,
            tooltip: 'Zoom In',
            backgroundColor: Colors.grey.shade800,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add, size: 20),
          ),
          const SizedBox(height: 8),
          // Zoom Out button
          FloatingActionButton.small(
            heroTag: 'zoomOut',
            onPressed: _zoomOut,
            tooltip: 'Zoom Out',
            backgroundColor: Colors.grey.shade800,
            foregroundColor: Colors.white,
            child: const Icon(Icons.remove, size: 20),
          ),
          const SizedBox(height: 16),
          // Refresh Places button
          FloatingActionButton.small(
            heroTag: 'refresh',
            onPressed: _isLoadingPlaces ? null : _loadAllPlaces,
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
          // Add Place button
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

  /// Unique identifier for this place (needed for delete operation).
  final String id;

  /// Whether this marker is from local assets (canned examples).
  final bool isLocal;

  /// Whether this marker is currently being saved.
  final bool isSaving;

  /// Custom color for this marker (from settings).
  final Color color;

  MarkerData({
    required this.position,
    required this.title,
    required this.description,
    required this.id,
    this.address,
    this.isLocal = false,
    this.isSaving = false,
    this.color = Colors.blue,
  });

  String get coordinates =>
      '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
}
