/// Widget displaying saved locations from the user's Solid Pod.
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

import 'package:solidpod/solidpod.dart';

import 'package:geopod/services/geocoding_service.dart';
import 'package:geopod/services/places_service.dart';

/// A page that displays all saved locations from the user's Solid Pod.
///
/// Optimized for instant rendering using cached state.
class LocationsPage extends StatefulWidget {
  const LocationsPage({super.key});

  @override
  State<LocationsPage> createState() => _LocationsPageState();
}

class _LocationsPageState extends State<LocationsPage> {
  /// Cached places list (only user's Pod data, excluding local examples).
  List<Place> _places = [];

  /// Whether the user is logged in (null = checking, true = logged in, false = not logged in).
  bool? _isLoggedIn;

  /// Whether we're currently loading.
  bool _isLoading = true;

  /// Error message if loading failed.
  String? _errorMessage;

  /// Whether data has been loaded at least once.
  bool _hasLoadedOnce = false;

  /// Returns only user's Pod places (filters out local canned examples).
  List<Place> get _userPlaces => _places.where((p) => !p.isLocal).toList();

  @override
  void initState() {
    super.initState();

    // Try to load from cache immediately (synchronous if cached)
    _tryLoadFromCache();

    // Then check login status and load fresh data
    _checkLoginAndLoad();
  }

  /// Tries to load places from in-memory cache synchronously.
  /// This provides instant display if user was previously logged in.
  void _tryLoadFromCache() {
    final cacheManager = PlacesCacheManager();
    final cached = cacheManager.allPlaces;

    if (cached != null && cached.isNotEmpty) {
      // We have cached data, assume user is logged in
      setState(() {
        _places = cached;
        _isLoggedIn = true;
        _hasLoadedOnce = true;
        _isLoading = false;
      });
    }
  }

