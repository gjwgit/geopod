/// Widget displaying saved locations from the user's Solid Pod.
///
// Time-stamp: <2025-12-04 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';

import 'package:solidpod/solidpod.dart';

import 'package:geopod/models/place.dart';
import 'package:geopod/services/places_service.dart'
    show PlacesService, PlacesCacheManager, placesChangeNotifier;
import 'package:geopod/widgets/locations/edit_place_dialog.dart';
import 'package:geopod/widgets/locations/import_operations.dart';
import 'package:geopod/widgets/locations/locations_page_header.dart';
import 'package:geopod/widgets/locations/locations_page_views.dart';
import 'package:geopod/widgets/locations/place_list_tile.dart';
import 'package:geopod/widgets/locations/place_operations.dart';

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
    if (mounted && _isLoggedIn) {
      _loadPlaces(forceRefresh: false);
    }
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
        showNoPlacesToExportSnackbar(context);
      }
      return;
    }
    final success = await PlacesService.exportPlaces(_places);
    if (!mounted) return;
    showExportResultSnackbar(context, success, _userPlaces.length);
  }

  Future<void> _importPlaces() async {
    if (!mounted) return;
    await performImportFlow(context, () async {
      await _loadPlaces();
    });
  }

  Future<void> _deletePlace(Place place) async {
    final confirmed = await showDeletePlaceConfirmation(context, place);
    if (!confirmed || !mounted) return;
    final removed = place;
    final ri = _places.indexOf(place);
    setState(() => _places.remove(place));
    final success = await deletePlaceWithFeedback(context, place);
    if (!mounted) return;
    if (!success) {
      setState(() => _places.insert(ri.clamp(0, _places.length), removed));
    }
  }

  Future<void> _clearAllPlaces() async {
    if (_userPlaces.isEmpty) return;
    final confirmed = await showClearAllConfirmation(
      context,
      _userPlaces.length,
    );
    if (!confirmed || !mounted) return;
    final removed = _userPlaces.toList();
    setState(() => _places.removeWhere((p) => !p.isLocal));
    final success = await clearAllPlacesWithFeedback(context, removed.length);
    if (!mounted) return;
    if (!success) {
      setState(() => _places.insertAll(0, removed));
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
      if (i != -1) {
        _places[i] = result;
      }
    });
    showUpdatingPlaceSnackbar(context, coordsChanged);
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
        if (!mounted) return;
      }
      showUpdateSuccessSnackbar(context);
    } else {
      setState(() {
        if (i != -1) {
          _places[i] = old;
        }
      });
      showUpdateFailureSnackbar(context);
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
