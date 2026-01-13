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
import 'package:geopod/services/places/encrypted_places_service.dart';
import 'package:geopod/services/places_service.dart'
    show PlacesCacheManager, PlacesService, placesChangeNotifier;
import 'package:geopod/widgets/map/fullscreen_toggle_button.dart';
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
    _animationController.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        // Batch state updates to reduce rebuilds
        _initialAnimationComplete = true;
        _isPostLoginRefresh = false;
        // Only call setState if truly needed for UI
        if (_isLoadingPlaces) setState(() {});
      }
    });
    _isLoggedIn = authStateNotifier.value;
    authStateNotifier.addListener(_onAuthStateChanged);
    placesChangeNotifier.addListener(_onPlacesChanged);
    _loadSettingsSync();
    _verifyLoginStateAndLoadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      authStateNotifier.addListener(_onAuthStateChanged);
      placesChangeNotifier.addListener(_onPlacesChanged);
      _animationController.forward();
      // Defer settings loading slightly to not block animation
      Future.microtask(() {
        if (mounted) _loadSettingsSync();
      });
      // Defer login verification even more
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) _verifyLoginStateAndLoadData();
      });
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
    // Immediately show local places for better UX
    setState(() {
      _isLoggedIn = true;
      _allPlaces = PlacesService.getLocalPlacesSync();
    });
    // Load pod data in background without blocking UI
    unawaited(_loadPodDataInBackground());
  }

  Future<void> _loadPodDataInBackground() async {
    try {
      final places = await handleLoginStateChange(
        wasLoggedIn: false,
        isNowLoggedIn: true,
      );
      if (mounted) setState(() => _allPlaces = places);
    } catch (_) {
      // Silently handle errors - local places are already shown
    }
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
    // Load settings from SharedPreferences only (fast, no network)
    MapSettingsService.loadSettings()
        .then((s) {
          if (!mounted) return;
          // Update settings immediately - don't wait for viewport
          setState(() => _mapSettings = s);

          // If showEncryptedPlaces is enabled from saved settings, validate it
          // This will be handled after login verification in _validateSavedEncryptedSetting
          if (s.showEncryptedPlaces) {
            // Defer validation until after login state is verified
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) _validateSavedEncryptedSetting();
            });
          }

          // Load viewport separately, but don't block map display
          if (!_viewportInitialized) {
            MapSettingsService.getStartupViewport(s)
                .then((viewport) {
                  if (!mounted) return;
                  final newCenter = LatLng(viewport.lat, viewport.lng);
                  final newZoom = viewport.zoom;
                  setState(() {
                    _initialCenter = newCenter;
                    _initialZoom = newZoom;
                    _viewportInitialized = true;
                  });
                  // Move map after state update
                  mapController.move(newCenter, newZoom);
                })
                .catchError((_) {});
          }
        })
        .catchError((_) {});
  }

  /// Validates the saved encrypted places setting.
  /// If showEncryptedPlaces was enabled in settings but security key is not
  /// available, this will prompt the user to enter their security key.
  /// If user cancels or key is not available, the setting will be reset.
  /// NOTE: This method assumes encrypted places will be loaded separately
  /// by _loadAllPlaces if includeEncrypted is true - it only handles
  /// security key validation and prompting.
  Future<void> _validateSavedEncryptedSetting() async {
    if (!_mapSettings.showEncryptedPlaces) return;
    if (!_isLoggedIn) {
      // Not logged in, reset the setting (can't use encrypted places)
      setState(() {
        _mapSettings = _mapSettings.copyWith(showEncryptedPlaces: false);
      });
      return;
    }

    // Check if encrypted places are already loaded (by _loadAllPlaces)
    final hasEncryptedPlaces = _allPlaces.any((p) => p.isEncrypted);
    if (hasEncryptedPlaces) {
      debugPrint(
        '_validateSavedEncryptedSetting: encrypted places already loaded, skipping',
      );
      return;
    }

    // Check if security key is already available
    final hasKey = await EncryptedPlacesService.isSecurityKeyAvailable();
    if (hasKey) {
      // Security key is available, load encrypted places
      debugPrint(
        '_validateSavedEncryptedSetting: has key, loading encrypted places',
      );
      unawaited(_loadEncryptedPlaces());
    } else {
      // Security key not available, need to prompt user
      debugPrint('_validateSavedEncryptedSetting: no key, prompting user');
      unawaited(_loadEncryptedPlaces());
    }
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
      setState(() {
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

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (_) => MapSettingsDialog(
        currentSettings: _mapSettings,
        onSettingsChanged: (ns) {
          final encryptedToggled =
              _mapSettings.showEncryptedPlaces != ns.showEncryptedPlaces;
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
          // Load encrypted places if newly enabled
          // Skip key verification since settings dialog already verified it
          if (encryptedToggled && ns.showEncryptedPlaces) {
            unawaited(_loadEncryptedPlaces(skipKeyVerification: true));
          } else if (encryptedToggled && !ns.showEncryptedPlaces) {
            // Remove encrypted places from display
            setState(() {
              _allPlaces.removeWhere((p) => p.isEncrypted);
            });
          }
        },
      ),
    );
  }

  void showSettingsDialog() => _showSettingsDialog();

  Future<void> _loadAllPlaces({
    bool forceRefresh = false,
    bool? includeEncrypted,
  }) async {
    final cm = PlacesCacheManager();
    final showLoading = cm.allPlaces == null;
    if (showLoading && mounted) {
      setState(() => _isLoadingPlaces = true);
    }
    try {
      final places = await loadAllPlaces(
        forceRefresh: forceRefresh,
        includeEncrypted: includeEncrypted ?? _mapSettings.showEncryptedPlaces,
      );
      if (mounted) {
        // Check if data actually changed to avoid unnecessary rebuild
        final hasChanges =
            _allPlaces.length != places.length ||
            !_allPlaces.every((p) => places.any((np) => np.id == p.id));
        if (hasChanges || _isLoadingPlaces) {
          setState(() {
            _allPlaces = List.from(places);
            _isLoadingPlaces = false;
          });
        }
      }
    } catch (_) {
      if (mounted && _isLoadingPlaces) {
        setState(() => _isLoadingPlaces = false);
      }
    }
  }

  /// Load encrypted places on demand when user enables the setting.
  /// If [skipKeyVerification] is true, assumes security key is already verified.
  Future<void> _loadEncryptedPlaces({bool skipKeyVerification = false}) async {
    if (!_isLoggedIn || !mounted) return;

    if (!skipKeyVerification) {
      // Ensure security key is available (will prompt user if needed)
      final hasKey = await EncryptedPlacesService.ensureSecurityKey(
        context,
        widget,
      );
      if (!hasKey) {
        // User cancelled or key not available, revert setting
        if (mounted) {
          setState(() {
            _mapSettings = _mapSettings.copyWith(showEncryptedPlaces: false);
          });
          MapSettingsService.saveSettings(_mapSettings);
        }
        return;
      }
    }

    try {
      debugPrint('Loading encrypted places...');
      final encryptedPlaces = await PlacesService.fetchEncryptedPlaces(
        forceRefresh: true,
      );
      debugPrint(
        'Fetched ${encryptedPlaces.length} encrypted places, '
        'isEncrypted flags: ${encryptedPlaces.map((p) => p.isEncrypted).toList()}',
      );
      if (mounted && encryptedPlaces.isNotEmpty) {
        setState(() {
          // Remove any existing encrypted places first
          _allPlaces.removeWhere((p) => p.isEncrypted);
          // Add newly loaded encrypted places
          _allPlaces.addAll(encryptedPlaces);
          debugPrint(
            'All places now: ${_allPlaces.length}, '
            'encrypted count: ${_allPlaces.where((p) => p.isEncrypted).length}',
          );
        });
      }
    } catch (e) {
      debugPrint('Error loading encrypted places: $e');
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
        setState(() {
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
      performBackgroundSave: (place) =>
          _performBackgroundSave(place, encrypted: encrypted),
      encrypted: encrypted,
    );
  }

  Future<void> _performBackgroundSave(
    Place op, {
    bool encrypted = false,
  }) async {
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
