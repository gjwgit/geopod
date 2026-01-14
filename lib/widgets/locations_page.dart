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

import 'package:solidpod/solidpod.dart' show isUserLoggedIn;

import 'package:geopod/models/place.dart';
import 'package:geopod/services/places_service.dart'
    show PlacesService, PlacesCacheManager, placesChangeNotifier;
import 'package:geopod/utils/widget_utils.dart';
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

class _LocationsPageState extends State<LocationsPage>
    with AuthStateManagement {
  List<Place> _places = [];
  late bool _isLoading;
  String? _errorMessage;
  bool _hasLoadedOnce = false;

  List<Place> get _userPlaces => _places.where((p) => !p.isLocal).toList();

  @override
  void initState() {
    super.initState();
    initAuthStateListener();

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

    placesChangeNotifier.addListener(_onPlacesChanged);
    addPostFrameCallback(this, _verifyLoginAndRefresh);
  }

  Future<void> _verifyLoginAndRefresh() async {
    final loggedIn = await isUserLoggedIn();
    if (!mounted) return;

    if (loggedIn != isLoggedIn) {
      // Auth state changed - handled by mixin
      if (loggedIn) {
        final cm = PlacesCacheManager();
        final cached = cm.allPlaces;
        if (cached != null && cached.isNotEmpty) {
          safeSetState(this, () {
            _places = cached.where((p) => !p.isLocal).toList();
            _isLoading = false;
            _hasLoadedOnce = true;
          });
        } else {
          _loadPlaces(forceRefresh: false);
        }
      } else {
        PlacesService.clearCache();
        safeSetState(this, () {
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
        safeSetState(this, () {
          _places = up;
          _isLoading = false;
          _hasLoadedOnce = true;
        });
      } else {
        _loadPlaces(forceRefresh: false);
      }
    }
  }

  @override
  void dispose() {
    disposeAuthStateListener();
    placesChangeNotifier.removeListener(_onPlacesChanged);
    super.dispose();
  }

  @override
  void onAuthStateChanged(bool isLoggedIn) {
    if (!isLoggedIn) {
      _handleLogout();
    }
  }

  void _onPlacesChanged() {
    if (mounted && isLoggedIn) {
      _loadPlaces(forceRefresh: false);
    }
  }

  Future<void> _handleLogout() async {
    await PlacesService.clearCache();
    safeSetState(this, () {
      _places = [];
      _hasLoadedOnce = false;
    });
  }

  Future<void> _loadPlaces({bool forceRefresh = false}) async {
    await executeWithLoading(
      state: this,
      setLoading: (loading) => _isLoading = loading,
      setError: (error) => _errorMessage = error,
      operation: () async {
        final places = await PlacesService.fetchPlaces(
          forceRefresh: forceRefresh,
        );
        _places = places;
        _hasLoadedOnce = true;
      },
    );
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
    safeSetState(this, () => _places.remove(place));

    final success = await deletePlaceWithFeedback(context, place);
    if (!mounted) return;

    if (!success) {
      safeSetState(
        this,
        () => _places.insert(ri.clamp(0, _places.length), removed),
      );
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
    safeSetState(this, () => _places.removeWhere((p) => !p.isLocal));

    final success = await clearAllPlacesWithFeedback(context, removed.length);
    if (!mounted) return;

    if (!success) {
      safeSetState(this, () => _places.insertAll(0, removed));
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

    safeSetState(this, () {
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
      safeSetState(this, () {
        if (i != -1) {
          _places[i] = old;
        }
      });
      showUpdateFailureSnackbar(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoggedIn) return const NotLoggedInView();
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
