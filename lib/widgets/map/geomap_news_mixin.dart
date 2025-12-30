/// News-related state and methods mixin for GeoMapWidget.
///
// Time-stamp: <Wednesday 2025-12-31 +1100 Graham Williams>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.
///
/// Authors: Graham Williams, Miduo

library;

import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:geopod/services/gdelt_news_service.dart';
import 'package:geopod/widgets/map/geomap_news_logic.dart';
import 'package:geopod/widgets/map/news_operations.dart';

/// Mixin that provides news-related functionality for GeoMapWidget.
mixin GeoMapNewsMixin<T extends StatefulWidget> on State<T> {
  /// News service instance - must be initialized in initState.
  GdeltNewsService get newsService;

  /// Map controller for bounds calculations.
  MapController get mapController;

  /// Current news markers list.
  List<NewsMarker> get newsMarkers;
  set newsMarkers(List<NewsMarker> value);

  /// Whether news markers are currently shown.
  bool get showNewsMarkers;
  set showNewsMarkers(bool value);

  /// Whether news is currently loading.
  bool get isLoadingNews;
  set isLoadingNews(bool value);

  /// Track last position to avoid unnecessary cache updates.
  LatLng? lastNewsUpdatePosition;
  double? lastNewsUpdateZoom;

  /// Toggles news markers visibility by showing the news list dialog.
  void toggleNewsMarkers() => showNewsListDialogAsyncImpl();

  /// Shows the news list dialog.
  Future<void> showNewsListDialogAsyncImpl() async {
    if (!mounted) return;
    await showNewsListDialogAsync(
      context: context,
      mapController: mapController,
      newsService: newsService,
      getVisibleMarkers: getVisibleNewsMarkersImpl,
      updateState: (m, l, s) {
        if (mounted) {
          setState(() {
            newsMarkers = m;
            isLoadingNews = l;
            showNewsMarkers = s;
          });
        }
      },
    );
  }

  /// Handles map position changes for news updates.
  void onMapPositionChangedForNews(MapCamera pos, bool gesture) {
    if (showNewsMarkers && gesture) {
      if (shouldUpdateNewsCacheImpl(pos.center, pos.zoom)) {
        updateNewsFromCacheImpl();
      }
    }
  }

  /// Checks if news cache should be updated based on position change.
  bool shouldUpdateNewsCacheImpl(LatLng newPosition, double newZoom) {
    final result = shouldUpdateNewsCache(
      newPosition: newPosition,
      newZoom: newZoom,
      lastPosition: lastNewsUpdatePosition,
      lastZoom: lastNewsUpdateZoom,
    );

    if (result) {
      lastNewsUpdatePosition = newPosition;
      lastNewsUpdateZoom = newZoom;
    }

    return result;
  }

  /// Updates news markers from cache.
  void updateNewsFromCacheImpl() {
    if (!mounted) return;
    updateNewsFromCacheForBounds(
      mapController: mapController,
      newsService: newsService,
      setMarkers: (m) => setState(() => newsMarkers = m),
      fetchForCurrentBounds: fetchNewsForCurrentBoundsImpl,
    );
  }

  /// Fetches news for current map bounds.
  Future<void> fetchNewsForCurrentBoundsImpl() async {
    if (!mounted) return;
    await fetchNewsForBounds(
      context: context,
      mapController: mapController,
      newsService: newsService,
      updateState: (m, l) {
        if (mounted) {
          setState(() {
            newsMarkers = m;
            isLoadingNews = l;
          });
        }
      },
    );
  }

  /// Gets visible news markers within current map bounds.
  List<NewsMarker> getVisibleNewsMarkersImpl() => getVisibleNewsInBounds(
    mapController: mapController,
    newsMarkers: newsMarkers,
    showNews: showNewsMarkers,
  );
}
