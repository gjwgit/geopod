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

import 'package:geopod/models/place.dart';
import 'package:geopod/services/places_service.dart'
    show PlacesService, PlacesCacheManager, placesChangeNotifier;
import 'package:geopod/widgets/locations/edit_place_dialog.dart';
import 'package:geopod/widgets/locations/import_format_dialog.dart';
import 'package:geopod/widgets/locations/import_preview_dialog.dart';
import 'package:geopod/widgets/locations/locations_page_header.dart';
import 'package:geopod/widgets/locations/locations_page_views.dart';
import 'package:geopod/widgets/locations/place_list_tile.dart';

class LocationsPage extends StatefulWidget {
  const LocationsPage({super.key});
  @override
  State<LocationsPage> createState() => _LocationsPageState();
}

class _LocationsPageState extends State<LocationsPage> {
  List<Place> _places = [];
  bool _isLoggedIn = true;
  late bool _isLoading;
  String? _errorMessage;
  bool _hasLoadedOnce = false;

  List<Place> get _userPlaces => _places.where((p) => !p.isLocal).toList();

  @override
  void initState() {
    super.initState();
    _isLoggedIn = authStateNotifier.value;
    final cm = PlacesCacheManager();
    final cached = cm.podPlaces;
    if (cached != null && cached.isNotEmpty) {
      _places = cached;
      _isLoading = false;
      _hasLoadedOnce = true;
    } else {
      final all = cm.allPlaces;
      if (all != null && all.isNotEmpty) {
        _places = all.where((p) => !p.isLocal).toList();
        _isLoading = _places.isEmpty;
        _hasLoadedOnce = _places.isNotEmpty;
      } else {
        _isLoading = true;
      }
    }
    authStateNotifier.addListener(_onAuthStateChanged);
    placesChangeNotifier.addListener(_onPlacesChanged);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _verifyLoginAndRefresh(),
    );
  }

  Future<void> _verifyLoginAndRefresh() async {
    final loggedIn = await checkLoggedIn();
    if (!mounted) return;
    if (loggedIn != _isLoggedIn) {
      setState(() => _isLoggedIn = loggedIn);
      if (loggedIn) {
        final cm = PlacesCacheManager();
        final cached = cm.allPlaces;
        if (cached != null && cached.isNotEmpty) {
          if (mounted) {
            setState(() {
              _places = cached.where((p) => !p.isLocal).toList();
              _isLoading = false;
              _hasLoadedOnce = true;
            });
          }
        } else {
          _loadPlaces(forceRefresh: false);
        }
      } else {
        PlacesService.clearCache();
        setState(() {
          _places = [];
          _hasLoadedOnce = false;
        });
        _loadPlaces();
      }
    } else if (!_hasLoadedOnce) {
      final cm = PlacesCacheManager();
      final cached = cm.allPlaces;
      if (cached != null && cached.isNotEmpty) {
        final up = loggedIn ? cached.where((p) => !p.isLocal).toList() : cached;
        if (mounted) {
          setState(() {
            _places = up;
            _isLoading = false;
            _hasLoadedOnce = true;
          });
        }
      } else {
        _loadPlaces(forceRefresh: false);
      }
    }
  }

  @override
  void dispose() {
    authStateNotifier.removeListener(_onAuthStateChanged);
    placesChangeNotifier.removeListener(_onPlacesChanged);
    super.dispose();
  }

  void _onPlacesChanged() {
    if (mounted && _isLoggedIn) _loadPlaces(forceRefresh: false);
  }

  void _onAuthStateChanged() {
    final loggedIn = authStateNotifier.value;
    if (loggedIn == _isLoggedIn) return;
    if (!loggedIn && mounted) {
      _handleLogout();
    } else if (loggedIn && mounted) {
      setState(() => _isLoggedIn = true);
    }
  }

  Future<void> _handleLogout() async {
    await PlacesService.clearCache();
    if (mounted) {
      setState(() {
        _isLoggedIn = false;
        _places = [];
        _hasLoadedOnce = false;
      });
    }
  }

  Future<void> _loadPlaces({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
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

  Future<void> _refresh() async => await _loadPlaces(forceRefresh: true);

  Future<void> _exportPlaces() async {
    if (_userPlaces.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No places to export'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    final success = await PlacesService.exportPlaces(_places);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      success
          ? SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text('Exported ${_userPlaces.length} places successfully'),
                ],
              ),
              backgroundColor: Colors.green,
            )
          : const SnackBar(
              content: Text('Failed to export places'),
              backgroundColor: Colors.red,
            ),
    );
  }

  Future<void> _importPlaces() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const ImportFormatDialog(),
    );
    if (confirmed != true || !mounted) return;
    final result = await PlacesService.importPlaces();
    if (!mounted) return;
    if (result.cancelled) return;
    if (!result.hasPlaces && result.hasErrors) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
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
              onPressed: () => Navigator.pop(ctx),
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
    final edited = await showDialog<List<Place>>(
      context: context,
      builder: (_) => ImportPreviewDialog(
        places: result.places,
        errors: result.errors,
        skippedCount: result.skippedCount,
      ),
    );
    if (edited == null || edited.isEmpty || !mounted) return;
    final progress = ValueNotifier<String>(
      'Importing ${edited.length} places...\nFetching addresses (0/${edited.length})...',
    );
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: ValueListenableBuilder<String>(
            valueListenable: progress,
            builder: (_, msg, _) => Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Expanded(child: Text(msg)),
              ],
            ),
          ),
        ),
      ),
    );
    final success = await PlacesService.mergeImportedPlaces(
      edited,
      context,
      const LocationsPage(),
      onProgress: (c, t) => progress.value =
          'Importing ${edited.length} places...\nFetching addresses ($c/$t)...',
    );
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
              Text('Imported ${edited.length} places successfully'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
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

  Future<void> _deletePlace(Place place) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Place'),
        content: Text(
          'Are you sure you want to delete "${place.displayTitle}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
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
    final removed = place;
    final ri = _places.indexOf(place);
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
      setState(() => _places.insert(ri.clamp(0, _places.length), removed));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete place'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _clearAllPlaces() async {
    if (_userPlaces.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('Clear All Places'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete ALL ${_userPlaces.length} saved places?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
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
    final removed = _userPlaces.toList();
    setState(() => _places.removeWhere((p) => !p.isLocal));
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
              Text('Cleared ${removed.length} places successfully'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() => _places.insertAll(0, removed));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to clear places'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _editPlace(Place place) async {
    final result = await showDialog<Place>(
      context: context,
      builder: (_) => EditPlaceDialog(place: place),
    );
    if (result == null || !mounted) return;
    final coordsChanged = result.lat != place.lat || result.lng != place.lng;
    final old = place;
    final i = _places.indexOf(place);
    setState(() {
      if (i != -1) _places[i] = result;
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
              coordsChanged
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
      coordinatesChanged: coordsChanged,
    );
    if (!mounted) return;
    if (success) {
      if (coordsChanged) {
        await _loadPlaces();
        if (!mounted) {
          return;
        }
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
      setState(() {
        if (i != -1) _places[i] = old;
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
    if (!_isLoggedIn) return const NotLoggedInView();
    if (_isLoading && !_hasLoadedOnce) return const LoadingView();
    if (_errorMessage != null) {
      return ErrorView(errorMessage: _errorMessage!, onRetry: _refresh);
    }
    final up = _userPlaces;
    if (up.isEmpty) {
      return EmptyPlacesView(onRefresh: _refresh, onImport: _importPlaces);
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: Column(
        children: [
          LocationsPageHeader(
            placeCount: up.length,
            isLoading: _isLoading,
            onRefresh: _refresh,
          ),
          LocationsActionButtons(
            isLoading: _isLoading,
            onExport: _exportPlaces,
            onImport: _importPlaces,
            onClearAll: _clearAllPlaces,
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: up.length,
              itemBuilder: (_, i) {
                final p = up[i];
                return PlaceListTile(
                  place: p,
                  onEdit: () => _editPlace(p),
                  onDelete: () => _deletePlace(p),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
