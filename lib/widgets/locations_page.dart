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
import 'package:geopod/services/map_settings_service.dart';
import 'package:geopod/services/places/encrypted_places_service.dart';
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

  /// Whether to load and display encrypted places.
  bool _showEncryptedPlaces = false;

  /// Whether to show example (local) places instead of user Pod places.
  /// Only relevant when logged in.
  /// Static so the choice persists across page navigations within the same
  /// app session (but is not written to disk).
  static bool _showingExamples = false;

  /// Cached local/example places — populated whenever logged-in data is loaded.
  List<Place> _examplePlaces = [];

  List<Place> get _userPlaces => _places.where((p) => !p.isLocal).toList();

  @override
  void initState() {
    super.initState();

    // CRITICAL: Initialize auth listener FIRST to get current state.

    initAuthStateListener();

    // Try to load from cache for instant display.
    final cm = PlacesCacheManager();
    final cached = cm.allPlaces;
    final cacheState = cm.wasLoggedInWhenCached;

    // Only use cache if it matches current login state.

    if (cached != null && cached.isNotEmpty && cacheState == isLoggedIn) {
      // Show POD places if logged in, local places if not.
      _places = isLoggedIn
          ? cached
                .where((p) => !p.isLocal)
                .toList() // Logged in: POD places
          : cached
                .where((p) => p.isLocal)
                .toList(); // Not logged in: local examples
      // Also populate example places cache when logged in.
      if (isLoggedIn) {
        _examplePlaces = cached.where((p) => p.isLocal).toList();
      }
      _isLoading = false;
      _hasLoadedOnce = true; // Cache is valid, mark as loaded
    } else {
      // Cache state doesn't match current login state or no cache
      // This happens when: guest cache exists but now logged in, or vice versa
      // _verifyLoginAndRefresh will handle the refresh.
      _isLoading = true;
    }

    placesChangeNotifier.addListener(_onPlacesChanged);
    addPostFrameCallback(this, _verifyLoginAndRefresh);
  }

  Future<void> _verifyLoginAndRefresh() async {
    // Always check current login state from server.
    final loggedIn = await isUserLoggedIn();

    // Load saved encrypted-places preference from map settings.
    final settings = await MapSettingsService.loadSettings();
    if (mounted) {
      setState(() => _showEncryptedPlaces = settings.showEncryptedPlaces);
    }

    // Check if cache matches the actual login state from server.
    final cm = PlacesCacheManager();
    final cacheState = cm.wasLoggedInWhenCached;
    final cacheMatchesLoginState = cacheState == loggedIn;

    if (!mounted) return;

    // If auth state differs from mixin state, force reload
    // (onAuthStateChanged will also be triggered, but that's okay - double check ensures consistency)
    // If we haven't loaded once yet, check if cache matches login state.

    if (loggedIn != isLoggedIn) {
      // Auth state mismatch - force refresh to get correct data.
      await _loadPlaces(forceRefresh: true);
    } else if (!_hasLoadedOnce) {
      // First load but auth state matches
      // Check if cache is from the correct login state.
      if (!cacheMatchesLoginState) {
        // Cache is from different login state (e.g., guest cache when now logged in)
        await _loadPlaces(forceRefresh: true);
      } else {
        // Cache matches current login state - safe to use.
        await _loadPlaces(forceRefresh: false);
      }
    } else if (loggedIn && _examplePlaces.isEmpty) {
      // Already loaded once, but example places cache is empty (e.g. page was
      // initialised from the PlacesCacheManager before _loadPlaces ran).
      await _loadPlaces(forceRefresh: false);
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
    // MUST force refresh on auth state change:
    // - Guest -> Login: need to fetch Pod data
    // - Login -> Logout: need to show local examples
    // - Cache from previous state is invalid.
    _loadPlaces(forceRefresh: true);
  }

  void _onPlacesChanged() {
    // Load places regardless of login state to ensure local places are visible.
    if (mounted) {
      _loadPlaces(forceRefresh: false);
    }
  }

  Future<void> _loadPlaces({bool forceRefresh = false}) async {
    await executeWithLoading(
      state: this,
      setLoading: (loading) => _isLoading = loading,
      setError: (error) => _errorMessage = error,
      operation: () async {
        final places = await PlacesService.fetchPlaces(
          forceRefresh: forceRefresh,
          includeEncrypted: _showEncryptedPlaces,
        );

        // Filter based on login state:
        // - Logged in: show POD places (user's own places, incl. encrypted)
        // - Not logged in: show local example places.

        _places = isLoggedIn
            // Exclude local examples; also exclude encrypted places when
            // the toggle is off — avoids cached encrypted data leaking
            // into the list even when includeEncrypted was false.
            ? places
                  .where(
                    (p) =>
                        !p.isLocal && (_showEncryptedPlaces || !p.isEncrypted),
                  )
                  .toList()
            : places.where((p) => p.isLocal).toList();

        // When logged in, also cache the local/example places so the toggle
        // can switch to them without a second network request.
        if (isLoggedIn) {
          _examplePlaces = places.where((p) => p.isLocal).toList();
        }

        _hasLoadedOnce = true;
      },
    );
  }

  /// Toggles the encrypted places visibility, syncing with map settings.
  /// When enabling, ensures the security key is available (prompts if needed)
  /// so the user doesn't have to navigate to the map first.

  Future<void> _toggleShowEncryptedPlaces(bool value) async {
    if (value) {
      // Ensure security key before enabling — prompt right here in the
      // locations page instead of waiting until the user opens the map.
      final hasKey = await EncryptedPlacesService.ensureSecurityKey(
        context,
        const LocationsPage(),
      );
      if (!mounted) return;
      if (!hasKey) {
        // User cancelled or no key — don't enable the toggle.
        return;
      }
    }

    setState(() => _showEncryptedPlaces = value);
    // Persist the setting in the background — does not block place loading.
    MapSettingsService.loadSettings().then(
      (s) => MapSettingsService.saveSettings(
        s.copyWith(showEncryptedPlaces: value),
      ),
    );
    // forceRefresh: false — fetchPlaces will fast-merge from the
    // EncryptedPlacesService in-memory cache when available.
    await _loadPlaces(forceRefresh: false);
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
    // Show loading view only on first load.
    if (_isLoading && !_hasLoadedOnce) return const LoadingView();

    // Show error view if there's an error.

    if (_errorMessage != null) {
      return ErrorView(errorMessage: _errorMessage!, onRetry: _refresh);
    }

    // Get the appropriate places list based on login state
    // For logged in users: toggle between user places and example places
    // For not logged in: use _places directly (which contains local examples)
    final displayPlaces = isLoggedIn
        ? (_showingExamples ? _examplePlaces : _userPlaces)
        : _places;

    // Show empty view if no places.

    if (displayPlaces.isEmpty) {
      // Show NotLoggedInView for logged-in users with no places
      // Show different message for not-logged-in users.
      if (isLoggedIn) {
        if (_showingExamples) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'No example places available.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ),
          );
        }
        return EmptyPlacesView(onRefresh: _refresh, onImport: _importPlaces);
      } else {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'No local example places available.\nPlease log in to manage your own places.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        );
      }
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: Column(
        children: [
          LocationsPageHeader(
            placeCount: displayPlaces.length,
            isLoading: _isLoading,
            onRefresh: _refresh,
            title: isLoggedIn && _showingExamples
                ? 'Example Places (${displayPlaces.length})'
                : null,
          ),

          // Only show action buttons when logged in.
          if (isLoggedIn) ...[
            // Toggle between user places and example places.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Text('Show examples', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Switch(
                    value: _showingExamples,
                    onChanged: (v) => setState(() => _showingExamples = v),
                    activeThumbColor: Colors.orange,
                  ),
                ],
              ),
            ),
            // Only show export/import/clear when viewing user's own places.
            if (!_showingExamples)
              LocationsActionButtons(
                isLoading: _isLoading,
                onExport: _exportPlaces,
                onImport: _importPlaces,
                onClearAll: _clearAllPlaces,
                showEncryptedToggle: true,
                showEncryptedPlaces: _showEncryptedPlaces,
                onToggleEncrypted: _toggleShowEncryptedPlaces,
              ),
          ],
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: displayPlaces.length,
              itemBuilder: (_, i) {
                final p = displayPlaces[i];
                return PlaceListTile(
                  place: p,

                  // Only allow edit/delete when logged in and place is not local.
                  onEdit: isLoggedIn && !p.isLocal ? () => _editPlace(p) : null,
                  onDelete: isLoggedIn && !p.isLocal
                      ? () => _deletePlace(p)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
