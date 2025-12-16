/// GDELT News Service for fetching geospatial news data.
///
// Time-stamp: <Monday 2025-12-16 Miduo Luo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.
///
/// This service provides production-grade integration with the GDELT GeoJSON API
/// for fetching real-time news markers based on geographic bounds.
///
/// Authors: Miduo Luo, Graham Williams
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Represents a news marker with geographic location and metadata.
class NewsMarker {
  final String id;
  final LatLng location;
  final String title;
  final String? source;
  final String? url;
  final DateTime? publishedAt;
  final String? imageUrl;
  final double? tone; // GDELT tone score (-10 to +10)

  const NewsMarker({
    required this.id,
    required this.location,
    required this.title,
    this.source,
    this.url,
    this.publishedAt,
    this.imageUrl,
    this.tone,
  });

  /// Parse a NewsMarker from GDELT GeoJSON feature.
  factory NewsMarker.fromGeoJson(Map<String, dynamic> feature) {
    final geometry = feature['geometry'] as Map<String, dynamic>;
    final properties = feature['properties'] as Map<String, dynamic>?;
    
    final coordinates = geometry['coordinates'] as List<dynamic>;
    final lng = (coordinates[0] as num).toDouble();
    final lat = (coordinates[1] as num).toDouble();

    // Extract title and URL from HTML field
    String title = properties?['name']?.toString() ?? 'No title';
    String? url;
    
    final html = properties?['html']?.toString();
    if (html != null && html.isNotEmpty) {
      // Parse HTML to extract title and URL
      final hrefMatch = RegExp(r'href="([^"]+)"').firstMatch(html);
      final titleMatch = RegExp(r'>([^<]+)</a>').firstMatch(html);
      
      if (hrefMatch != null) {
        url = hrefMatch.group(1);
      }
      if (titleMatch != null) {
        title = titleMatch.group(1) ?? title;
      }
    }

    return NewsMarker(
      id: feature['id']?.toString() ?? DateTime.now().toIso8601String(),
      location: LatLng(lat, lng),
      title: title,
      source: properties?['name']?.toString(), // Country/region name
      url: url,
      publishedAt: null, // GDELT geo API doesn't provide dates
      imageUrl: properties?['shareimage']?.toString(),
      tone: null, // Not available in geo API
    );
  }
}

/// Service for fetching news from GDELT GeoJSON API with debouncing and caching.
class GdeltNewsService {
  static const String _baseUrl = 'https://api.gdeltproject.org/api/v2/geo/geo';
  static const Duration _debounceDuration = Duration(milliseconds: 500);
  
  Timer? _debounceTimer;
  DateTime? _lastFetchTime;
  static const Duration _minFetchInterval = Duration(seconds: 2);
  
  // Cache for storing fetched news markers
  final List<NewsMarker> _cachedMarkers = [];
  LatLngBounds? _cachedBounds;
  DateTime? _cacheTime;
  static const Duration _cacheExpiry = Duration(minutes: 10);

  /// Fetch news markers within the specified bounds with debouncing and caching.
  Future<List<NewsMarker>> fetchNews({
    required LatLngBounds bounds,
    String query = 'news',
    int maxResults = 250,
    String timeSpan = '24h',
    bool forceRefresh = false,
  }) async {
    // If bounds are covered by cache and not forcing refresh, return filtered cache
    if (!forceRefresh && isBoundsCovered(bounds)) {
      debugPrint('Using cached news data');
      return getMarkersInBounds(bounds);
    }
    
    _debounceTimer?.cancel();

    final completer = Completer<List<NewsMarker>>();

    _debounceTimer = Timer(_debounceDuration, () async {
      try {
        final now = DateTime.now();
        if (_lastFetchTime != null) {
          final elapsed = now.difference(_lastFetchTime!);
          if (elapsed < _minFetchInterval) {
            final waitTime = _minFetchInterval - elapsed;
            await Future.delayed(waitTime);
          }
        }
        _lastFetchTime = now;

        final markers = await _performFetch(
          bounds: bounds,
          query: query,
          maxResults: maxResults,
          timeSpan: timeSpan,
        );
        
        // Update cache
        _cachedMarkers.clear();
        _cachedMarkers.addAll(markers);
        _cachedBounds = bounds;
        _cacheTime = DateTime.now();
        debugPrint('Cached ${markers.length} news markers');
        
        completer.complete(markers);
      } catch (e) {
        completer.completeError(e);
      }
    });

    return completer.future;
  }