  /// Checks login status and loads places.
  Future<void> _checkLoginAndLoad() async {
    final loggedIn = await checkLoggedIn();

    if (!mounted) return;

    if (!loggedIn) {
      setState(() {
        _isLoggedIn = false;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoggedIn = true);

    if (!_hasLoadedOnce) {
      await _loadPlaces();
    } else {
      setState(() => _isLoading = false);
    }
  }

  /// Loads places from Pod (or cache if available).
  Future<void> _loadPlaces({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Use cache-aware fetch (instant if cached, slow if not)
      final places = await PlacesService.fetchPlaces(
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _places = places;
          _isLoading = false;
          _hasLoadedOnce = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Manual refresh (forces data reload from Pod).
  Future<void> _refresh() async {
    await _loadPlaces(forceRefresh: true);
  }

  /// Exports user's places to a JSON file.
  Future<void> _exportPlaces() async {
    if (_userPlaces.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No places to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final success = await PlacesService.exportPlaces(_places);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text('Exported ${_userPlaces.length} places successfully'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to export places'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Shows the import dialog with format information, then imports places.
  Future<void> _importPlaces() async {
    // Show format information dialog first.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const _ImportFormatDialog(),
    );

    if (confirmed != true || !mounted) return;

    // Perform import.
    final result = await PlacesService.importPlaces();

    if (!mounted) return;

    if (result.cancelled) {
      return;
    }

    if (!result.hasPlaces && result.hasErrors) {
      // Show error dialog.
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Import Failed'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('No valid places found in the file.'),
                const SizedBox(height: 12),
                const Text(
                  'Errors:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...result.errors
                    .take(10)
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• $e',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ),
                if (result.errors.length > 10)
                  Text(
                    '... and ${result.errors.length - 10} more errors',
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (!result.hasPlaces) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No places found in the file'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show preview dialog with edit capability.
    // Returns the edited list of places, or null if cancelled.
    final editedPlaces = await showDialog<List<Place>>(
      context: context,
      builder: (context) => _ImportPreviewDialog(
        places: result.places,
        errors: result.errors,
        skippedCount: result.skippedCount,
      ),
    );

    if (editedPlaces == null || editedPlaces.isEmpty || !mounted) return;

    // Show loading dialog with progress.
    final progressNotifier = ValueNotifier<String>(
      'Importing ${editedPlaces.length} places...\nFetching addresses (0/${editedPlaces.length})...',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: ValueListenableBuilder<String>(
            valueListenable: progressNotifier,
            builder: (context, message, _) => Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Expanded(child: Text(message)),
              ],
            ),
          ),
        ),
      ),
    );

    // Merge into Pod with progress callback.
    final success = await PlacesService.mergeImportedPlaces(
      editedPlaces,
      context,
      const LocationsPage(),
      onProgress: (current, total) {
        progressNotifier.value =
            'Importing ${editedPlaces.length} places...\nFetching addresses ($current/$total)...';
      },
    );

    // Dismiss progress dialog.
    if (mounted) {
      Navigator.of(context).pop();
    }

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text('Imported ${editedPlaces.length} places successfully'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh the list.
      await _loadPlaces();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save imported places'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Deletes a place with optimistic update.
  Future<void> _deletePlace(Place place) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Place'),
        content: SingleChildScrollView(
          child: Text(
            'Are you sure you want to delete "${place.displayTitle}"?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
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

    final removedPlace = place;
    final removedIndex = _places.indexOf(place);
    setState(() => _places.remove(place));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Deleting place...'),
        duration: Duration(seconds: 1),
      ),
    );

    final success = await PlacesService.deletePlace(
      place.id,
      context,
      const LocationsPage(),
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Place deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() {
        _places.insert(removedIndex.clamp(0, _places.length), removedPlace);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete place'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Clears all user's saved places.
  Future<void> _clearAllPlaces() async {
    if (_userPlaces.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('Clear All Places'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete ALL ${_userPlaces.length} saved places?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Optimistic update - remove all user places from UI.
    final removedPlaces = _userPlaces.toList();
    setState(() {
      _places.removeWhere((p) => !p.isLocal);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Clearing all places...'),
        duration: Duration(seconds: 1),
      ),
    );

    final success = await PlacesService.clearAllPlaces(
      context,
      const LocationsPage(),
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text('Cleared ${removedPlaces.length} places successfully'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      // Rollback on failure.
      setState(() {
        _places.insertAll(0, removedPlaces);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to clear places'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Opens the edit dialog for a place.
  Future<void> _editPlace(Place place) async {
    final result = await showDialog<Place>(
      context: context,
      builder: (context) => _EditPlaceDialog(place: place),
    );

    if (result == null || !mounted) return;

    // Check if coordinates changed.
    final coordinatesChanged =
        result.lat != place.lat || result.lng != place.lng;

    // Optimistic update.
    final oldPlace = place;
    final index = _places.indexOf(place);
    setState(() {
      if (index != -1) {
        _places[index] = result;
      }
    });

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
            Text(
              coordinatesChanged
                  ? 'Updating place and fetching new address...'
                  : 'Updating place...',
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );

    final success = await PlacesService.updatePlace(
      result,
      context,
      const LocationsPage(),
      coordinatesChanged: coordinatesChanged,
    );

    if (!mounted) return;

    if (success) {
      // Refresh to get the updated address if coordinates changed.
      if (coordinatesChanged) {
        await _loadPlaces();
        // Check mounted status again after async operation
        if (!mounted) return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Place updated successfully'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      // Rollback on failure.
      setState(() {
        if (index != -1) {
          _places[index] = oldPlace;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update place'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while checking login status
    if (_isLoggedIn == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Checking login status...'),
          ],
        ),
      );
    }

    // Show login prompt if not logged in
    if (_isLoggedIn == false) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Please log in to view your saved locations',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _checkLoginAndLoad,
              icon: const Icon(Icons.refresh),
              label: const Text('Check Again'),
            ),
          ],
        ),
      );
    }

    // Show loading indicator for data
    if (_isLoading && !_hasLoadedOnce) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading your saved places...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Error loading places',
              style: TextStyle(fontSize: 18, color: Colors.red.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    // Filter to only show user's Pod data (exclude local canned examples).
    final userPlaces = _userPlaces;

    if (userPlaces.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No saved places',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button on the map to add a new place',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _importPlaces,
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Import JSON'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                    side: BorderSide(color: Colors.blue.shade300),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'My Places (${userPlaces.length})',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _refresh,
                    tooltip: 'Refresh',
                  ),
              ],
            ),
          ),
          // Import/Export buttons row.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _exportPlaces,
                    icon: const Icon(Icons.file_upload_outlined, size: 18),
                    label: const Text('Export'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      side: BorderSide(color: Colors.green.shade300),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _importPlaces,
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    label: const Text('Import'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                      side: BorderSide(color: Colors.blue.shade300),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _clearAllPlaces,
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                    label: const Text('Clear All'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: userPlaces.length,
              itemBuilder: (context, index) {
                final place = userPlaces[index];
                return _PlaceListTile(
                  place: place,
                  onEdit: () => _editPlace(place),
                  onDelete: () => _deletePlace(place),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A list tile widget for displaying a single user place.
///
/// Only displays user's Pod data (not local canned examples).
class _PlaceListTile extends StatelessWidget {
  const _PlaceListTile({
    required this.place,
    required this.onEdit,
    required this.onDelete,
  });

  final Place place;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(Icons.place, color: Colors.white),
        ),
        title: Text(
          place.displayTitle,
          style: const TextStyle(fontWeight: FontWeight.w500),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.home_outlined,
                  size: 14,
                  color: place.address != null ? Colors.blue : Colors.grey,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    place.shortAddress,
                    style: TextStyle(
                      fontSize: 12,
                      color: place.address != null
                          ? Colors.blue.shade700
                          : Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  place.coordinates,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  place.formattedDate,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit_outlined, color: Colors.blue.shade600),
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onDelete,
              tooltip: 'Delete',
            ),
          ],
        ),
        isThreeLine: true,
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.place, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(child: Text('Place Details')),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow(label: 'Note', value: place.note),
                    const SizedBox(height: 12),
                    _DetailRow(
                      label: 'Address',
                      value: place.address ?? 'No address available',
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      label: 'Latitude',
                      value: place.lat.toStringAsFixed(6),
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(
                      label: 'Longitude',
                      value: place.lng.toStringAsFixed(6),
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(label: 'Saved', value: place.formattedDate),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A simple detail row widget.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}

/// Dialog showing the expected JSON format for importing places.
class _ImportFormatDialog extends StatelessWidget {
  const _ImportFormatDialog();

  static const String _exampleJson = '''[
  {
    "id": "place_001",
    "lat": -33.8568,
    "lng": 151.2153,
    "note": "Sydney Opera House",
    "timestamp": "2025-01-01T00:00:00.000Z",
    "address": "Bennelong Point, Sydney"
  }
]''';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue),
          SizedBox(width: 8),
          Expanded(child: Text('Import JSON Format')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your JSON file should contain an array of place objects.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Required Fields:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            _buildFieldInfo('lat', 'Latitude (-90 to 90)', isRequired: true),
            _buildFieldInfo('lng', 'Longitude (-180 to 180)', isRequired: true),
            const SizedBox(height: 12),
            const Text(
              'Optional Fields (auto-filled if missing):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            _buildFieldInfo('id', 'Unique ID (auto-generated UUID)'),
            _buildFieldInfo('note', 'Description (defaults to empty)'),
            _buildFieldInfo('timestamp', 'ISO date (defaults to now)'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Address field is ignored. Addresses will be auto-generated from coordinates using reverse geocoding.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Example:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                _exampleJson,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.folder_open, size: 18),
          label: const Text('Select File'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildFieldInfo(
    String field,
    String description, {
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isRequired ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: isRequired ? Colors.red.shade400 : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            field,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isRequired ? Colors.red.shade700 : Colors.blue.shade700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog for editing a place's lat, lng, and note.
class _EditPlaceDialog extends StatefulWidget {
  const _EditPlaceDialog({required this.place});

  final Place place;

  @override
  State<_EditPlaceDialog> createState() => _EditPlaceDialogState();
}

class _EditPlaceDialogState extends State<_EditPlaceDialog> {
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _noteController;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _previewAddress;

  @override
  void initState() {
    super.initState();
    _latController = TextEditingController(
      text: widget.place.lat.toStringAsFixed(6),
    );
    _lngController = TextEditingController(
      text: widget.place.lng.toStringAsFixed(6),
    );
    _noteController = TextEditingController(text: widget.place.note);
    _previewAddress = widget.place.address;
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Previews the address for current coordinates.
  Future<void> _previewAddressForCoordinates() async {
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);

    if (lat == null || lng == null) return;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return;

    setState(() => _isLoading = true);

    final address = await GeocodingService.getAddress(lat, lng);

    if (mounted) {
      setState(() {
        _previewAddress = address;
        _isLoading = false;
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);

    if (lat == null || lng == null) return;

    final updatedPlace = Place(
      id: widget.place.id,
      lat: lat,
      lng: lng,
      note: _noteController.text.trim(),
      timestamp: widget.place.timestamp,
      address: widget
          .place
          .address, // Address will be updated by service if coords changed.
      isLocal: false,
    );

    Navigator.pop(context, updatedPlace);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.edit, color: Colors.blue),
          SizedBox(width: 8),
          Expanded(child: Text('Edit Place')),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  hintText: 'Enter a description',
                  prefixIcon: Icon(Icons.notes),
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        hintText: '-90 to 90',
                        prefixIcon: Icon(Icons.north),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final lat = double.tryParse(value);
                        if (lat == null || lat < -90 || lat > 90) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lngController,
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        hintText: '-180 to 180',
                        prefixIcon: Icon(Icons.east),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final lng = double.tryParse(value);
                        if (lng == null || lng < -180 || lng > 180) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Preview address button.
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _previewAddressForCoordinates,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.location_searching, size: 18),
                  label: const Text('Preview Address'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Address preview.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.home_outlined,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Address:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _previewAddress ?? 'Not available',
                      style: TextStyle(
                        fontSize: 13,
                        color: _previewAddress != null
                            ? Colors.black87
                            : Colors.grey.shade500,
                        fontStyle: _previewAddress != null
                            ? FontStyle.normal
                            : FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Note: Address will be automatically updated when you save if coordinates change.',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save, size: 18),
          label: const Text('Save'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// Dialog showing a preview of places to be imported with edit/delete capabilities.
class _ImportPreviewDialog extends StatefulWidget {
  const _ImportPreviewDialog({
    required this.places,
    required this.errors,
    required this.skippedCount,
  });

  final List<Place> places;
  final List<String> errors;
  final int skippedCount;

  @override
  State<_ImportPreviewDialog> createState() => _ImportPreviewDialogState();
}

class _ImportPreviewDialogState extends State<_ImportPreviewDialog> {
  late List<Place> _editablePlaces;

  @override
  void initState() {
    super.initState();
    // Create a mutable copy of the places list.
    _editablePlaces = List<Place>.from(widget.places);
  }

  /// Opens the edit dialog for a place in the preview list.
  Future<void> _editPreviewPlace(int index) async {
    final place = _editablePlaces[index];
    final result = await showDialog<Place>(
      context: context,
      builder: (context) => _EditImportPlaceDialog(place: place, index: index),
    );

    if (result != null && mounted) {
      setState(() {
        _editablePlaces[index] = result;
      });
    }
  }

  /// Removes a place from the preview list.
  void _removePreviewPlace(int index) {
    setState(() {
      _editablePlaces.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.preview, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Import Preview (${_editablePlaces.length} places)'),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.skippedCount > 0) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        color: Colors.orange.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${widget.skippedCount} items skipped due to validation errors',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // Info box about editing.
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tap the edit icon to modify a place before importing, or the delete icon to remove it.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Places to import:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const Spacer(),
                  if (_editablePlaces.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _editablePlaces.clear();
                        });
                      },
                      icon: Icon(
                        Icons.delete_sweep,
                        size: 16,
                        color: Colors.red.shade600,
                      ),
                      label: Text(
                        'Remove All',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_editablePlaces.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No places to import',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _editablePlaces.length,
                    itemBuilder: (context, index) {
                      final place = _editablePlaces[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            radius: 16,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                          title: Text(
                            place.note.isEmpty
                                ? '(No note)'
                                : place.displayTitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: place.note.isEmpty
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            place.coordinates,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: Colors.blue.shade600,
                                ),
                                onPressed: () => _editPreviewPlace(index),
                                tooltip: 'Edit',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Colors.red,
                                ),
                                onPressed: () => _removePreviewPlace(index),
                                tooltip: 'Remove',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _editablePlaces.isEmpty
              ? null
              : () => Navigator.pop(context, _editablePlaces),
          icon: const Icon(Icons.download, size: 18),
          label: Text('Import ${_editablePlaces.length} Places'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// Dialog for editing a place during import preview.
class _EditImportPlaceDialog extends StatefulWidget {
  const _EditImportPlaceDialog({required this.place, required this.index});

  final Place place;
  final int index;

  @override
  State<_EditImportPlaceDialog> createState() => _EditImportPlaceDialogState();
}

class _EditImportPlaceDialogState extends State<_EditImportPlaceDialog> {
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _noteController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _latController = TextEditingController(
      text: widget.place.lat.toStringAsFixed(6),
    );
    _lngController = TextEditingController(
      text: widget.place.lng.toStringAsFixed(6),
    );
    _noteController = TextEditingController(text: widget.place.note);
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);

    if (lat == null || lng == null) return;

    final updatedPlace = Place(
      id: widget.place.id,
      lat: lat,
      lng: lng,
      note: _noteController.text.trim(),
      timestamp: widget.place.timestamp,
      address: null, // Address will be fetched during import.
      isLocal: false,
    );

    Navigator.pop(context, updatedPlace);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit, color: Colors.blue.shade600),
          const SizedBox(width: 8),
          Expanded(child: Text('Edit Place #${widget.index + 1}')),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  hintText: 'Enter a description',
                  prefixIcon: Icon(Icons.notes),
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        hintText: '-90 to 90',
                        prefixIcon: Icon(Icons.north),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final lat = double.tryParse(value);
                        if (lat == null || lat < -90 || lat > 90) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lngController,
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        hintText: '-180 to 180',
                        prefixIcon: Icon(Icons.east),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final lng = double.tryParse(value);
                        if (lng == null || lng < -180 || lng > 180) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Address will be auto-generated from coordinates when imported.',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Apply'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
