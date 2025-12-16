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
import 'package:url_launcher/url_launcher.dart';

import 'package:geopod/services/gdelt_news_service.dart';
import 'package:geopod/services/geocoding_service.dart';
import 'package:geopod/services/map_settings_service.dart';
import 'package:geopod/services/places_service.dart'
    show PlacesService, Place, PlacesCacheManager, placesChangeNotifier;
import 'package:geopod/widgets/add_place_form.dart';
import 'package:geopod/widgets/map_settings_dialog.dart';

/// A map widget displaying points of interest with the ability to add new places.
///
/// Features:
/// - Optimistic updates: Places appear instantly before save completes
/// - Background saving: Geocoding + writePod happens without blocking UI
/// - Pre-loaded data: Places are fetched once and cached for instant access
class GeoMapWidget extends StatefulWidget {
  const GeoMapWidget({super.key});

  @override
  State<GeoMapWidget> createState() => GeoMapWidgetState();
}

class GeoMapWidgetState extends State<GeoMapWidget>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final MapController _mapController = MapController();

  /// Tile provider instance for downloading map tiles
  /// Recreated when app resumes from background to avoid connection issues
  /// Using NetworkTileProvider (built-in) instead of CancellableNetworkTileProvider
  /// to avoid Dio adapter closure problems on Android
  TileProvider _tileProvider = NetworkTileProvider();

  /// All places (local + Pod) loaded and cached for instant access.
  List<Place> _allPlaces = [];

  /// IDs of places currently being saved in background.
  final Set<String> _savingPlaceIds = {};

  /// Whether initial load is in progress.
  bool _isLoadingPlaces = false;

  /// Map display settings (colors, visibility, map source).
  MapSettings _mapSettings = MapSettings(
    mapSource: MapSettings.getDefaultMapSource(),
  );

  /// Track user login status for UI updates
  bool _isLoggedIn = false;

  /// Animation controller for smooth map entrance
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  /// Track if initial animation has completed
  bool _initialAnimationComplete = false;

  /// Track if this is a post-login data refresh (to replay animations)
  bool _isPostLoginRefresh = false;

  /// GDELT news service for fetching geospatial news
  final GdeltNewsService _newsService = GdeltNewsService();

  /// List of news markers fetched from GDELT API
  List<NewsMarker> _newsMarkers = [];

  /// Whether news markers should be displayed on the map
  bool _showNewsMarkers = false;

  /// Whether news data is currently being fetched
  bool _isLoadingNews = false;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller for smooth entrance (300ms)
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Create fade-in animation with smooth curve
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    // Mark animation as complete when done
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _initialAnimationComplete = true;
          _isPostLoginRefresh = false; // Clear post-login flag after animation
        });
      }
    });

    // Check initial login state synchronously (fast but may be stale)
    _isLoggedIn = AuthDataManager.isLoggedInSync();

    // Listen for login/logout events
    authStateNotifier.addListener(_onAuthStateChanged);

    // Listen for places data changes (add/delete/update)
    placesChangeNotifier.addListener(_onPlacesChanged);

    // Load settings SYNCHRONOUSLY from cache (should be preloaded on app startup)
    // This ensures UI renders with correct settings immediately, not defaults
    _loadSettingsSync();

    // CRITICAL: Verify login state asynchronously after app restart
    // This handles the case where app was killed in background and token expired
    _verifyLoginStateAndLoadData();

    // Start fade-in animation after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
      }
    });

    // Register lifecycle observer to handle app resume/pause
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

  /// Called when places data changes (add/delete/update)
  void _onPlacesChanged() {
    if (mounted && _isLoggedIn) {
      // Places data changed - try to use cache first (faster)
      // Cache was cleared by the operation, so next load will fetch fresh data
      _loadAllPlaces(forceRefresh: false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Recreate tile provider when app resumes from background
    // This fixes connection issues on Android after app pause/resume
    if (state == AppLifecycleState.resumed) {
      setState(() {
        _tileProvider = NetworkTileProvider();
      });
    }
  }

  /// Called when auth state changes (login/logout)
  void _onAuthStateChanged() {
    if (mounted) {
      final wasLoggedIn = _isLoggedIn;
      final isNowLoggedIn = authStateNotifier.value;

      // Only react if state actually changed
      if (isNowLoggedIn == wasLoggedIn) {
        return; // No change, preserve cache
      }

      setState(() {
        _isLoggedIn = isNowLoggedIn;
      });

      // After login, clear guest cache and reload user's Pod data
      if (isNowLoggedIn && !wasLoggedIn) {
        _handleLogin();
      } else if (!isNowLoggedIn && wasLoggedIn) {
        _handleLogout();
      }
    }
  }

  /// Handles login: incrementally loads user's Pod data (keeps local places cached)
  /// This is much faster than full refresh because local places are already cached.
  Future<void> _handleLogin() async {
    if (mounted) {
      // Prepare for smooth transition with animation
      _isPostLoginRefresh = true;
      _initialAnimationComplete = false; // Allow markers to animate again

      // Update login state immediately (UI shows logged-in state)
      setState(() {
        _isLoggedIn = true;
      });

      // Incrementally load Pod data while keeping local places cached
      // This is much faster than clearCache + forceRefresh
      final places = await PlacesService.refreshPodDataOnly();

      if (mounted) {
        setState(() {
          _allPlaces = places;
        });
      }
    }
  }

  /// Handles logout: clears Pod cache and shows local places only
  Future<void> _handleLogout() async {
    // User logged out - clear Pod cache only, keep local places cached
    await PlacesService.clearPodCacheOnly();

    if (mounted) {
      _isPostLoginRefresh = false;
      _initialAnimationComplete = false;

      // Update login state immediately
      setState(() {
        _isLoggedIn = false; // CRITICAL: Mark as logged out
      });

      // Load local places only (instant from cache)
      final localPlaces = await PlacesService.loadLocalPlaces();
      if (mounted) {
        setState(() {
          _allPlaces = localPlaces;
        });
      }
    }
  }

  /// Loads map settings SYNCHRONOUSLY from cache.
  /// Should be instant since settings are preloaded on app startup.
  void _loadSettingsSync() {
    // Use fire-and-forget async call but apply immediately when ready
    MapSettingsService.loadSettings()
        .then((settings) {
          if (mounted) {
            setState(() => _mapSettings = settings);
          }
        })
        .catchError((_) {
          // Ignore errors - will use default settings
        });
  }

  /// Verifies actual login state asynchronously and loads appropriate data.
  /// This is critical for handling app restarts after being killed in background.
  Future<void> _verifyLoginStateAndLoadData() async {
    // Verify actual login state (checks token expiry)
    final actuallyLoggedIn = await checkLoggedIn();

    if (!mounted) return;

    // Check if sync state was wrong (e.g., app killed in background, token expired)
    if (_isLoggedIn != actuallyLoggedIn) {
      setState(() {
        _isLoggedIn = actuallyLoggedIn;
      });

      // Update global auth state
      authStateNotifier.value = actuallyLoggedIn;

      // Clear stale cache immediately
      PlacesService.clearCache();
    }

    // Now check cache with verified login state
    final cacheManager = PlacesCacheManager();
    final cachedPlaces = cacheManager.allPlaces;
    final cacheLoginState = cacheManager.wasLoggedInWhenCached;

    // Use cache only if login state matches
    if (cachedPlaces != null && cacheLoginState == _isLoggedIn) {
      setState(() {
        _allPlaces = List.from(cachedPlaces);
      });
    } else {
      // No cache OR auth state mismatch - clear and reload
      if (cachedPlaces != null && cacheLoginState != _isLoggedIn) {
        PlacesService.clearCache();
      }
      // Load fresh data
      await _loadAllPlaces(forceRefresh: true);
    }
  }

  /// Shows the settings dialog.
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => MapSettingsDialog(
        currentSettings: _mapSettings,
        onSettingsChanged: (newSettings) {
          setState(() {
            // Check if map source changed - need new tile provider
            final mapSourceChanged =
                _mapSettings.mapSource != newSettings.mapSource;
            _mapSettings = newSettings;

            // Recreate tile provider when map source changes
            // This prevents "Client is already closed" errors
            if (mapSourceChanged) {
              _tileProvider = NetworkTileProvider();
            }
          });
        },
      ),
    );
  }

  /// Public method to show settings dialog (called from app bar).
  void showSettingsDialog() {
    _showSettingsDialog();
  }

  /// Loads all places (local + Pod) using cache-aware fetch.
  /// This will be instant if data is already cached in memory.
  Future<void> _loadAllPlaces({bool forceRefresh = false}) async {
    // Skip loading indicator if cache is warm (instant response expected)
    final cacheManager = PlacesCacheManager();
    final hasCache = cacheManager.allPlaces != null;

    if (!hasCache) {
      setState(() => _isLoadingPlaces = true);
    }

    try {
      // Use cache-aware fetch - instant if cached, slow if not
      final places = await PlacesService.fetchPlaces(
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          // Create a mutable copy to avoid reference issues
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

  /// Returns filtered markers based on visibility settings.
  ///
  /// Color scheme (customizable via settings):
  /// - Local (canned examples): localPlacesColor (default: Orange)
  /// - Pod (user data): userPlacesColor (default: Blue)
  /// - Saving in progress: Orange with spinner
  List<MarkerData> get _filteredMarkers {
    // Filter places based on visibility settings.
    final visiblePlaces = _mapSettings.showLocalPlaces
        ? _allPlaces
        : _allPlaces.where((p) => !p.isLocal).toList();

    return visiblePlaces
        .map(
          (place) => MarkerData(
            id: place.id,
            position: LatLng(place.lat, place.lng),
            title: place.displayTitle,
            description: place.note,
            address: place.address,
            isLocal: place.isLocal,
            isSaving: _savingPlaceIds.contains(place.id),
            // Use custom colors from settings.
            color: place.isLocal
                ? _mapSettings.localPlacesColor
                : _mapSettings.userPlacesColor,
          ),
        )
        .toList();
  }

  /// Shows the Add Place dialog with optional pre-filled coordinates.
  Future<void> _showAddPlaceDialog({
    double? latitude,
    double? longitude,
  }) async {
    // Check if user is logged in
    final webId = await getWebId();
    if (webId == null || webId.isEmpty) {
      // Show dialog prompting user to login
      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Login Required'),
          content: const Text(
            'Please log in to add places to your collection.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                SolidAuthHandler.instance.handleLogin(context);
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
      builder: (context) => AddPlaceForm(
        initialLatitude: latitude,
        initialLongitude: longitude,
        returnWidget: const GeoMapWidget(),
      ),
    );

    if (result != null && mounted) {
      _handleOptimisticSave(result.place);
    }
  }

  /// Handles optimistic update and background save.
  void _handleOptimisticSave(Place optimisticPlace) {
    // Add to local list immediately (at the beginning, before local places).
    setState(() {
      _allPlaces.insert(0, optimisticPlace);
      _savingPlaceIds.add(optimisticPlace.id);
    });

    // Show feedback snackbar.
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
            Expanded(
              child: Text('Saving "${optimisticPlace.displayTitle}"...'),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );

    // Fire background task.
    unawaited(_performBackgroundSave(optimisticPlace));
  }

  /// Performs the heavy save operations in background.
  Future<void> _performBackgroundSave(Place optimisticPlace) async {
    try {
      // Geocoding.
      final address = await GeocodingService.getAddress(
        optimisticPlace.lat,
        optimisticPlace.lng,
      );

      // Create updated place with real address.
      final updatedPlace = Place(
        id: optimisticPlace.id,
        lat: optimisticPlace.lat,
        lng: optimisticPlace.lng,
        note: optimisticPlace.note,
        timestamp: optimisticPlace.timestamp,
        address: address,
      );

      // Check mounted before using context.
      if (!mounted) return;

      // Write to Pod.
      final success = await PlacesService.addPlace(
        updatedPlace,
        context,
        const GeoMapWidget(),
      );

      if (!mounted) return;

      if (success) {
        setState(() {
          final index = _allPlaces.indexWhere(
            (p) => p.id == optimisticPlace.id,
          );
          if (index != -1) {
            _allPlaces[index] = updatedPlace;
          }
          _savingPlaceIds.remove(optimisticPlace.id);
        });

        // Update in-memory cache so LocationsPage sees the new data immediately
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
        _allPlaces.removeWhere((p) => p.id == optimisticPlace.id);
        _savingPlaceIds.remove(optimisticPlace.id);
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

  /// Shows options when user taps on the map.
  void _onMapTap(TapPosition tapPosition, LatLng latLng) async {
    // Check if user is logged in
    final webId = await getWebId();
    if (webId == null || webId.isEmpty) {
      // Show dialog prompting user to login
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Login Required'),
          content: const Text(
            'Please log in to add places to your collection.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                SolidAuthHandler.instance.handleLogin(context);
              },
              child: const Text('Login'),
            ),
          ],
        ),
      );
      return;
    }

    _showAddPlaceDialog(latitude: latLng.latitude, longitude: latLng.longitude);
  }

  /// Zooms in the map by one level.
  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    final newZoom = (currentZoom + 0.6).clamp(3.0, 18.0);
    _mapController.move(_mapController.camera.center, newZoom);
  }

  /// Zooms out the map by one level.
  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    final newZoom = (currentZoom - 0.6).clamp(3.0, 18.0);
    _mapController.move(_mapController.camera.center, newZoom);
  }

  /// Toggles the display of news markers on the map.
  void _toggleNewsMarkers() {
    // Always show the news list dialog when clicked
    _showNewsListDialog();
  }

  /// Shows a dialog with the list of all news in current view.
  Future<void> _showNewsListDialog() async {
    // Fetch news first
    setState(() {
      _isLoadingNews = true;
      _showNewsMarkers = true;
    });

    try {
      final bounds = _mapController.camera.visibleBounds;
      final newsMarkers = await _newsService.fetchNews(
        bounds: bounds,
        query: 'news',
        maxResults: 50,
        timeSpan: '24h',
      );

      if (mounted) {
        setState(() {
          _newsMarkers = newsMarkers;
          _isLoadingNews = false;
        });

        // Show the list dialog
        showDialog(
          context: context,
          builder: (dialogContext) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: 500,
              height: 600,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        Icons.article,
                        color: Colors.blue.shade700,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'News in Current View',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          // Only close dialog, keep news markers visible
                          Navigator.of(dialogContext).pop();
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Text(
                    '${_getVisibleNewsMarkers().length} news items in current view',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  // News list
                  Expanded(
                    child: _getVisibleNewsMarkers().isEmpty
                        ? Center(
                            child: Text(
                              'No news found in this area',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _getVisibleNewsMarkers().length,
                            itemBuilder: (context, index) {
                              final news = _getVisibleNewsMarkers()[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue.shade700,
                                    child: const Icon(
                                      Icons.article,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    news.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      if (news.source != null)
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.public,
                                              size: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                news.source!,
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.location_on,
                                            size: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${news.location.latitude.toStringAsFixed(2)}, ${news.location.longitude.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: news.url != null
                                      ? IconButton(
                                          icon: const Icon(Icons.open_in_new),
                                          onPressed: () =>
                                              _launchUrl(news.url!),
                                          tooltip: 'Read Article',
                                        )
                                      : null,
                                  onTap: () {
                                    Navigator.of(dialogContext).pop();
                                    // Zoom to news location
                                    _mapController.move(news.location, 12.0);
                                    // Show details
                                    Future.delayed(
                                      const Duration(milliseconds: 300),
                                      () {
                                        _showNewsMarkerDetails(news);
                                      },
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        // Close news feature completely
                        setState(() {
                          _showNewsMarkers = false;
                          _newsMarkers = [];
                        });
                      },
                      icon: const Icon(Icons.close),
                      label: const Text('Close News'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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

  /// Fetches news markers for the current map viewport bounds.
  Future<void> _fetchNewsForCurrentBounds() async {
    if (!mounted) return;

    setState(() {
      _isLoadingNews = true;
    });

    try {
      // Get current map bounds
      final bounds = _mapController.camera.visibleBounds;

      debugPrint('=== Fetching news for map bounds ===');
      debugPrint('Southwest: ${bounds.south}, ${bounds.west}');
      debugPrint('Northeast: ${bounds.north}, ${bounds.east}');
      debugPrint(
        'Center: ${bounds.center.latitude}, ${bounds.center.longitude}',
      );

      // Fetch news from GDELT API with debouncing
      // Note: GDELT requires actual keywords, not '*'
      final newsMarkers = await _newsService.fetchNews(
        bounds: bounds,
        query: 'news', // Use 'news' as default query
        maxResults: 50, // Reduced from 250 to avoid timeout
        timeSpan: '24h',
      );

      debugPrint('Received ${newsMarkers.length} news markers');
      if (newsMarkers.isNotEmpty) {
        debugPrint(
          'First marker: ${newsMarkers[0].title} at ${newsMarkers[0].location.latitude}, ${newsMarkers[0].location.longitude}',
        );
      }

      if (mounted) {
        setState(() {
          _newsMarkers = newsMarkers;
          _isLoadingNews = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingNews = false;
        });
        // Show error message to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch news: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  /// Called when map position changes (zoom or pan).
  void _onMapPositionChanged(MapCamera position, bool hasGesture) {
    // Only fetch news if news markers are enabled
    if (_showNewsMarkers && hasGesture) {
      // Try to use cached data first
      _updateNewsFromCache();
    }
  }

  /// Update news markers from cache or fetch if needed.
  void _updateNewsFromCache() {
    if (!mounted) return;

    final bounds = _mapController.camera.visibleBounds;

    // First, try to get markers from cache
    final cachedMarkers = _newsService.getMarkersInBounds(bounds);

    if (cachedMarkers.isNotEmpty) {
      // Update UI with cached markers immediately
      setState(() {
        _newsMarkers = cachedMarkers;
      });
      debugPrint('Updated ${cachedMarkers.length} news markers from cache');
    }

    // If bounds are not covered by cache, fetch new data
    if (!_newsService.isBoundsCovered(bounds)) {
      debugPrint('Bounds not fully covered, fetching new data...');
      _fetchNewsForCurrentBounds();
    }
  }

  /// Get list of news markers that are currently visible on screen.
  List<NewsMarker> _getVisibleNewsMarkers() {
    if (!_showNewsMarkers || _newsMarkers.isEmpty) return [];

    final bounds = _mapController.camera.visibleBounds;
    return _newsMarkers.where((marker) {
      return marker.location.latitude >= bounds.south &&
          marker.location.latitude <= bounds.north &&
          marker.location.longitude >= bounds.west &&
          marker.location.longitude <= bounds.east;
    }).toList();
  }

  /// Shows detailed information about a news marker in a bottom sheet.
  void _showNewsMarkerDetails(NewsMarker newsMarker) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with news icon
            Row(
              children: [
                Icon(
                  Icons.article_outlined,
                  color: Colors.blue.shade700,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'News Article',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // News title
            Text(
              newsMarker.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            // Source and date
            if (newsMarker.source != null || newsMarker.publishedAt != null)
              Row(
                children: [
                  if (newsMarker.source != null) ...[
                    Icon(Icons.public, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      newsMarker.source!,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  if (newsMarker.source != null &&
                      newsMarker.publishedAt != null)
                    Text(' • ', style: TextStyle(color: Colors.grey.shade600)),
                  if (newsMarker.publishedAt != null) ...[
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDateTime(newsMarker.publishedAt!),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),

            // Tone indicator
            if (newsMarker.tone != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    newsMarker.tone! > 0
                        ? Icons.sentiment_satisfied
                        : newsMarker.tone! < 0
                        ? Icons.sentiment_dissatisfied
                        : Icons.sentiment_neutral,
                    size: 16,
                    color: newsMarker.tone! > 0
                        ? Colors.green
                        : newsMarker.tone! < 0
                        ? Colors.red
                        : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Tone: ${newsMarker.tone!.toStringAsFixed(1)}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // Location info
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${newsMarker.location.latitude.toStringAsFixed(4)}, ${newsMarker.location.longitude.toStringAsFixed(4)}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Close'),
                ),
                if (newsMarker.url != null) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _launchUrl(newsMarker.url!);
                    },
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Read Article'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Format DateTime for display.
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    }
  }

  /// Launch URL in browser.
  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch URL');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open article: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  /// Shows detailed information about a marker in a bottom sheet.
  void _showMarkerDetails(MarkerData marker) {
    // Use marker's custom color for UI elements.
    final markerColor = marker.color;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: marker.isSaving
                        ? Colors.orange.shade50
                        : markerColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: marker.isSaving
                      ? SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.orange.shade600,
                          ),
                        )
                      : Icon(Icons.place, color: markerColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        marker.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (marker.isSaving)
                        Text(
                          'Saving...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade600,
                          ),
                        )
                      else if (marker.isLocal)
                        Text(
                          'Example Location',
                          style: TextStyle(fontSize: 12, color: markerColor),
                        )
                      else
                        Text(
                          'Your Saved Place',
                          style: TextStyle(fontSize: 12, color: markerColor),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(sheetContext),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            if (marker.description.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes, size: 20, color: Colors.grey.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      marker.description,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.home_outlined,
                  size: 20,
                  color: marker.isSaving ? Colors.orange.shade600 : markerColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    marker.address ?? 'Address not available',
                    style: TextStyle(
                      fontSize: 14,
                      color: marker.isSaving
                          ? Colors.orange.shade600
                          : marker.address != null
                          ? markerColor
                          : Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Icon(Icons.location_on, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 12),
                Text(
                  marker.coordinates,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
              ],
            ),

            // Delete button for user's saved places only.
            if (!marker.isLocal && !marker.isSaving) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _confirmAndDeletePlace(marker);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete This Place'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// Shows confirmation dialog and deletes the place if confirmed.
  Future<void> _confirmAndDeletePlace(MarkerData marker) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Place'),
        content: SingleChildScrollView(
          child: Text(
            'Are you sure you want to delete "${marker.title}"?\n\n'
            'This action cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
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

    // Find the place and its index before deletion
    final removedIndex = _allPlaces.indexWhere((p) => p.id == marker.id);

    // Safety check: ensure place exists before deletion
    if (removedIndex == -1) {
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

    final removedPlace = _allPlaces[removedIndex];

    setState(() {
      _allPlaces.removeAt(removedIndex);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Deleting place...'),
        duration: Duration(seconds: 1),
      ),
    );

    // Perform actual delete.
    final success = await PlacesService.deletePlace(
      marker.id,
      context,
      const GeoMapWidget(),
    );

    if (!mounted) return;

    if (success) {
      // Update in-memory cache so LocationsPage sees the deletion immediately
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
      // Rollback on failure.
      setState(() {
        if (removedIndex >= 0 && removedIndex <= _allPlaces.length) {
          _allPlaces.insert(removedIndex, removedPlace);
        } else {
          _allPlaces.add(removedPlace);
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
    // Detect if app is in dark mode
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Check if current map source is already dark
    final isMapAlreadyDark = _mapSettings.mapSource.isDarkSource;

    // Midnight blue color matrix for dark mode
    // Transforms bright maps into eye-friendly night vision
    const midnightMatrix = <double>[
      -0.33, -0.33, -0.33, 0, 255, // Red
      -0.33, -0.33, -0.33, 0, 255, // Green
      -0.33, -0.33, -0.33, 0, 255, // Blue
      0, 0, 0, 1, 0,
    ];
    // Apply color filter only if:
    // 1. App is in dark mode, AND
    // 2. Map source is NOT already a dark map
    final shouldApplyFilter = isDarkMode && !isMapAlreadyDark;

    return Scaffold(
      body: Stack(
        children: [
          // Fade-in animation for smooth entrance
          FadeTransition(
            opacity: _fadeAnimation,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(-12.46, 130.84), // Darwin
                // initialCenter: const LatLng(-35.2809, 149.1300), // Canberra
                initialZoom: 13.0,
                minZoom: 3.0,
                maxZoom: 18.0,
                onTap: _onMapTap,
                onLongPress: (tapPosition, latLng) {
                  _showAddPlaceDialog(
                    latitude: latLng.latitude,
                    longitude: latLng.longitude,
                  );
                },
                onPositionChanged: _onMapPositionChanged,
              ),
              children: [
                // Apply color filter ONLY to tile layer, not markers
                ColorFiltered(
                  colorFilter: shouldApplyFilter
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

                    // CRITICAL: Remove failed tiles so they can be retried
                    // Without this, white tiles persist after loading failures
                    evictErrorTileStrategy: EvictErrorTileStrategy.dispose,

                    // Optimized buffer settings to reduce white tiles
                    // keepBuffer: tiles to keep cached outside visible area (0-10 recommended)
                    // Higher = smoother scroll/zoom but more memory (~10MB per +2)
                    keepBuffer:
                        5, // Reduced further to prevent memory issues during fast zoom
                    // panBuffer: preload tiles around visible area (0-4 recommended)
                    // Higher = smoother pan but more network requests
                    panBuffer: 1, // Minimal preload to prevent request flooding
                    // Zoom settings
                    maxZoom: 19,
                    maxNativeZoom: 18,

                    // Additional optimization for mobile and fast zoom
                    tileSize: 256,
                    retinaMode:
                        false, // Disable for performance on non-retina screens
                    // Error handling for tile loading failures
                    errorImage: const AssetImage(
                      'assets/images/tile_error.png',
                      package: 'solidpod',
                    ),
                  ),
                ),

                // Marker layer - NOT affected by color filter
                MarkerLayer(
                  markers: _filteredMarkers.asMap().entries.map((entry) {
                    final index = entry.key;
                    final markerData = entry.value;

                    return Marker(
                      point: markerData.position,
                      width: 40,
                      height: 40,
                      child: _MarkerWithAnimation(
                        index: index,
                        // Animate on initial load OR after login refresh
                        shouldAnimate:
                            !_initialAnimationComplete || _isPostLoginRefresh,
                        child: GestureDetector(
                          onTap: () => _showMarkerDetails(markerData),
                          child: markerData.isSaving
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
                                  // Use custom color from settings.
                                  color: markerData.color,
                                ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // News marker layer - only display markers visible on current screen
                if (_showNewsMarkers)
                  MarkerLayer(
                    markers: _getVisibleNewsMarkers().map((newsMarker) {
                      return Marker(
                        point: newsMarker.location,
                        width: 36,
                        height: 36,
                        child: GestureDetector(
                          onTap: () => _showNewsMarkerDetails(newsMarker),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue.shade700,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
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
                      );
                    }).toList(),
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
          Positioned(
            top: 16,
            left: 16,
            child: GestureDetector(
              onTap: _isLoadingPlaces
                  ? null
                  : () {
                      if (_isLoggedIn) {
                        // Logged in: show add place dialog
                        _showAddPlaceDialog();
                      } else {
                        // Not logged in: navigate to login page
                        SolidAuthHandler.instance.handleLogin(context);
                      }
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _isLoggedIn
                      ? Colors.green.withValues(alpha: 0.85)
                      : Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                  // Visual hint for clickable state
                  border: _isLoggedIn
                      ? Border.all(color: Colors.green.shade300, width: 1.5)
                      : !_isLoadingPlaces
                      ? Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        )
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isLoadingPlaces
                          ? Icons.hourglass_empty
                          : _isLoggedIn
                          ? Icons.add_location
                          : Icons.login,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isLoadingPlaces
                          ? 'Loading places...'
                          : _isLoggedIn
                          ? 'Tap to Add Place'
                          : 'Login to add places',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: _isLoggedIn
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // News markers toggle button
          Positioned(
            top: 68, // Below the add place button
            left: 16,
            child: GestureDetector(
              onTap: _isLoadingNews ? null : _toggleNewsMarkers,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _showNewsMarkers
                      ? Colors.blue.withValues(alpha: 0.85)
                      : Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: _showNewsMarkers
                      ? Border.all(color: Colors.blue.shade300, width: 1.5)
                      : Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoadingNews)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      Icon(
                        _showNewsMarkers
                            ? Icons.article
                            : Icons.article_outlined,
                        color: Colors.white,
                        size: 16,
                      ),
                    const SizedBox(width: 6),
                    Text(
                      _isLoadingNews
                          ? 'Loading news...'
                          : _showNewsMarkers
                          ? 'News: ${_getVisibleNewsMarkers().length}'
                          : 'Show News',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: _showNewsMarkers
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Zoom In button
          FloatingActionButton.small(
            heroTag: 'zoomIn',
            onPressed: _zoomIn,
            tooltip: 'Zoom In',
            backgroundColor: Colors.grey.shade800,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add, size: 20),
          ),
          const SizedBox(height: 8),
          // Zoom Out button
          FloatingActionButton.small(
            heroTag: 'zoomOut',
            onPressed: _zoomOut,
            tooltip: 'Zoom Out',
            backgroundColor: Colors.grey.shade800,
            foregroundColor: Colors.white,
            child: const Icon(Icons.remove, size: 20),
          ),
          const SizedBox(height: 16),
          // Refresh Places button
          FloatingActionButton.small(
            heroTag: 'refresh',
            onPressed: _isLoadingPlaces ? null : _loadAllPlaces,
            tooltip: 'Refresh Places',
            backgroundColor: _isLoadingPlaces ? Colors.grey : Colors.blue,
            foregroundColor: Colors.white,
            child: _isLoadingPlaces
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

/// Animated marker widget with delayed entrance animation
class _MarkerWithAnimation extends StatefulWidget {
  const _MarkerWithAnimation({
    required this.index,
    required this.shouldAnimate,
    required this.child,
  });

  final int index;
  final bool shouldAnimate;
  final Widget child;

  @override
  State<_MarkerWithAnimation> createState() => _MarkerWithAnimationState();
}

class _MarkerWithAnimationState extends State<_MarkerWithAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    if (widget.shouldAnimate) {
      // Create animation controller with staggered delay based on index
      _controller = AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      );

      // Scale animation: bounce effect (0.0 �?1.0 with overshoot)
      _scaleAnimation = CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      );

      // Fade animation: smooth fade-in
      _fadeAnimation = CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      );

      // Start animation with staggered delay (50ms per marker)
      Future.delayed(Duration(milliseconds: 100 + (widget.index * 50)), () {
        if (mounted) {
          _controller.forward();
        }
      });
    } else {
      // No animation needed - create dummy controller
      _controller = AnimationController(duration: Duration.zero, vsync: this)
        ..value = 1.0;

      _scaleAnimation = const AlwaysStoppedAnimation(1.0);
      _fadeAnimation = const AlwaysStoppedAnimation(1.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.shouldAnimate) {
      // No animation - return child directly
      return widget.child;
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

/// Data model for a map marker.
class MarkerData {
  final LatLng position;
  final String title;
  final String description;
  final String? address;

  /// Unique identifier for this place (needed for delete operation).
  final String id;

  /// Whether this marker is from local assets (canned examples).
  final bool isLocal;

  /// Whether this marker is currently being saved.
  final bool isSaving;

  /// Custom color for this marker (from settings).
  final Color color;

  MarkerData({
    required this.position,
    required this.title,
    required this.description,
    required this.id,
    this.address,
    this.isLocal = false,
    this.isSaving = false,
    this.color = Colors.blue,
  });

  String get coordinates =>
      '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
}
