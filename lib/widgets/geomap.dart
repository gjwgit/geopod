/// The primary map widget.
///
// Time-stamp: <Tuesday 2026-01-14 +1100>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.
///
/// Authors: Graham Williams, Miduo

library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:solidpod/solidpod.dart' show authStateNotifier;
import 'package:solidui/solidui.dart';

import 'package:geopod/models/place.dart';
import 'package:geopod/services/location_service.dart';
import 'package:geopod/services/map_settings_service.dart';
import 'package:geopod/services/navigation_service.dart' show pendingNavTarget;
import 'package:geopod/services/places_service.dart'
    show placesChangeNotifier, PlacesService;
import 'package:geopod/utils/widget_utils.dart';
import 'package:geopod/widgets/locations/edit_place_dialog.dart';
import 'package:geopod/widgets/locations/place_operations.dart';
import 'package:geopod/widgets/locations_page.dart';
import 'package:geopod/widgets/map/fullscreen_toggle_button.dart';
import 'package:geopod/widgets/map/geomap_action_handlers.dart';
import 'package:geopod/widgets/map/geomap_builders.dart';
import 'package:geopod/widgets/map/geomap_core.dart' hide buildLoadingIndicator;
import 'package:geopod/widgets/map/geomap_encrypted_places_loader.dart';
import 'package:geopod/widgets/map/geomap_event_handlers.dart';
import 'package:geopod/widgets/map/geomap_initialization.dart';
import 'package:geopod/widgets/map/geomap_place_handlers.dart';
import 'package:geopod/widgets/map/geomap_settings.dart';
import 'package:geopod/widgets/map/geomap_settings_loader.dart';
import 'package:geopod/widgets/map/geomap_state_logic.dart';
import 'package:geopod/widgets/map/geomap_state_mixin.dart';
import 'package:geopod/widgets/map/geomap_viewport_logic.dart';
import 'package:geopod/widgets/map/map_floating_buttons.dart';
import 'package:geopod/widgets/map/map_overlay_buttons.dart';
import 'package:geopod/widgets/map/marker_data.dart';
import 'package:geopod/widgets/map/place_save_handler.dart';
import 'package:geopod/widgets/map_settings_dialog.dart';

class GeoMapWidget extends StatefulWidget {
  const GeoMapWidget({super.key});
  @override
  State<GeoMapWidget> createState() => GeoMapWidgetState();
}

