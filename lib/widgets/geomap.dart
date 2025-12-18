/// The primary map widget.
///
// Time-stamp: <Monday 2025-12-08 08:22:27 +1100 Graham Williams>
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:solidpod/solidpod.dart';
import 'package:solidui/solidui.dart';

import 'package:geopod/models/place.dart';
import 'package:geopod/services/gdelt_news_service.dart';
import 'package:geopod/services/geocoding_service.dart';
import 'package:geopod/services/map_settings_service.dart';
import 'package:geopod/services/places_service.dart'
    show PlacesService, PlacesCacheManager, placesChangeNotifier;
import 'package:geopod/widgets/add_place_form.dart';
import 'package:geopod/widgets/map/map_floating_buttons.dart';
import 'package:geopod/widgets/map/map_overlay_buttons.dart';
import 'package:geopod/widgets/map/marker_data.dart';
import 'package:geopod/widgets/map/marker_details_sheet.dart';
import 'package:geopod/widgets/map/marker_with_animation.dart';
import 'package:geopod/widgets/map/news_list_dialog.dart';
import 'package:geopod/widgets/map/news_marker_details_sheet.dart';
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
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
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
    if (mounted) {
      setState(() => _allPlaces = places);
    }
  }

  Future<void> _handleLogout() async {
    await PlacesService.clearPodCacheOnly();
    if (!mounted) return;
    _isPostLoginRefresh = false;
    _initialAnimationComplete = false;
    setState(() => _isLoggedIn = false);
    final localPlaces = await PlacesService.loadLocalPlaces();
    if (mounted) {
      setState(() => _allPlaces = localPlaces);
    }
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
      builder: (ctx) => MapSettingsDialog(
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
      if (mounted) {
        setState(() => _isLoadingPlaces = false);
      }
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
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Login Required'),
          content: const Text(
            'Please log in to add places to your collection.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                SolidAuthHandler.instance.handleLogin(ctx);
              },
              child: const Text('Login'),
            ),
          ],
        ),
      );
      return;
    }
    if (!mounted) return;
    final result = await showDialog<AddPlaceResult>(
      context: context,
      builder: (ctx) => AddPlaceForm(
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
            Expanded(child: Text('Saving "${p.displayTitle}"...')),
          ],
        ),
        backgroundColor: Colors.blue.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
    unawaited(_performBackgroundSave(p));
  }

  Future<void> _performBackgroundSave(Place op) async {
    try {
      final address = await GeocodingService.getAddress(op.lat, op.lng);
      final up = Place(
        id: op.id,
        lat: op.lat,
        lng: op.lng,
        note: op.note,
        timestamp: op.timestamp,
        address: address,
      );
      if (!mounted) return;
      final success = await PlacesService.addPlace(
        up,
        context,
        const GeoMapWidget(),
      );
      if (!mounted) return;
      if (success) {
        setState(() {
          final i = _allPlaces.indexWhere((x) => x.id == op.id);
          if (i != -1) {
            _allPlaces[i] = up;
          }
          _savingPlaceIds.remove(op.id);
        });
        PlacesCacheManager().cacheAllPlaces(_allPlaces);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Place saved successfully!')),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('WritePod failed');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _allPlaces.removeWhere((x) => x.id == op.id);
        _savingPlaceIds.remove(op.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Failed to save: $e')),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _onMapTap(TapPosition tp, LatLng ll) async {
    final webId = await getWebId();
    if (webId == null || webId.isEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Login Required'),
          content: const Text(
            'Please log in to add places to your collection.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                SolidAuthHandler.instance.handleLogin(ctx);
              },
              child: const Text('Login'),
            ),
          ],
        ),
      );
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
    setState(() {
      _isLoadingNews = true;
      _showNewsMarkers = true;
    });
    try {
      final bounds = _mapController.camera.visibleBounds;
      final nm = await _newsService.fetchNews(
        bounds: bounds,
        query: 'news',
        maxResults: 50,
        timeSpan: '24h',
      );
      if (mounted) {
        setState(() {
          _newsMarkers = nm;
          _isLoadingNews = false;
        });
        await showNewsListDialog(
          context: context,
          visibleNewsMarkers: _getVisibleNewsMarkers(),
          onCloseNews: () => setState(() {
            _showNewsMarkers = false;
            _newsMarkers = [];
          }),
          onNewsMarkerTap: (n) {
            _mapController.move(n.location, 12.0);
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                showNewsMarkerDetailsSheet(context, n);
              }
            });
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingNews = false;
          _showNewsMarkers = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch news: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _onMapPositionChanged(MapCamera pos, bool gesture) {
    if (_showNewsMarkers && gesture) _updateNewsFromCache();
  }

  void _updateNewsFromCache() {
    if (!mounted) return;
    final bounds = _mapController.camera.visibleBounds;
    final cached = _newsService.getMarkersInBounds(bounds);
    if (cached.isNotEmpty) {
      setState(() => _newsMarkers = cached);
    }
    if (!_newsService.isBoundsCovered(bounds)) {
      _fetchNewsForCurrentBounds();
    }
  }

  Future<void> _fetchNewsForCurrentBounds() async {
    if (!mounted) return;
    setState(() => _isLoadingNews = true);
    try {
      final bounds = _mapController.camera.visibleBounds;
      final nm = await _newsService.fetchNews(
        bounds: bounds,
        query: 'news',
        maxResults: 50,
        timeSpan: '24h',
      );
      if (mounted) {
        setState(() {
          _newsMarkers = nm;
          _isLoadingNews = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingNews = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch news: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  List<NewsMarker> _getVisibleNewsMarkers() {
    if (!_showNewsMarkers || _newsMarkers.isEmpty) return [];
    final b = _mapController.camera.visibleBounds;
    return _newsMarkers
        .where(
          (m) =>
              m.location.latitude >= b.south &&
              m.location.latitude <= b.north &&
              m.location.longitude >= b.west &&
              m.location.longitude <= b.east,
        )
        .toList();
  }

  Future<void> _confirmAndDeletePlace(MarkerData m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Place'),
        content: SingleChildScrollView(
          child: Text(
            'Are you sure you want to delete "${m.title}"?\n\nThis action cannot be undone.',
          ),
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
    final ri = _allPlaces.indexWhere((p) => p.id == m.id);
    if (ri == -1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Place not found'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    final rp = _allPlaces[ri];
    setState(() => _allPlaces.removeAt(ri));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Deleting place...'),
        duration: Duration(seconds: 1),
      ),
    );
    final success = await PlacesService.deletePlace(
      m.id,
      context,
      const GeoMapWidget(),
    );
    if (!mounted) return;
    if (success) {
      PlacesCacheManager().cacheAllPlaces(_allPlaces);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Place deleted successfully')),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        if (ri >= 0 && ri <= _allPlaces.length) {
          _allPlaces.insert(ri, rp);
        } else {
          _allPlaces.add(rp);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Failed to delete place')),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMapDark = _mapSettings.mapSource.isDarkSource;
    const midnightMatrix = <double>[
      -0.33,
      -0.33,
      -0.33,
      0,
      255,
      -0.33,
      -0.33,
      -0.33,
      0,
      255,
      -0.33,
      -0.33,
      -0.33,
      0,
      255,
      0,
      0,
      0,
      1,
      0,
    ];
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
                ColorFiltered(
                  colorFilter: applyFilter
                      ? const ColorFilter.matrix(midnightMatrix)
                      : const ColorFilter.mode(
                          Colors.transparent,
                          BlendMode.dst,
                        ),
                  child: TileLayer(
                    key: ValueKey(_mapSettings.mapSource),
                    urlTemplate: _mapSettings.mapSource.urlTemplate,
                    subdomains: _mapSettings.mapSource.subdomains,
                    userAgentPackageName: 'com.togaware.geopod',
                    tileProvider: _tileProvider,
                    evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
                    keepBuffer: 5,
                    panBuffer: 1,
                    maxZoom: 19,
                    maxNativeZoom: 18,
                    tileSize: 256,
                    retinaMode: false,
                    errorImage: const AssetImage(
                      'assets/images/tile_error.png',
                      package: 'solidpod',
                    ),
                  ),
                ),
                MarkerLayer(
                  markers: _filteredMarkers.asMap().entries.map((e) {
                    final i = e.key;
                    final m = e.value;
                    return Marker(
                      point: m.position,
                      width: 40,
                      height: 40,
                      child: MarkerWithAnimation(
                        index: i,
                        shouldAnimate:
                            !_initialAnimationComplete || _isPostLoginRefresh,
                        child: GestureDetector(
                          onTap: () => showMarkerDetailsSheet(
                            context,
                            m,
                            onDelete: () => _confirmAndDeletePlace(m),
                          ),
                          child: m.isSaving
                              ? Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 40,
                                      color: Colors.orange.shade400,
                                    ),
                                    const Positioned(
                                      top: 8,
                                      child: SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Icon(
                                  Icons.location_on,
                                  size: 40,
                                  color: m.color,
                                ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (_showNewsMarkers)
                  MarkerLayer(
                    markers: _getVisibleNewsMarkers()
                        .map(
                          (n) => Marker(
                            point: n.location,
                            width: 36,
                            height: 36,
                            child: GestureDetector(
                              onTap: () =>
                                  showNewsMarkerDetailsSheet(context, n),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade700,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.article,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
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
