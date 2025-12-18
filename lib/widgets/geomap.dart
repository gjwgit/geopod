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
    show PlacesService, PlacesCacheManager, placesChangeNotifier;
import 'package:geopod/widgets/add_place_form.dart';
import 'package:geopod/widgets/map/delete_place_handler.dart';
import 'package:geopod/widgets/map/login_required_dialog.dart';
import 'package:geopod/widgets/map/map_floating_buttons.dart';
import 'package:geopod/widgets/map/map_overlay_buttons.dart';
import 'package:geopod/widgets/map/map_tile_layer.dart';
import 'package:geopod/widgets/map/marker_data.dart';
import 'package:geopod/widgets/map/news_marker_layer.dart';
import 'package:geopod/widgets/map/news_operations.dart';
import 'package:geopod/widgets/map/place_save_handler.dart';
import 'package:geopod/widgets/map/places_marker_layer.dart';
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
    _animationController.dispose();
    _newsService.dispose();
    authStateNotifier.removeListener(_onAuthStateChanged);
    placesChangeNotifier.removeListener(_onPlacesChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onPlacesChanged() {
    if (mounted && _isLoggedIn) _loadAllPlaces(forceRefresh: false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      setState(() => _tileProvider = NetworkTileProvider());
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
    final places = await PlacesService.refreshPodDataOnly();
    if (mounted) setState(() => _allPlaces = places);
  }

  Future<void> _handleLogout() async {
    await PlacesService.clearPodCacheOnly();
    if (!mounted) return;
    _isPostLoginRefresh = false;
    _initialAnimationComplete = false;
    setState(() => _isLoggedIn = false);
    final localPlaces = await PlacesService.loadLocalPlaces();
    if (mounted) setState(() => _allPlaces = localPlaces);
  }

  void _loadSettingsSync() {
    MapSettingsService.loadSettings()
        .then((s) {
          if (mounted) setState(() => _mapSettings = s);
        })
        .catchError((_) {});
  }

  Future<void> _verifyLoginStateAndLoadData() async {
    final actuallyLoggedIn = await checkLoggedIn();
    if (!mounted) return;
    if (_isLoggedIn != actuallyLoggedIn) {
      setState(() => _isLoggedIn = actuallyLoggedIn);
      authStateNotifier.value = actuallyLoggedIn;
      PlacesService.clearCache();
    }
    final cm = PlacesCacheManager();
    final cached = cm.allPlaces;
    final cacheState = cm.wasLoggedInWhenCached;
    if (cached != null && cacheState == _isLoggedIn) {
      setState(() => _allPlaces = List.from(cached));
    } else {
      if (cached != null && cacheState != _isLoggedIn) {
        PlacesService.clearCache();
      }
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
      final places = await PlacesService.fetchPlaces(
        forceRefresh: forceRefresh,
      );
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

  List<MarkerData> get _filteredMarkers {
    final visible = _mapSettings.showLocalPlaces
        ? _allPlaces
        : _allPlaces.where((p) => !p.isLocal).toList();
    return visible
        .map(
          (p) => MarkerData(
            id: p.id,
            position: LatLng(p.lat, p.lng),
            title: p.displayTitle,
            description: p.note,
            address: p.address,
            isLocal: p.isLocal,
            isSaving: _savingPlaceIds.contains(p.id),
            color: p.isLocal
                ? _mapSettings.localPlacesColor
                : _mapSettings.userPlacesColor,
          ),
        )
        .toList();
  }

  Future<void> _showAddPlaceDialog({
    double? latitude,
    double? longitude,
  }) async {
    final webId = await getWebId();
    if (webId == null || webId.isEmpty) {
      if (!mounted) return;
      await showLoginRequiredDialog(context);
      return;
    }
    if (!mounted) return;
    final result = await showDialog<AddPlaceResult>(
      context: context,
      builder: (_) => AddPlaceForm(
        initialLatitude: latitude,
        initialLongitude: longitude,
        returnWidget: const GeoMapWidget(),
      ),
    );
    if (result != null && mounted) _handleOptimisticSave(result.place);
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

  void _onMapTap(TapPosition tp, LatLng ll) async {
    final webId = await getWebId();
    if (webId == null || webId.isEmpty) {
      if (!mounted) return;
      showLoginRequiredDialog(context);
      return;
    }
    _showAddPlaceDialog(latitude: ll.latitude, longitude: ll.longitude);
  }

  void _zoomIn() {
    final z = _mapController.camera.zoom;
    _mapController.move(
      _mapController.camera.center,
      (z + 0.6).clamp(3.0, 18.0),
    );
  }

  void _zoomOut() {
    final z = _mapController.camera.zoom;
    _mapController.move(
      _mapController.camera.center,
      (z - 0.6).clamp(3.0, 18.0),
    );
  }

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
    if (_showNewsMarkers && gesture) _updateNewsFromCache();
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
    final ri = _allPlaces.indexWhere((p) => p.id == m.id);
    if (ri == -1) {
      if (mounted) showPlaceNotFoundSnackbar(context);
      return;
    }
    final rp = _allPlaces[ri];
    setState(() => _allPlaces.removeAt(ri));
    if (!mounted) return;
    showDeletingSnackbar(context);
    final success = await PlacesService.deletePlace(
      m.id,
      context,
      const GeoMapWidget(),
    );
    if (!mounted) return;
    if (success) {
      PlacesCacheManager().cacheAllPlaces(_allPlaces);
      showDeleteSuccessSnackbar(context);
    } else {
      setState(() {
        if (ri >= 0 && ri <= _allPlaces.length) {
          _allPlaces.insert(ri, rp);
        } else {
          _allPlaces.add(rp);
        }
      });
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
          FadeTransition(
            opacity: _fadeAnimation,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(-12.46, 130.84),
                initialZoom: 13.0,
                minZoom: 3.0,
                maxZoom: 18.0,
                onTap: _onMapTap,
                onLongPress: (tp, ll) => _showAddPlaceDialog(
                  latitude: ll.latitude,
                  longitude: ll.longitude,
                ),
                onPositionChanged: _onMapPositionChanged,
              ),
              children: [
                buildMapTileLayer(
                  mapSettings: _mapSettings,
                  tileProvider: _tileProvider,
                  applyFilter: applyFilter,
                ),
                buildPlacesMarkerLayer(
                  context: context,
                  markers: _filteredMarkers,
                  shouldAnimate:
                      !_initialAnimationComplete || _isPostLoginRefresh,
                  onDelete: _confirmAndDeletePlace,
                ),
                if (_showNewsMarkers)
                  buildNewsMarkerLayer(
                    context: context,
                    newsMarkers: _getVisibleNewsMarkers(),
                  ),
              ],
            ),
          ),
          if (_isLoadingPlaces)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: Colors.green,
              ),
            ),
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
        onZoomIn: _zoomIn,
        onZoomOut: _zoomOut,
        onRefresh: _loadAllPlaces,
      ),
    );
  }
}