  /// Perform the actual API fetch without debouncing.
  Future<List<NewsMarker>> _performFetch({
    required LatLngBounds bounds,
    required String query,
    required int maxResults,
    required String timeSpan,
  }) async {
    try {
      final center = bounds.center;
      
      final queryParams = {
        'query': query,
        'format': 'geojson',
        'maxrows': maxResults.toString(),
        'timespan': timeSpan,
        'near': '${center.latitude},${center.longitude}',
        'radius': _calculateRadiusKm(bounds).toString(),
      };

      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);
      
      debugPrint('GDELT API URL: $uri');
      
      final response = await http.get(uri).timeout(
        const Duration(seconds: 30), // Increased from 10 to 30 seconds
        onTimeout: () {
          throw TimeoutException('GDELT API request timed out');
        },
      );

      if (response.statusCode != 200) {
        throw Exception('GDELT API error: ${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final features = data['features'] as List<dynamic>? ?? [];

      debugPrint('API returned ${features.length} features');

      // Parse all features and cache them (filtering done later for specific bounds)
      final markers = features
          .whereType<Map<String, dynamic>>()
          .map((f) => NewsMarker.fromGeoJson(f))
          .where((marker) {
            // Only filter invalid coordinates (0,0)
            return !(marker.location.latitude == 0.0 && 
                     marker.location.longitude == 0.0);
          })
          .toList();

      debugPrint('Parsed ${markers.length} valid markers (excluding 0,0 coordinates)');
      return markers;
    } catch (e) {
      debugPrint('Error fetching GDELT news: $e');
      return [];
    }
  }

  /// Calculate approximate radius in kilometers from bounds.
  double _calculateRadiusKm(LatLngBounds bounds) {
    const Distance distance = Distance();
    
    final northWest = LatLng(bounds.north, bounds.west);
    final southEast = LatLng(bounds.south, bounds.east);
    
    final diagonalMeters = distance(northWest, southEast);
    // Use half diagonal and limit to max 500km for faster queries
    return (diagonalMeters / 1000 / 2).clamp(1, 500);
  }

  /// Filter cached markers for the given bounds without making API call.
  List<NewsMarker> getMarkersInBounds(LatLngBounds bounds) {
    if (_cachedMarkers.isEmpty) return [];
    
    // Check if cache is still valid
    if (_cacheTime != null) {
      final elapsed = DateTime.now().difference(_cacheTime!);
      if (elapsed > _cacheExpiry) {
        // Cache expired, clear it
        _cachedMarkers.clear();
        _cachedBounds = null;
        _cacheTime = null;
        return [];
      }
    }
    
    // Filter cached markers that are within the requested bounds
    return _cachedMarkers.where((marker) {
      return marker.location.latitude >= bounds.south &&
             marker.location.latitude <= bounds.north &&
             marker.location.longitude >= bounds.west &&
             marker.location.longitude <= bounds.east;
    }).toList();
  }
  
  /// Check if the given bounds are mostly covered by cached data.
  bool isBoundsCovered(LatLngBounds bounds) {
    if (_cachedBounds == null || _cacheTime == null) return false;
    
    // Check if cache is still valid
    final elapsed = DateTime.now().difference(_cacheTime!);
    if (elapsed > _cacheExpiry) return false;
    
    // Check if requested bounds are within cached bounds (with 20% margin)
    final latMargin = (_cachedBounds!.north - _cachedBounds!.south) * 0.2;
    final lngMargin = (_cachedBounds!.east - _cachedBounds!.west) * 0.2;
    
    return bounds.south >= _cachedBounds!.south - latMargin &&
           bounds.north <= _cachedBounds!.north + latMargin &&
           bounds.west >= _cachedBounds!.west - lngMargin &&
           bounds.east <= _cachedBounds!.east + lngMargin;
  }
  
  /// Clear the cache manually.
  void clearCache() {
    _cachedMarkers.clear();
    _cachedBounds = null;
    _cacheTime = null;
  }

  /// Cancel any pending debounced requests.
  void dispose() {
    _debounceTimer?.cancel();
    clearCache();
  }
}