class GeoMapWidgetState extends State<GeoMapWidget>
    with
        SingleTickerProviderStateMixin,
        WidgetsBindingObserver,
        GeoMapStateMixin,
        MarkerCacheMixin,
        GeoMapEventHandlers,
        GeoMapActionHandlers,
        GeoMapSettingsLoader,
        GeoMapEncryptedPlacesLoader {
  // State variables implementation for mixins.
  @override
  final MapController mapController = MapController();
  @override
  TileProvider tileProvider = NetworkTileProvider();
  @override
  List<Place> allPlaces = [];
  @override
  final Set<String> savingPlaceIds = {};
  @override
  bool isLoadingPlaces = false;
  @override
  MapSettings mapSettings = MapSettings(
    mapSource: MapSettings.getDefaultMapSource(),
  );
  @override
  bool isLoggedIn = false;
  @override
  late AnimationController animationController;
  @override
  late Animation<double> fadeAnimation;
  @override
  bool initialAnimationComplete = false;
  @override
  bool isPostLoginRefresh = false;

  // Debounce timer for persisting the map viewport as the user pans/zooms, so
  // the position survives app exit even on desktop (where dispose/lifecycle
  // callbacks are unreliable on window close).
  Timer? _viewportSaveTimer;
  @override
  LatLng initialCenter = const LatLng(defaultInitialLat, defaultInitialLng);
  @override
  double initialZoom = defaultInitialZoom;
  @override
  bool viewportInitialized = false;
  @override
  bool skipPlacesChangeNotification = false;
  @override
  bool isLocating = false;
  @override
  LatLng? userLocation;

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    fadeAnimation = CurvedAnimation(
      parent: animationController,
      curve: Curves.easeOut,
    );

    initializeMapState(
      animationController: animationController,
      fadeAnimation: fadeAnimation,
      onAnimationComplete: _onAnimationComplete,
      onAuthStateChanged: () => onAuthStateChanged(),
      onPlacesChanged: () => onPlacesChanged(),
      authStateNotifier: authStateNotifier,
      placesChangeNotifier: placesChangeNotifier,
    );

    isLoggedIn = authStateNotifier.value;
    initializeMapPostFrame(
      context: context,
      animationController: animationController,
      loadSettingsSync: () =>
          loadSettingsSync(onComplete: _consumePendingNavTarget),
      verifyLoginStateAndLoadData: () async {
        final result = await verifyLoginStateAndLoadData(
          currentIsLoggedIn: isLoggedIn,
        );
        if (!mounted) return;

        // Update state if login changed.

        if (result.loginStateChanged) {
          setState(() {
            isLoggedIn = result.actuallyLoggedIn;
            if (result.places != null) {
              allPlaces = result.places!;
            }
          });
        }

        // Load fresh data if needed.

        if (result.needsRefresh) {
          final places = await loadAllPlaces(
            forceRefresh: false,
            includeEncrypted: true,
          );
          if (mounted) {
            setState(() => allPlaces = places);
          }
        } else if (result.places != null && !result.loginStateChanged) {
          // Use cached places if no refresh needed and state didn't change.
          if (mounted) {
            setState(() => allPlaces = result.places!);
          }
        }
      },
    );
    WidgetsBinding.instance.addObserver(this);

    // Register pending-navigation listener so that a programmatic "navigate
    // to this place" from another page is consumed once the map is ready.
    pendingNavTarget.addListener(_consumePendingNavTarget);
  }

  void _onAnimationComplete() {
    if (mounted) {
      initialAnimationComplete = true;
      isPostLoginRefresh = false;
      if (isLoadingPlaces) setState(() {});
    }
  }

  /// Map position changed: on user gestures, debounce-save the viewport so it
  /// persists across sessions.
  void _onMapPositionChanged(MapCamera pos, bool gesture) {
    if (!gesture) return;
    _viewportSaveTimer?.cancel();
    _viewportSaveTimer = Timer(const Duration(milliseconds: 600), () {
      saveViewportIfEnabled(
        mapController: mapController,
        mapSettings: mapSettings,
      );
    });
  }

  @override
  void dispose() {
    pendingNavTarget.removeListener(_consumePendingNavTarget);
    _viewportSaveTimer?.cancel();
    saveViewportIfEnabled(
      mapController: mapController,
      mapSettings: mapSettings,
    );
    animationController.dispose();
    authStateNotifier.removeListener(onAuthStateChanged);
    placesChangeNotifier.removeListener(onPlacesChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    handleMapLifecycleChange(
      state: state,
      onResume: () => setState(() => tileProvider = createTileProvider()),
      onPauseOrInactive: () => saveViewportIfEnabled(
        mapController: mapController,
        mapSettings: mapSettings,
      ),
    );
  }

  void showSettingsDialog() {
    showDialog(
      context: context,
      builder: (_) => MapSettingsDialog(
        currentSettings: mapSettings,
        onSettingsChanged: (newSettings) {
          final changes = computeSettingsChanges(
            oldSettings: mapSettings,
            newSettings: newSettings,
          );

          safeSetState(this, () {
            mapSettings = newSettings;
            if (changes.mapSourceChanged) {
              tileProvider = createTileProvider();
              adjustZoomForMapSource(
                mapController: mapController,
                mapSettings: newSettings,
              );
            }
          });

          // mapSourceChanged is handled by the tile provider update above.
        },
      ),
    );
  }

  /// Navigate the map to a specific location with an optional zoom level.
  ///
  /// Called externally (e.g., from the Locations page) to jump the map view
  /// to a saved place.

  void navigateToLocation(LatLng position, {double zoom = 16.0}) {
    mapController.move(position, zoom);
  }

  /// Consume a pending navigation target set via [pendingNavTarget].
  ///
  /// Called once after the first frame and whenever [pendingNavTarget] changes.

  void _consumePendingNavTarget() {
    final target = pendingNavTarget.value;
    if (target == null) return;
    // Clear before moving so a second listener call is a no-op.
    pendingNavTarget.value = null;
    navigateToLocation(target);
  }

  /// Handle location button tap - get user location and move map to it.

  Future<void> _onLocatePressed() async {
    if (isLocating) return;

    setState(() => isLocating = true);

    try {
      final result = await LocationService.getCurrentLocation();

      if (!mounted) return;

      if (result.success && result.location != null) {
        // Save user location and move map to it.
        setState(() {
          userLocation = result.location;
        });
        mapController.move(result.location!, 15.0);

        // Show success message.

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location found successfully'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Show detailed error message.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.errorMessage ?? 'Unable to get your location',
              ),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(label: 'OK', onPressed: () {}),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLocating = false);
      }
    }
  }

  /// Cached getter for filtered markers to avoid expensive rebuilds.

  List<MarkerData> get _filteredMarkers {
    return getCachedFilteredMarkers(
      allPlaces: allPlaces,
      mapSettings: mapSettings,
      savingPlaceIds: savingPlaceIds,
      builder: () => buildFilteredMarkers(
        allPlaces: allPlaces,
        mapSettings: mapSettings,
        savingPlaceIds: savingPlaceIds,
      ),
    );
  }

  Future<void> _showAddPlaceDialog({double? lat, double? lng}) async {
    final result = await showAddPlaceDialogIfLoggedIn(
      context: context,
      latitude: lat,
      longitude: lng,
    );
    if (result != null && mounted) {
      _handleOptimisticSave(result.place, encrypted: result.encrypted);
    }
  }

  void _handleOptimisticSave(Place p, {bool encrypted = false}) {
    handleOptimisticPlaceSave(
      place: p,
      allPlaces: allPlaces,
      savingPlaceIds: savingPlaceIds,
      context: context,
      setState: setState,
      performBackgroundSave: (place) => performPlaceBackgroundSave(
        originalPlace: place,
        context: context,
        allPlaces: allPlaces,
        savingPlaceIds: savingPlaceIds,
        setState: setState,
        encrypted: encrypted,
      ),
      encrypted: encrypted,
    );
  }

  Future<void> _confirmAndDeletePlace(MarkerData m) async {
    // Set flag to skip placesChangeNotifier during our delete operation.
    skipPlacesChangeNotification = true;
    try {
      await confirmAndDeletePlace(
        marker: m,
        context: context,
        allPlaces: allPlaces,
        setState: setState,
      );
    } finally {
      skipPlacesChangeNotification = false;
    }
  }

  Future<void> _editPlaceFromMap(MarkerData m) async {
    // Reconstruct a Place from MarkerData for the edit dialog.
    final place = Place(
      id: m.id,
      lat: m.position.latitude,
      lng: m.position.longitude,
      note: m.description,
      timestamp: DateTime.now().toIso8601String(),
      address: m.address,
      isLocal: m.isLocal,
      isEncrypted: m.isEncrypted,
    );

    final result = await showDialog<Place>(
      context: context,
      builder: (_) => EditPlaceDialog(place: place),
    );
    if (result == null || !mounted) return;

    final coordsChanged = result.lat != place.lat || result.lng != place.lng;
    final i = allPlaces.indexWhere((p) => p.id == place.id);
    final old = i != -1 ? allPlaces[i] : null;

    if (i != -1) {
      setState(() => allPlaces[i] = result);
    }

    showUpdatingPlaceSnackbar(context, coordsChanged);

    skipPlacesChangeNotification = true;
    try {
      final success = await PlacesService.updatePlace(
        result,
        context,
        const LocationsPage(),
        coordinatesChanged: coordsChanged,
      );

      if (!mounted) return;

      if (success) {
        showUpdateSuccessSnackbar(context);
        if (coordsChanged) {
          // Reload to get the updated address from the server.
          final places = await loadAllPlaces(
            forceRefresh: true,
            includeEncrypted: true,
          );
          if (mounted) setState(() => allPlaces = places);
        }
      } else {
        if (i != -1 && old != null) {
          setState(() => allPlaces[i] = old);
        }
        showUpdateFailureSnackbar(context);
      }
    } finally {
      skipPlacesChangeNotification = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMapDark = mapSettings.mapSource.isDarkSource;
    final applyFilter = isDark && !isMapDark;
    return Scaffold(
      body: Stack(
        children: [
          buildFlutterMapWidget(
            mapController: mapController,
            fadeAnimation: fadeAnimation,
            mapSettings: mapSettings,
            tileProvider: tileProvider,
            applyFilter: applyFilter,
            filteredMarkers: _filteredMarkers,
            shouldAnimate: !initialAnimationComplete || isPostLoginRefresh,
            onTap: (tp, ll) =>
                _showAddPlaceDialog(lat: ll.latitude, lng: ll.longitude),
            onLongPress: (tp, ll) =>
                _showAddPlaceDialog(lat: ll.latitude, lng: ll.longitude),
            onPositionChanged: _onMapPositionChanged,
            onDeletePlace: _confirmAndDeletePlace,
            onEditPlace: _editPlaceFromMap,
            context: context,
            initialCenter: initialCenter,
            initialZoom: initialZoom,
            userLocation: userLocation,
          ),

          // Loading indicator.
          buildLoadingIndicator(isLoading: isLoadingPlaces),
          AddPlaceOverlayButton(
            isLoading: isLoadingPlaces,
            isLoggedIn: isLoggedIn,
            onTap: () {
              if (isLoggedIn) {
                _showAddPlaceDialog();
              } else {
                SolidAuthHandler.instance.handleLogin(context);
              }
            },
          ),

          // Fullscreen toggle button.
          const FullscreenToggleButton(),
        ],
      ),
      floatingActionButton: RepaintBoundary(
        child: MapFloatingButtons(
          isLoadingPlaces: isLoadingPlaces,
          onZoomIn: () => zoomIn(mapController),
          onZoomOut: () => zoomOut(mapController),
          onRefresh: handleRefreshPressed,
          onLocate: _onLocatePressed,
          isLocating: isLocating,
        ),
      ),
    );
  }
}
