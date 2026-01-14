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
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';

import 'package:geopod/models/place.dart';
import 'package:geopod/services/gdelt_news_service.dart';
import 'package:geopod/services/map_settings_service.dart';
import 'package:geopod/services/places_service.dart' show placesChangeNotifier;
import 'package:geopod/utils/widget_utils.dart';
import 'package:solidpod/solidpod.dart' show authStateNotifier;
import 'package:solidui/solidui.dart';
import 'package:geopod/widgets/map/fullscreen_toggle_button.dart';
import 'package:geopod/widgets/map/geomap_builders.dart';
import 'package:geopod/widgets/map/geomap_core.dart' hide buildLoadingIndicator;
import 'package:geopod/widgets/map/geomap_initialization.dart';
import 'package:geopod/widgets/map/geomap_news_mixin.dart';
import 'package:geopod/widgets/map/geomap_place_handlers.dart';
import 'package:geopod/widgets/map/geomap_places_loader.dart';
import 'package:geopod/widgets/map/geomap_settings.dart';
import 'package:geopod/widgets/map/geomap_state_logic.dart';
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
        GeoMapNewsMixin {
  @override
  final MapController mapController = MapController();
  TileProvider _tileProvider = CancellableNetworkTileProvider();
  List<Place> _allPlaces = [];
  final Set<String> _savingPlaceIds = {};
  bool _isLoadingPlaces = false;
  MapSettings _mapSettings = MapSettings(
    mapSource: MapSettings.getDefaultMapSource(),
  );
  bool _isLoggedIn = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _initialAnimationComplete = false;
  bool _isPostLoginRefresh = false;
  @override
  final GdeltNewsService newsService = GdeltNewsService();
  @override
  List<NewsMarker> newsMarkers = [];
  @override
  bool showNewsMarkers = false;
  @override
  bool isLoadingNews = false;
  LatLng _initialCenter = const LatLng(defaultInitialLat, defaultInitialLng);
  double _initialZoom = defaultInitialZoom;
  bool _viewportInitialized = false;

  // Cached filtered markers to avoid rebuilding on every setState
  List<MarkerData>? _cachedFilteredMarkers;
  int _lastPlacesHash = 0;
  int _lastSavingIdsHash = 0;
  bool _lastShowLocalPlaces = true;
  bool _lastShowEncryptedPlaces = false;

  // Flag to skip placesChangeNotifier during local delete operations
  bool _skipPlacesChangeNotification = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    initializeMapState(
      animationController: _animationController,
      fadeAnimation: _fadeAnimation,
      onAnimationComplete: _onAnimationComplete,
      onAuthStateChanged: _onAuthStateChanged,
      onPlacesChanged: _onPlacesChanged,
      authStateNotifier: authStateNotifier,
      placesChangeNotifier: placesChangeNotifier,
    );

    _isLoggedIn = authStateNotifier.value;
    initializeMapPostFrame(
      context: context,
      animationController: _animationController,
      loadSettingsSync: _loadSettingsSync,
      verifyLoginStateAndLoadData: _verifyLoginStateAndLoadData,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  void _onAnimationComplete() {
    if (mounted) {
      _initialAnimationComplete = true;
      _isPostLoginRefresh = false;
      if (_isLoadingPlaces) setState(() {});
    }
  }

  @override
  void dispose() {
    saveViewportIfEnabled(
      mapController: mapController,
      mapSettings: _mapSettings,
    );
    _animationController.dispose();
    newsService.dispose();
    authStateNotifier.removeListener(_onAuthStateChanged);
    placesChangeNotifier.removeListener(_onPlacesChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onPlacesChanged() {
    // Skip if we triggered this ourselves (during delete operations)
    if (_skipPlacesChangeNotification) return;
    if (mounted && _isLoggedIn) _loadAllPlaces(forceRefresh: false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    handleMapLifecycleChange(
      state: state,
      onResume: () => setState(() => _tileProvider = createTileProvider()),
      onPauseOrInactive: () => saveViewportIfEnabled(
        mapController: mapController,
        mapSettings: _mapSettings,
      ),
    );
  }

  void _onAuthStateChanged() {
    if (!mounted) return;
    final wasLoggedIn = _isLoggedIn;
    final isNowLoggedIn = authStateNotifier.value;
    if (isNowLoggedIn == wasLoggedIn) return;

    safeSetState(this, () => _isLoggedIn = isNowLoggedIn);

    if (isNowLoggedIn && !wasLoggedIn) {
      _handleLogin();
    } else if (!isNowLoggedIn && wasLoggedIn) {
      _handleLogout();
    }
  }

  Future<void> _handleLogin() async {
    if (!mounted) return;
    _isPostLoginRefresh = true;
    _initialAnimationComplete = false;

    final localPlaces = await handleLogin(context: context);
    safeSetState(this, () {
      _isLoggedIn = true;
      _allPlaces = localPlaces;
    });
  }

  Future<void> _handleLogout() async {
    final places = await handleLogout();
    if (!mounted) return;
    _isPostLoginRefresh = false;
    _initialAnimationComplete = false;
    safeSetState(this, () {
      _isLoggedIn = false;
      _allPlaces = places;
    });
  }

  void _loadSettingsSync() {
    loadMapSettingsSync(viewportInitialized: _viewportInitialized)
        .then((result) {
          if (!mounted) return;

          safeSetState(this, () {
            _mapSettings = result.settings;
            if (result.initialCenter != null) {
              _initialCenter = result.initialCenter!;
              _initialZoom = result.initialZoom!;
              _viewportInitialized = result.viewportInitialized;
            }
          });

          // Move map after state update if viewport was loaded
          if (result.initialCenter != null) {
            mapController.move(result.initialCenter!, result.initialZoom!);
          }

          // Validate encrypted setting if enabled
          if (result.settings.showEncryptedPlaces) {
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) _validateSavedEncryptedSetting();
            });
          }
        })
        .catchError((_) {});
  }

  Future<void> _validateSavedEncryptedSetting() async {
    final shouldLoad = await validateSavedEncryptedSetting(
      mapSettings: _mapSettings,
      isLoggedIn: _isLoggedIn,
      allPlaces: _allPlaces,
    );

    if (!shouldLoad) {
      // Reset setting if validation failed
      if (!_isLoggedIn) {
        safeSetState(this, () {
          _mapSettings = _mapSettings.copyWith(showEncryptedPlaces: false);
        });
      }
      return;
    }

    // Load encrypted places
    unawaited(_loadEncryptedPlaces());
  }

  Future<void> _verifyLoginStateAndLoadData() async {
    // Local places already loaded in initState, skip if not empty
    final result = await verifyLoginStateAndLoadData(
      currentIsLoggedIn: _isLoggedIn,
    );
    if (!mounted) return;

    // Batch all state changes into single setState
    final needsRebuild = result.loginStateChanged || result.places != null;
    if (needsRebuild) {
      safeSetState(this, () {
        if (result.loginStateChanged) {
          _isLoggedIn = result.actuallyLoggedIn;
        }
        if (result.places != null) {
          _allPlaces = result.places!;
        }
      });
    }

    if (result.needsRefresh) {
      // Load in background without blocking - add slight delay to let UI settle
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) unawaited(_loadAllPlaces(forceRefresh: true));
      });
    }
  }

  void showSettingsDialog() {
    showDialog(
      context: context,
      builder: (_) => MapSettingsDialog(
        currentSettings: _mapSettings,
        onSettingsChanged: (newSettings) {
          final changes = computeSettingsChanges(
            oldSettings: _mapSettings,
            newSettings: newSettings,
          );

          safeSetState(this, () {
            _mapSettings = newSettings;
            if (changes.mapSourceChanged) {
              _tileProvider = createTileProvider();
              adjustZoomForMapSource(
                mapController: mapController,
                mapSettings: newSettings,
              );
            }
          });

          // Handle encrypted places toggle
          if (changes.encryptedToggled && changes.encryptedEnabled) {
            unawaited(_loadEncryptedPlaces(skipKeyVerification: true));
          } else if (changes.encryptedToggled && !changes.encryptedEnabled) {
            safeSetState(this, () {
              _allPlaces = removeEncryptedPlaces(allPlaces: _allPlaces);
            });
          }
        },
      ),
    );
  }

  Future<void> _loadAllPlaces({
    bool forceRefresh = false,
    bool? includeEncrypted,
  }) async {
    final result = await loadPlacesWithState(
      currentPlaces: _allPlaces,
      forceRefresh: forceRefresh,
      includeEncrypted: includeEncrypted ?? _mapSettings.showEncryptedPlaces,
    );

    if (!mounted) return;

    if (result.showLoading) {
      safeSetState(this, () => _isLoadingPlaces = true);
    }

    if (result.hasChanges || _isLoadingPlaces) {
      safeSetState(this, () {
        _allPlaces = List.from(result.places);
        _isLoadingPlaces = false;
      });
    }
  }

  Future<void> _loadEncryptedPlaces({bool skipKeyVerification = false}) async {
    if (!_isLoggedIn || !mounted) return;

    final result = await loadEncryptedPlaces(
      context: context,
      widget: widget,
      isLoggedIn: _isLoggedIn,
      skipKeyVerification: skipKeyVerification,
    );

    if (result.cancelled && mounted) {
      safeSetState(this, () {
        _mapSettings = _mapSettings.copyWith(showEncryptedPlaces: false);
      });
      MapSettingsService.saveSettings(_mapSettings);
      return;
    }

    if (mounted && result.encryptedPlaces.isNotEmpty) {
      safeSetState(this, () {
        _allPlaces = mergeEncryptedPlaces(
          allPlaces: _allPlaces,
          encryptedPlaces: result.encryptedPlaces,
        );
      });
    }
  }

  /// Cached getter for filtered markers to avoid expensive rebuilds.
  List<MarkerData> get _filteredMarkers {
    // Compute hashes to detect changes
    final placesHash = Object.hashAll(_allPlaces.map((p) => p.id));
    final savingHash = Object.hashAll(_savingPlaceIds);
    final showLocal = _mapSettings.showLocalPlaces;
    final showEncrypted = _mapSettings.showEncryptedPlaces;

    // Return cached if nothing changed
    if (_cachedFilteredMarkers != null &&
        placesHash == _lastPlacesHash &&
        savingHash == _lastSavingIdsHash &&
        showLocal == _lastShowLocalPlaces &&
        showEncrypted == _lastShowEncryptedPlaces) {
      return _cachedFilteredMarkers!;
    }

    // Rebuild and cache
    _lastPlacesHash = placesHash;
    _lastSavingIdsHash = savingHash;
    _lastShowLocalPlaces = showLocal;
    _lastShowEncryptedPlaces = showEncrypted;
    _cachedFilteredMarkers = buildFilteredMarkers(
      allPlaces: _allPlaces,
      mapSettings: _mapSettings,
      savingPlaceIds: _savingPlaceIds,
    );
    return _cachedFilteredMarkers!;
  }

  Future<void> _showAddPlaceDialog({double? lat, double? lng}) async {
    final result = await showAddPlaceDialogIfLoggedIn(
      context: context,
      latitude: lat,
      longitude: lng,
    );
    if (result != null && mounted) {
      // If adding encrypted place, auto-enable showEncryptedPlaces so user can see it
      if (result.encrypted && !_mapSettings.showEncryptedPlaces) {
        safeSetState(this, () {
          _mapSettings = _mapSettings.copyWith(showEncryptedPlaces: true);
        });
        MapSettingsService.saveSettings(_mapSettings);
      }
      _handleOptimisticSave(result.place, encrypted: result.encrypted);
    }
  }

  void _handleOptimisticSave(Place p, {bool encrypted = false}) {
    handleOptimisticPlaceSave(
      place: p,
      allPlaces: _allPlaces,
      savingPlaceIds: _savingPlaceIds,
      context: context,
      setState: setState,
      performBackgroundSave: (place) => performPlaceBackgroundSave(
        originalPlace: place,
        context: context,
        allPlaces: _allPlaces,
        savingPlaceIds: _savingPlaceIds,
        setState: setState,
        encrypted: encrypted,
      ),
      encrypted: encrypted,
    );
  }

  Future<void> _confirmAndDeletePlace(MarkerData m) async {
    // Set flag to skip placesChangeNotifier during our delete operation
    _skipPlacesChangeNotification = true;
    try {
      await confirmAndDeletePlace(
        marker: m,
        context: context,
        allPlaces: _allPlaces,
        setState: setState,
      );
    } finally {
      _skipPlacesChangeNotification = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMapDark = _mapSettings.mapSource.isDarkSource;
    final applyFilter = isDark && !isMapDark;
    return Scaffold(
      body: Stack(
        children: [
          buildFlutterMapWidget(
            mapController: mapController,
            fadeAnimation: _fadeAnimation,
            mapSettings: _mapSettings,
            tileProvider: _tileProvider,
            applyFilter: applyFilter,
            filteredMarkers: _filteredMarkers,
            shouldAnimate: !_initialAnimationComplete || _isPostLoginRefresh,
            showNewsMarkers: showNewsMarkers,
            visibleNewsMarkers: getVisibleNewsMarkersImpl(),
            onTap: (tp, ll) =>
                _showAddPlaceDialog(lat: ll.latitude, lng: ll.longitude),
            onLongPress: (tp, ll) =>
                _showAddPlaceDialog(lat: ll.latitude, lng: ll.longitude),
            onPositionChanged: onMapPositionChangedForNews,
            onDeletePlace: _confirmAndDeletePlace,
            context: context,
            initialCenter: _initialCenter,
            initialZoom: _initialZoom,
          ),
          // Loading indicator
          buildLoadingIndicator(isLoading: _isLoadingPlaces),
          AddPlaceOverlayButton(
            isLoading: _isLoadingPlaces,
            isLoggedIn: _isLoggedIn,
            onTap: () {
              if (_isLoggedIn) {
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
          isLoadingPlaces: _isLoadingPlaces,
          onZoomIn: () => zoomIn(mapController),
          onZoomOut: () => zoomOut(mapController),
          onRefresh: _loadAllPlaces,
        ),
      ),
    );
  }
}
