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
import 'package:latlong2/latlong.dart';
import 'package:solidpod/solidpod.dart';
import 'package:solidui/solidui.dart';

import 'package:geopod/models/place.dart';
import 'package:geopod/services/gdelt_news_service.dart';
import 'package:geopod/services/map_settings_service.dart';
import 'package:geopod/services/places_service.dart'
    show PlacesCacheManager, placesChangeNotifier;
import 'package:geopod/widgets/map/delete_place_handler.dart';
import 'package:geopod/widgets/map/geomap_core.dart';
import 'package:geopod/widgets/map/geomap_state_logic.dart';
import 'package:geopod/widgets/map/map_floating_buttons.dart';
import 'package:geopod/widgets/map/map_overlay_buttons.dart';
import 'package:geopod/widgets/map/marker_data.dart';
import 'package:geopod/widgets/map/news_operations.dart';
import 'package:geopod/widgets/map/place_save_handler.dart';
import 'package:geopod/widgets/map_settings_dialog.dart';

class GeoMapWidget extends StatefulWidget {
  const GeoMapWidget({super.key});
  @override
  State<GeoMapWidget> createState() => GeoMapWidgetState();
}

class GeoMapWidgetState extends State<GeoMapWidget>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final MapController _mapController = MapController();
  TileProvider _tileProvider = NetworkTileProvider();
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
  final GdeltNewsService _newsService = GdeltNewsService();
  List<NewsMarker> _newsMarkers = [];
  bool _showNewsMarkers = false;
  bool _isLoadingNews = false;
  LatLng _initialCenter = const LatLng(defaultInitialLat, defaultInitialLng);
  double _initialZoom = defaultInitialZoom;
  bool _viewportInitialized = false;
  // Track last position to avoid unnecessary cache updates
  LatLng? _lastNewsUpdatePosition;
  double? _lastNewsUpdateZoom;

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
    _newsService.dispose();
    authStateNotifier.removeListener(_onAuthStateChanged);
    placesChangeNotifier.removeListener(_onPlacesChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Saves current viewport position if rememberViewport is enabled.
  void _saveCurrentViewport() {
    if (_mapSettings.rememberViewport) {
      final center = _mapController.camera.center;
      final zoom = _mapController.camera.zoom;
      MapSettingsService.saveLastViewport(
        lat: center.latitude,
        lng: center.longitude,
        zoom: zoom,
      );
    }
  }

  void _onPlacesChanged() {
    if (mounted && _isLoggedIn) _loadAllPlaces(forceRefresh: false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      setState(() => _tileProvider = NetworkTileProvider());
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
              _mapController.move(_initialCenter, _initialZoom);
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
            if (changed) _tileProvider = NetworkTileProvider();
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

  List<MarkerData> get _filteredMarkers => buildFilteredMarkers(
    allPlaces: _allPlaces,
    mapSettings: _mapSettings,
    savingPlaceIds: _savingPlaceIds,
  );

  Future<void> _showAddPlaceDialog({double? lat, double? lng}) async {
    final place = await showAddPlaceDialogIfLoggedIn(
      context: context,
      latitude: lat,
      longitude: lng,
    );
    if (place != null && mounted) _handleOptimisticSave(place);
  }

  void _handleOptimisticSave(Place p) {
    setState(() {
      _allPlaces.insert(0, p);
      _savingPlaceIds.add(p.id);
    });
    showSavingSnackbar(context, p);
    unawaited(_performBackgroundSave(p));
  }

  Future<void> _performBackgroundSave(Place op) async {
    try {
      final up = await performBackgroundSave(op, context);
      if (!mounted) return;
      if (up != null) {
        setState(() {
          final i = _allPlaces.indexWhere((x) => x.id == op.id);
          if (i != -1) _allPlaces[i] = up;
          _savingPlaceIds.remove(op.id);
        });
        PlacesCacheManager().cacheAllPlaces(_allPlaces);
        showSaveSuccessSnackbar(context);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _allPlaces.removeWhere((x) => x.id == op.id);
        _savingPlaceIds.remove(op.id);
      });
      showSaveErrorSnackbar(context, e);
    }
  }

  void _onMapTap(TapPosition tp, LatLng ll) =>
      _showAddPlaceDialog(lat: ll.latitude, lng: ll.longitude);

  void _toggleNewsMarkers() => _showNewsListDialogAsync();

  Future<void> _showNewsListDialogAsync() async {
    if (!mounted) return;
    await showNewsListDialogAsync(
      context: context,
      mapController: _mapController,
      newsService: _newsService,
      getVisibleMarkers: _getVisibleNewsMarkers,
      updateState: (m, l, s) {
        if (mounted) {
          setState(() {
            _newsMarkers = m;
            _isLoadingNews = l;
            _showNewsMarkers = s;
          });
        }
      },
    );
  }

  void _onMapPositionChanged(MapCamera pos, bool gesture) {
    if (_showNewsMarkers && gesture) {
      // Only update if position/zoom changed significantly
      if (_shouldUpdateNewsCache(pos.center, pos.zoom)) {
        _updateNewsFromCache();
      }
    }
  }

  /// Check if news cache should be updated based on position change
  bool _shouldUpdateNewsCache(LatLng newPosition, double newZoom) {
    // First time or no previous position
    if (_lastNewsUpdatePosition == null || _lastNewsUpdateZoom == null) {
      _lastNewsUpdatePosition = newPosition;
      _lastNewsUpdateZoom = newZoom;
      return true;
    }

    // Calculate position change in degrees
    final latDiff = (newPosition.latitude - _lastNewsUpdatePosition!.latitude)
        .abs();
    final lngDiff = (newPosition.longitude - _lastNewsUpdatePosition!.longitude)
        .abs();
    final zoomDiff = (newZoom - _lastNewsUpdateZoom!).abs();

    // Thresholds: ~1km movement or 1 zoom level change
    // At zoom 12, 0.01 degrees ≈ 1.1 km
    const positionThreshold = 0.01;
    const zoomThreshold = 1.0;

    final shouldUpdate =
        latDiff > positionThreshold ||
        lngDiff > positionThreshold ||
        zoomDiff > zoomThreshold;

    if (shouldUpdate) {
      _lastNewsUpdatePosition = newPosition;
      _lastNewsUpdateZoom = newZoom;
    }

    return shouldUpdate;
  }

  void _updateNewsFromCache() {
    if (!mounted) return;
    updateNewsFromCacheForBounds(
      mapController: _mapController,
      newsService: _newsService,
      setMarkers: (m) => setState(() => _newsMarkers = m),
      fetchForCurrentBounds: _fetchNewsForCurrentBounds,
    );
  }

  Future<void> _fetchNewsForCurrentBounds() async {
    if (!mounted) return;
    await fetchNewsForBounds(
      context: context,
      mapController: _mapController,
      newsService: _newsService,
      updateState: (m, l) {
        if (mounted) {
          setState(() {
            _newsMarkers = m;
            _isLoadingNews = l;
          });
        }
      },
    );
  }

  List<NewsMarker> _getVisibleNewsMarkers() => getVisibleNewsInBounds(
    mapController: _mapController,
    newsMarkers: _newsMarkers,
    showNews: _showNewsMarkers,
  );

  Future<void> _confirmAndDeletePlace(MarkerData m) async {
    final confirmed = await showDeleteConfirmationDialog(context, m);
    if (!confirmed || !mounted) return;
    final prep = prepareDeletePlace(marker: m, allPlaces: _allPlaces);
    if (!prep.success) {
      if (mounted) showPlaceNotFoundSnackbar(context);
      return;
    }
    setState(() => _allPlaces.removeAt(prep.removedIndex!));
    if (!mounted) return;
    showDeletingSnackbar(context);
    final success = await performDeleteOnServer(
      placeId: m.id,
      context: context,
    );
    if (!mounted) return;
    if (success) {
      updateCacheAfterDelete(_allPlaces);
      showDeleteSuccessSnackbar(context);
    } else {
      setState(
        () => restorePlace(
          allPlaces: _allPlaces,
          originalIndex: prep.removedIndex!,
          removedPlace: prep.removedPlace!,
        ),
      );
      showDeleteErrorSnackbar(context);
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
            mapController: _mapController,
            fadeAnimation: _fadeAnimation,
            mapSettings: _mapSettings,
            tileProvider: _tileProvider,
            applyFilter: applyFilter,
            filteredMarkers: _filteredMarkers,
            shouldAnimate: !_initialAnimationComplete || _isPostLoginRefresh,
            showNewsMarkers: _showNewsMarkers,
            visibleNewsMarkers: _getVisibleNewsMarkers(),
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
            isLoadingNews: _isLoadingNews,
            showNewsMarkers: _showNewsMarkers,
            visibleNewsCount: _getVisibleNewsMarkers().length,
            onTap: _toggleNewsMarkers,
          ),
        ],
      ),
      floatingActionButton: MapFloatingButtons(
        isLoadingPlaces: _isLoadingPlaces,
        onZoomIn: () => zoomIn(_mapController),
        onZoomOut: () => zoomOut(_mapController),
        onRefresh: _loadAllPlaces,
      ),
    );
  }
}
