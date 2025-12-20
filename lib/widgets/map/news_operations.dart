/// News marker operations for GeoMapWidget.
///
// Time-stamp: <2025-12-08 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';

import 'package:geopod/services/gdelt_news_service.dart';
import 'package:geopod/widgets/map/news_list_dialog.dart';
import 'package:geopod/widgets/map/news_marker_details_sheet.dart';

/// Shows news list dialog and handles news marker operations.
Future<void> showNewsListDialogAsync({
  required BuildContext context,
  required MapController mapController,
  required GdeltNewsService newsService,
  required List<NewsMarker> Function() getVisibleMarkers,
  required void Function(List<NewsMarker> markers, bool loading, bool show)
  updateState,
}) async {
  updateState([], true, true);
  try {
    final bounds = mapController.camera.visibleBounds;
    final nm = await newsService.fetchNews(
      bounds: bounds,
      query: 'news',
      maxResults: 50,
      timeSpan: '24h',
    );
    updateState(nm, false, true);
    if (!context.mounted) return;
    await showNewsListDialog(
      context: context,
      visibleNewsMarkers: getVisibleMarkers(),
      onCloseNews: () => updateState([], false, false),
      onNewsMarkerTap: (n) {
        mapController.move(n.location, 12.0);
        Future.delayed(const Duration(milliseconds: 300), () {
          if (context.mounted) {
            showNewsMarkerDetailsSheet(context, n);
          }
        });
      },
    );
  } catch (e) {
    updateState([], false, false);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to fetch news: $e'),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }
}

/// Updates news markers from cache when map position changes.
void updateNewsFromCacheForBounds({
  required MapController mapController,
  required GdeltNewsService newsService,
  required void Function(List<NewsMarker>) setMarkers,
  required Future<void> Function() fetchForCurrentBounds,
}) {
  final bounds = mapController.camera.visibleBounds;
  final cached = newsService.getMarkersInBounds(bounds);
  
  // Always update visible markers from cache
  if (cached.isNotEmpty) {
    setMarkers(cached);
  }
  
  // Only fetch new data if significantly outside cached bounds
  // This prevents unnecessary fetches during small movements
  if (!newsService.isBoundsCovered(bounds)) {
    // Async fetch without blocking UI
    fetchForCurrentBounds();
  }
}

/// Fetches news for current map bounds.
Future<void> fetchNewsForBounds({
  required BuildContext context,
  required MapController mapController,
  required GdeltNewsService newsService,
  required void Function(List<NewsMarker> markers, bool loading) updateState,
}) async {
  // Don't clear existing markers, just set loading state
  // Get current cached markers first
  final bounds = mapController.camera.visibleBounds;
  final currentMarkers = newsService.getMarkersInBounds(bounds);
  updateState(currentMarkers, true);
  
  try {
    final nm = await newsService.fetchNews(
      bounds: bounds,
      query: 'news',
      maxResults: 50,
      timeSpan: '24h',
    );
    updateState(nm, false);
  } catch (e) {
    updateState([], false);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to fetch news: $e'),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }
}

/// Gets visible news markers within map bounds.
List<NewsMarker> getVisibleNewsInBounds({
  required MapController mapController,
  required List<NewsMarker> newsMarkers,
  required bool showNews,
}) {
  if (!showNews || newsMarkers.isEmpty) return [];
  final b = mapController.camera.visibleBounds;
  return newsMarkers
      .where(
        (m) =>
            m.location.latitude >= b.south &&
            m.location.latitude <= b.north &&
            m.location.longitude >= b.west &&
            m.location.longitude <= b.east,
      )
      .toList();
}
