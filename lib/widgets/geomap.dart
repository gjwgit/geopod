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
import 'package:geopod/services/gdelt_news_service.dart';
import 'package:geopod/services/location_service.dart';
import 'package:geopod/services/map_settings_service.dart';
import 'package:geopod/services/places_service.dart' show placesChangeNotifier;
import 'package:geopod/utils/widget_utils.dart';
import 'package:geopod/widgets/map/fullscreen_toggle_button.dart';
import 'package:geopod/widgets/map/geomap_action_handlers.dart';
import 'package:geopod/widgets/map/geomap_builders.dart';
import 'package:geopod/widgets/map/geomap_core.dart' hide buildLoadingIndicator;
import 'package:geopod/widgets/map/geomap_encrypted_places_loader.dart';
import 'package:geopod/widgets/map/geomap_event_handlers.dart';
import 'package:geopod/widgets/map/geomap_initialization.dart';
import 'package:geopod/widgets/map/geomap_news_mixin.dart';
import 'package:geopod/widgets/map/geomap_place_handlers.dart';
import 'package:geopod/widgets/map/geomap_places_loader.dart';
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
        GeoMapEncryptedPlacesLoader,
        GeoMapNewsMixin {
  // State variables implementation for mixins
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
  @override
  final GdeltNewsService newsService = GdeltNewsService();
  @override
  List<NewsMarker> newsMarkers = [];
  @override
  bool showNewsMarkers = false;
  @override
  bool isLoadingNews = false;
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
      loadSettingsSync: () => loadSettingsSync(
        () => unawaited(
          loadEncryptedPlaces().catchError((error, stackTrace) {
            debugPrint('Failed to load encrypted places: $error');
          }),
        ),
      ),
      verifyLoginStateAndLoadData: () async {
        final result = await verifyLoginStateAndLoadData(
          currentIsLoggedIn: isLoggedIn,
        );
        if (!mounted) return;

        // Update state if login changed
        if (result.loginStateChanged) {
          setState(() {
            isLoggedIn = result.actuallyLoggedIn;
            if (result.places != null) {
              allPlaces = result.places!;
            }
          });
        }

        // Load fresh data if needed
        if (result.needsRefresh) {
          final places = await loadAllPlaces(forceRefresh: false);
          if (mounted) {
            setState(() => allPlaces = places);
          }
        } else if (result.places != null && !result.loginStateChanged) {
          // Use cached places if no refresh needed and state didn't change
          if (mounted) {
            setState(() => allPlaces = result.places!);
          }
        }
      },
    );
    WidgetsBinding.instance.addObserver(this);
  }

  void _onAnimationComplete() {
    if (mounted) {
      initialAnimationComplete = true;
      isPostLoginRefresh = false;
      if (isLoadingPlaces) setState(() {});
    }
  }

  @override
  void dispose() {
    saveViewportIfEnabled(
      mapController: mapController,
      mapSettings: mapSettings,
    );
    animationController.dispose();
    newsService.dispose();
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

          // Handle encrypted places toggle
          if (changes.encryptedToggled && changes.encryptedEnabled) {
            unawaited(
              loadEncryptedPlaces(skipKeyVerification: true).catchError((
                error,
                stackTrace,
              ) {
                debugPrint('Failed to load encrypted places: $error');
              }),
            );
          } else if (changes.encryptedToggled && !changes.encryptedEnabled) {
            safeSetState(this, () {
              allPlaces = removeEncryptedPlaces(allPlaces: allPlaces);
            });
          }
        },
      ),
    );
  }

  /// Handle location button tap - get user location and move map to it.
  Future<void> _onLocatePressed() async {
    if (isLocating) return;

    setState(() => isLocating = true);

    try {
      final result = await LocationService.getCurrentLocation();

      if (!mounted) return;

      if (result.success && result.location != null) {
        // Save user location and move map to it
        setState(() {
          userLocation = result.location;
        });
        mapController.move(result.location!, 15.0);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location found successfully'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Show detailed error message
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
      // If adding encrypted place, auto-enable showEncryptedPlaces so user can see it
      if (result.encrypted && !mapSettings.showEncryptedPlaces) {
        safeSetState(this, () {
          mapSettings = mapSettings.copyWith(showEncryptedPlaces: true);
        });
        MapSettingsService.saveSettings(mapSettings);
      }
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
    // Set flag to skip placesChangeNotifier during our delete operation
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
            showNewsMarkers: showNewsMarkers,
            visibleNewsMarkers: getVisibleNewsMarkersImpl(),
            onTap: (tp, ll) =>
                _showAddPlaceDialog(lat: ll.latitude, lng: ll.longitude),
            onLongPress: (tp, ll) =>
                _showAddPlaceDialog(lat: ll.latitude, lng: ll.longitude),
            onPositionChanged: onMapPositionChangedForNews,
            onDeletePlace: _confirmAndDeletePlace,
            context: context,
            initialCenter: initialCenter,
            initialZoom: initialZoom,
            userLocation: userLocation,
          ),
          // Loading indicator
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
          NewsOverlayButton(
            isLoadingNews: isLoadingNews,
            showNewsMarkers: showNewsMarkers,
            visibleNewsCount: getVisibleNewsMarkersImpl().length,
            onTap: toggleNewsMarkers,
          ),
          // Fullscreen toggle button
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
