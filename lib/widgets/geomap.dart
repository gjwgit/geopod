/// The primary map widget.
///
// Time-stamp: <Monday 2025-12-08 08:22:27 +1100 Graham Williams>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
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
import 'package:solidpod/solidpod.dart';
import 'package:solidui/solidui.dart';

import 'package:geopod/models/place.dart';
import 'package:geopod/services/gdelt_news_service.dart';
import 'package:geopod/services/map_settings_service.dart';
import 'package:geopod/services/places_service.dart'
    show PlacesCacheManager, placesChangeNotifier;
import 'package:geopod/widgets/map/geomap_core.dart';
import 'package:geopod/widgets/map/geomap_news_mixin.dart';
import 'package:geopod/widgets/map/geomap_place_handlers.dart';
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
    _animationController.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        setState(() {
          _initialAnimationComplete = true;
          _isPostLoginRefresh = false;
        });
      }
    });
    _isLoggedIn = AuthDataManager.isLoggedInSync();
    authStateNotifier.addListener(_onAuthStateChanged);
    placesChangeNotifier.addListener(_onPlacesChanged);
    _loadSettingsSync();
    _verifyLoginStateAndLoadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _animationController.forward();
    });
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _saveCurrentViewport();
    _animationController.dispose();
    newsService.dispose();
    authStateNotifier.removeListener(_onAuthStateChanged);
    placesChangeNotifier.removeListener(_onPlacesChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Saves current viewport position if rememberViewport is enabled.
  void _saveCurrentViewport() {
    saveCurrentViewport(
      mapController: mapController,
      mapSettings: _mapSettings,
    );
  }

  void _onPlacesChanged() {
    // Skip if we triggered this ourselves (during delete operations)
    if (_skipPlacesChangeNotification) return;
    if (mounted && _isLoggedIn) _loadAllPlaces(forceRefresh: false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      setState(() => _tileProvider = CancellableNetworkTileProvider());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveCurrentViewport();
    }
  }

  void _onAuthStateChanged() {
    if (!mounted) return;
    final wasLoggedIn = _isLoggedIn;
    final isNowLoggedIn = authStateNotifier.value;
    if (isNowLoggedIn == wasLoggedIn) return;
    setState(() => _isLoggedIn = isNowLoggedIn);
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
    setState(() => _isLoggedIn = true);
    final places = await handleLoginStateChange(
      wasLoggedIn: false,
      isNowLoggedIn: true,
    );
    if (mounted) setState(() => _allPlaces = places);
  }

  Future<void> _handleLogout() async {
    final places = await handleLoginStateChange(
      wasLoggedIn: true,
      isNowLoggedIn: false,
    );
    if (!mounted) return;
    _isPostLoginRefresh = false;
    _initialAnimationComplete = false;
    setState(() {
      _isLoggedIn = false;
      _allPlaces = places;
    });
  }

  void _loadSettingsSync() {
    MapSettingsService.loadSettings()
        .then((s) async {
          if (!mounted) return;
          setState(() => _mapSettings = s);
          // Load startup viewport after settings are loaded
          if (!_viewportInitialized) {
            final viewport = await MapSettingsService.getStartupViewport(s);
            if (mounted) {
              setState(() {
                _initialCenter = LatLng(viewport.lat, viewport.lng);
                _initialZoom = viewport.zoom;
                _viewportInitialized = true;
              });
              // Move map to the loaded viewport
              mapController.move(_initialCenter, _initialZoom);
            }
          }
        })
        .catchError((_) {});
  }

  Future<void> _verifyLoginStateAndLoadData() async {
    final result = await verifyLoginStateAndLoadData(
      currentIsLoggedIn: _isLoggedIn,
    );
    if (!mounted) return;
    if (result.loginStateChanged) {
      setState(() => _isLoggedIn = result.actuallyLoggedIn);
    }
    if (result.places != null) {
      setState(() => _allPlaces = result.places!);
    }
    if (result.needsRefresh) {
      await _loadAllPlaces(forceRefresh: true);
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (_) => MapSettingsDialog(
        currentSettings: _mapSettings,
        onSettingsChanged: (ns) {
          setState(() {
            final changed = _mapSettings.mapSource != ns.mapSource;
            _mapSettings = ns;
            if (changed) {
              _tileProvider = CancellableNetworkTileProvider();
              // Adjust zoom level if current zoom exceeds new map source's max
              adjustZoomForMapSource(
                mapController: mapController,
                mapSettings: ns,
              );
            }
          });
        },
      ),
    );
  }

  void showSettingsDialog() => _showSettingsDialog();

  Future<void> _loadAllPlaces({bool forceRefresh = false}) async {
    final cm = PlacesCacheManager();
    if (cm.allPlaces == null) setState(() => _isLoadingPlaces = true);
    try {
      final places = await loadAllPlaces(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _allPlaces = List.from(places);
          _isLoadingPlaces = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPlaces = false);
    }
  }

  /// Cached getter for filtered markers to avoid expensive rebuilds.
  List<MarkerData> get _filteredMarkers {
    // Compute hashes to detect changes
    final placesHash = Object.hashAll(_allPlaces.map((p) => p.id));
    final savingHash = Object.hashAll(_savingPlaceIds);
    final showLocal = _mapSettings.showLocalPlaces;

    // Return cached if nothing changed
    if (_cachedFilteredMarkers != null &&
        placesHash == _lastPlacesHash &&
        savingHash == _lastSavingIdsHash &&
        showLocal == _lastShowLocalPlaces) {
      return _cachedFilteredMarkers!;
    }

    // Rebuild and cache
    _lastPlacesHash = placesHash;
    _lastSavingIdsHash = savingHash;
    _lastShowLocalPlaces = showLocal;
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
      performBackgroundSave: (place) => _performBackgroundSave(place, encrypted: encrypted),
    );
  }

  Future<void> _performBackgroundSave(Place op, {bool encrypted = false}) async {
    await performPlaceBackgroundSave(
      originalPlace: op,
      context: context,
      allPlaces: _allPlaces,
      savingPlaceIds: _savingPlaceIds,
      setState: setState,
      encrypted: encrypted,
    );
  }

  void _onMapTap(TapPosition tp, LatLng ll) =>
      _showAddPlaceDialog(lat: ll.latitude, lng: ll.longitude);

  void _onMapPositionChanged(MapCamera pos, bool gesture) {
    onMapPositionChangedForNews(pos, gesture);
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
            onTap: _onMapTap,
            onLongPress: (tp, ll) =>
                _showAddPlaceDialog(lat: ll.latitude, lng: ll.longitude),
            onPositionChanged: _onMapPositionChanged,
            onDeletePlace: _confirmAndDeletePlace,
            context: context,
            initialCenter: _initialCenter,
            initialZoom: _initialZoom,
          ),
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
        ],
      ),
      floatingActionButton: MapFloatingButtons(
        isLoadingPlaces: _isLoadingPlaces,
        onZoomIn: () => zoomIn(mapController),
        onZoomOut: () => zoomOut(mapController),
        onRefresh: _loadAllPlaces,
      ),
    );
  }
}
