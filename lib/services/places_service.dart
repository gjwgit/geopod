/// Service for managing places data in the user's Solid Pod.
///
// Time-stamp: <2025-12-04 Miduo>
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

import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solidpod/solidpod.dart';
import 'package:uuid/uuid.dart';

import 'package:geopod/services/geocoding_service.dart';

/// Global notifier for places data changes.
/// Increment this value whenever places are added, deleted, or updated.
/// UI components can listen to this to refresh their data.
final placesChangeNotifier = ValueNotifier<int>(0);

/// The file name for storing all places.
const String _placesFileName = 'places.json';

/// Cache keys for SharedPreferences
const String _keyPodPlacesCache = 'pod_places_cache';
const String _keyPodPlacesCacheTimestamp = 'pod_places_cache_timestamp';

/// Cache expiry duration (5 minutes)
const Duration _cacheExpiry = Duration(minutes: 5);

/// In-memory cache manager for instant access to places data.
class PlacesCacheManager {
  // Singleton pattern
  static final PlacesCacheManager _instance = PlacesCacheManager._internal();
  factory PlacesCacheManager() => _instance;
  PlacesCacheManager._internal();

  /// Cached all places (local + Pod)
  List<Place>? _allPlacesCache;

  /// Cached Pod-only places
  List<Place>? _podPlacesCache;

  /// Last cache update timestamp
  DateTime? _lastCacheTime;

  /// Login state when cache was created (to prevent guest using logged-in user's cache)
  bool? _wasLoggedInWhenCached;

  /// Cache validity duration (in-memory cache, should be long enough for login)
  static const Duration _memoryCacheExpiry = Duration(minutes: 30);

  /// Gets all cached places (local + Pod)
  List<Place>? get allPlaces {
    if (_allPlacesCache == null || _isCacheExpired()) {
      return null;
    }
    return List.unmodifiable(_allPlacesCache!);
  }

  /// Gets the login state when cache was created
  bool? get wasLoggedInWhenCached => _wasLoggedInWhenCached;

  /// Gets cached Pod places only
  List<Place>? get podPlaces {
    if (_podPlacesCache == null || _isCacheExpired()) {
      return null;
    }
    return List.unmodifiable(_podPlacesCache!);
  }

  /// Caches all places data with current login state
  void cacheAllPlaces(List<Place> places) {
    _allPlacesCache = List.from(places);
    _lastCacheTime = DateTime.now();
    _wasLoggedInWhenCached = AuthDataManager.isLoggedInSync();
  }

  /// Caches Pod places data
  void cachePodPlaces(List<Place> places) {
    _podPlacesCache = List.from(places);
    _lastCacheTime = DateTime.now();
  }

  /// Checks if in-memory cache is expired
  bool _isCacheExpired() {
    if (_lastCacheTime == null) return true;
    return DateTime.now().difference(_lastCacheTime!) > _memoryCacheExpiry;
  }

  /// Clears all in-memory cache
  void clearCache() {
    _allPlacesCache = null;
    _podPlacesCache = null;
    _lastCacheTime = null;
    _wasLoggedInWhenCached = null;
  }

  /// Clears only Pod-related cache, preserves local places structure
  /// allPlaces cache is cleared because it contains merged data
  void clearPodCacheOnly() {
    _allPlacesCache = null; // Clear merged cache (will be rebuilt)
    _podPlacesCache = null; // Clear Pod cache
    _lastCacheTime = null;
    _wasLoggedInWhenCached = null;
    // Note: Local places are cached in PlacesService._cachedLocalPlaces, not here
  }

  /// Forces cache refresh on next fetch
  void invalidateCache() {
    _lastCacheTime = null;
  }
}

/// Data model representing a saved place.
class Place {
  final String id;
  final double lat;
  final double lng;
  final String note;
  final String timestamp;
  final String? address;

  /// Whether this place is from local assets (canned examples).
  /// Local places are read-only and cannot be deleted.
  final bool isLocal;

  Place({
    required this.id,
    required this.lat,
    required this.lng,
    required this.note,
    required this.timestamp,
    this.address,
    this.isLocal = false,
  });

  /// Creates a Place from JSON map.
  ///
  /// [isLocalSource] indicates if the JSON comes from local assets.
  factory Place.fromJson(
    Map<String, dynamic> json, {
    bool isLocalSource = false,
  }) {
    return Place(
      id:
          json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      note: json['note'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
      address: json['address'] as String?,
      isLocal: isLocalSource,
    );
  }

  /// Converts Place to JSON map.
  /// Note: isLocal is not serialized as it's determined by source.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lat': lat,
      'lng': lng,
      'note': note,
      'timestamp': timestamp,
      if (address != null) 'address': address,
    };
  }

  /// Returns a formatted display string for the place.
  /// Now returns the full note without truncation.
  String get displayTitle {
    return note.isNotEmpty ? note : '(No title)';
  }

  /// Returns formatted coordinates string.
  String get coordinates =>
      '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';

  /// Returns the address or coordinates if address is not available.
  String get displayAddress => address ?? coordinates;

  /// Returns a short version of the address for display in limited space.
  String get shortAddress {
    if (address == null || address!.isEmpty) {
      return coordinates;
    }
    if (address!.length > 40) {
      return '${address!.substring(0, 37)}...';
    }
    return address!;
  }

  /// Returns formatted date string.
  String get formattedDate {
    try {
      final date = DateTime.parse(timestamp);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return timestamp;
    }
  }
}

/// Service for reading and managing places from the Solid Pod.
///
/// Uses direct HTTP requests for JSON files.
class PlacesService {
  /// Cached local places (loaded once from assets).
  static List<Place>? _cachedLocalPlaces;

  /// Gets the full file path within the app's data directory.
  /// Saves to: geopod/data/places/places.json
  static Future<String> _getFullFilePath() async {
    final dataDirPath = await getDataDirPath();
    final placesPath = '$dataDirPath/places';
    return '$placesPath/$_placesFileName';
  }

  /// Loads canned example places from local assets.
  static Future<List<Place>> loadLocalPlaces() async {
    // Return cached data if available.
    if (_cachedLocalPlaces != null) {
      return _cachedLocalPlaces!;
    }

    final places = <Place>[];

    try {
      final jsonString = await rootBundle.loadString('assets/data/places.json');
      final dynamic decoded = jsonDecode(jsonString);

      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            try {
              places.add(Place.fromJson(item, isLocalSource: true));
            } catch (_) {
              // Skip malformed entries.
            }
          }
        }
      }
    } catch (_) {
      // Return empty list if asset fails to load.
    }

    _cachedLocalPlaces = places;
    return places;
  }

  /// Reads a JSON file directly from the Pod using HTTP.
  static Future<String?> _readJsonFile() async {
    try {
      final filePath = await _getFullFilePath();
      final fileUrl = await getFileUrl(filePath);
      final (:accessToken, :dPopToken) = await getTokensForResource(
        fileUrl,
        'GET',
      );

      final response = await http.get(
        Uri.parse(fileUrl),
        headers: <String, String>{
          'Accept': 'application/json, */*',
          'Authorization': 'DPoP $accessToken',
          'Connection': 'keep-alive',
          'DPoP': dPopToken,
        },
      );

      if (response.statusCode == 200) {
        return response.body;
      } else if (response.statusCode == 404) {
        return null;
      } else {
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  /// Writes a JSON file directly to the Pod using HTTP PUT.
  static Future<bool> _writeJsonFile(String content) async {
    try {
      final filePath = await _getFullFilePath();
      final fileUrl = await getFileUrl(filePath);
      final (:accessToken, :dPopToken) = await getTokensForResource(
        fileUrl,
        'PUT',
      );

      final response = await http.put(
        Uri.parse(fileUrl),
        headers: <String, String>{
          'Accept': '*/*',
          'Authorization': 'DPoP $accessToken',
          'Connection': 'keep-alive',
          'Content-Type': 'application/json',
          'DPoP': dPopToken,
        },
        body: content,
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Fetches all places: local (canned examples) + user's Pod data.
  ///
  /// Returns merged list with local places first, then Pod places sorted by date.
  /// Uses in-memory cache + parallel loading to minimize startup time.
  static Future<List<Place>> fetchPlaces({bool forceRefresh = false}) async {
    final cacheManager = PlacesCacheManager();

    // Step 1: Try in-memory cache first (instant - 0ms)
    if (!forceRefresh) {
      final cachedAll = cacheManager.allPlaces;
      if (cachedAll != null) {
        return cachedAll;
      }
    }

    final allPlaces = <Place>[];

    // Step 2: Parallel loading - Load local and Pod data simultaneously
    final results = await Future.wait([
      loadLocalPlaces(), // Fast: local asset file (~10-50ms)
      fetchPodPlaces(
        forceRefresh: forceRefresh,
      ), // Slow: network request (~500-2000ms)
    ]);

    final localPlaces = results[0];
    final podPlaces = results[1];

    // Merge - Pod places first (user data), then local examples
    allPlaces.addAll(podPlaces);
    allPlaces.addAll(localPlaces);

    // Cache the merged result in memory
    cacheManager.cacheAllPlaces(allPlaces);

    return allPlaces;
  }

  /// Fetches only the user's saved places from the Pod.
  /// Uses in-memory cache + SharedPreferences cache for instant access.
  static Future<List<Place>> fetchPodPlaces({bool forceRefresh = false}) async {
    final places = <Place>[];
    final cacheManager = PlacesCacheManager();

    try {
      final isLoggedIn = await checkLoggedIn();
      if (!isLoggedIn) {
        return places;
      }

      // Step 1: Try in-memory cache first (instant - 0ms)
      if (!forceRefresh) {
        final memoryCache = cacheManager.podPlaces;
        if (memoryCache != null) {
          // Refresh in background if needed
          _refreshPodPlacesInBackground();
          return memoryCache;
        }
      }

      // Step 2: Try SharedPreferences cache (fast - 1-5ms)
      if (!forceRefresh) {
        final cached = await _getCachedPodPlaces();
        if (cached != null) {
          // Cache in memory for next time
          cacheManager.cachePodPlaces(cached);
          // Return cached immediately, but refresh in background
          _refreshPodPlacesInBackground();
          return cached;
        }
      }

      // Step 3: No cache - fetch from Pod (slow - 500-2000ms)
      final content = await _readJsonFile();

      if (content == null || content.trim().isEmpty) {
        return places;
      }

      try {
        final dynamic decoded = jsonDecode(content);

        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              try {
                places.add(Place.fromJson(item, isLocalSource: false));
              } catch (_) {
                // Skip malformed entries.
              }
            }
          }
        } else if (decoded is Map<String, dynamic>) {
          try {
            places.add(Place.fromJson(decoded, isLocalSource: false));
          } catch (_) {
            // Skip if malformed.
          }
        }
      } on FormatException {
        return places;
      }

      places.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Cache the result for next time (both SharedPreferences and memory)
      await _cachePodPlaces(content);
      cacheManager.cachePodPlaces(places);
    } catch (e) {
      // Return empty list on error.
    }

    return places;
  }

  /// Gets cached Pod places if available and not expired.
  static Future<List<Place>?> _getCachedPodPlaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if cache exists
      final cachedJson = prefs.getString(_keyPodPlacesCache);
      final cachedTimestamp = prefs.getInt(_keyPodPlacesCacheTimestamp);

      if (cachedJson == null || cachedTimestamp == null) {
        return null;
      }

      // Check if cache is expired
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(cachedTimestamp);
      final now = DateTime.now();
      if (now.difference(cacheTime) > _cacheExpiry) {
        return null; // Cache expired
      }

      // Parse cached data
      final places = <Place>[];
      final dynamic decoded = jsonDecode(cachedJson);

      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            try {
              places.add(Place.fromJson(item, isLocalSource: false));
            } catch (_) {
              // Skip malformed entries
            }
          }
        }
      }

      places.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return places;
    } catch (_) {
      return null;
    }
  }

  /// Caches Pod places data to SharedPreferences.
  static Future<void> _cachePodPlaces(String jsonContent) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPodPlacesCache, jsonContent);
      await prefs.setInt(
        _keyPodPlacesCacheTimestamp,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // Ignore cache errors - not critical
    }
  }

  /// Refreshes Pod places in background (fire and forget).
  static void _refreshPodPlacesInBackground() {
    // Fire and forget - don't await
    Future(() async {
      try {
        if (!await checkLoggedIn()) return;

        final content = await _readJsonFile();
        if (content != null && content.trim().isNotEmpty) {
          await _cachePodPlaces(content);
        }
      } catch (_) {
        // Ignore errors in background refresh
      }
    });
  }

  /// Clears the Pod places cache (both SharedPreferences and memory).
  /// NOTE: This clears ALL caches including local places cache.
  /// For login scenarios, prefer clearPodCacheOnly() to keep local places.
  static Future<void> clearCache() async {
    try {
      // Clear in-memory cache
      PlacesCacheManager().clearCache();

      // Clear SharedPreferences cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyPodPlacesCache);
      await prefs.remove(_keyPodPlacesCacheTimestamp);
    } catch (e) {
      // Ignore errors
    }
  }

  /// Clears only Pod places cache, preserving local places cache.
  /// Use this for login scenarios - local examples don't need to be reloaded.
  static Future<void> clearPodCacheOnly() async {
    try {
      // Clear only Pod-related caches, keep local places
      PlacesCacheManager().clearPodCacheOnly();

      // Clear SharedPreferences Pod cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyPodPlacesCache);
      await prefs.remove(_keyPodPlacesCacheTimestamp);
    } catch (e) {
      // Ignore errors
    }
  }

  /// Incrementally updates places by adding Pod data to existing local cache.
  /// This is much faster than full refresh after login because:
  /// - Local places are already cached (instant)
  /// - Only Pod places need network request
  /// Returns merged list immediately with cached local + fresh Pod data.
  static Future<List<Place>> refreshPodDataOnly() async {
    final cacheManager = PlacesCacheManager();

    // Get local places from cache (instant) or load if not cached
    final localPlaces = await loadLocalPlaces();

    // Clear old Pod cache and fetch fresh Pod data
    await clearPodCacheOnly();
    final podPlaces = await fetchPodPlaces(forceRefresh: true);

    // Merge - Pod places first, then local examples
    final allPlaces = <Place>[];
    allPlaces.addAll(podPlaces);
    allPlaces.addAll(localPlaces);

    // Cache the merged result
    cacheManager.cacheAllPlaces(allPlaces);

    return allPlaces;
  }

  /// Adds a new place to the Pod.
  static Future<bool> addPlace(
    Place place,
    BuildContext context,
    Widget returnWidget,
  ) async {
    try {
      if (!await checkLoggedIn()) {
        return false;
      }

      // Use cached Pod places to avoid unnecessary network request
      final cacheManager = PlacesCacheManager();
      var existingPlaces = cacheManager.podPlaces;

      // If no cache, fetch from network (fallback)
      existingPlaces ??= await fetchPodPlaces();

      // Create a mutable copy and add the new place
      final updatedPlaces = List<Place>.from(existingPlaces)..insert(0, place);

      final jsonList = updatedPlaces.map((p) => p.toJson()).toList();
      final jsonContent = jsonEncode(jsonList);

      final success = await _writeJsonFile(jsonContent);

      // Clear cache after successful write
      if (success) {
        await clearCache();
        // Notify listeners that places data has changed
        placesChangeNotifier.value++;
      }

      return success;
    } catch (_) {
      return false;
    }
  }

  /// Deletes a place from the Pod by its ID.
  ///
  /// Only Pod places can be deleted. Local (canned) places are read-only.
  static Future<bool> deletePlace(
    String placeId,
    BuildContext context,
    Widget returnWidget,
  ) async {
    try {
      if (!await checkLoggedIn()) {
        return false;
      }

      // Use cached Pod places to avoid unnecessary network request
      final cacheManager = PlacesCacheManager();
      var existingPlaces = cacheManager.podPlaces;

      // If no cache, fetch from network (fallback)
      existingPlaces ??= await fetchPodPlaces();

      // Create a mutable copy and filter out the deleted place
      final updatedPlaces = List<Place>.from(existingPlaces)
        ..removeWhere((p) => p.id == placeId);

      final jsonList = updatedPlaces.map((p) => p.toJson()).toList();
      final jsonContent = jsonEncode(jsonList);

      final success = await _writeJsonFile(jsonContent);

      // Clear cache after successful write
      if (success) {
        await clearCache();
        // Notify listeners that places data has changed
        placesChangeNotifier.value++;
      }

      return success;
    } catch (_) {
      return false;
    }
  }

  /// Exports user's Pod places to a JSON file and triggers download.
  ///
  /// Returns true if export was successful, false otherwise.
  static Future<bool> exportPlaces(List<Place> places) async {
    try {
      // Filter out local places - only export user's Pod data.
      final userPlaces = places.where((p) => !p.isLocal).toList();

      if (userPlaces.isEmpty) {
        return false;
      }

      final jsonList = userPlaces.map((p) => p.toJson()).toList();
      final jsonContent = const JsonEncoder.withIndent('  ').convert(jsonList);
      final bytes = Uint8List.fromList(utf8.encode(jsonContent));

      await FileSaver.instance.saveFile(
        name: 'places',
        bytes: bytes,
        ext: 'json',
        mimeType: MimeType.json,
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Imports places from a JSON file selected by the user.
  ///
  /// Returns an [ImportResult] containing validated places and any errors.
  /// Validation rules:
  /// - lat and lng are REQUIRED - items without these are skipped
  /// - id: auto-generated if missing (UUID)
  /// - timestamp: uses current time if missing
  /// - note: defaults to empty string if missing
  /// - address: defaults to "Unknown Location" if missing
  static Future<ImportResult> importPlaces() async {
    final result = ImportResult();

    try {
      final pickResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (pickResult == null || pickResult.files.isEmpty) {
        result.cancelled = true;
        return result;
      }

      final file = pickResult.files.first;
      if (file.bytes == null) {
        result.errors.add('Failed to read file data');
        return result;
      }

      final jsonString = utf8.decode(file.bytes!);
      final dynamic decoded;

      try {
        decoded = jsonDecode(jsonString);
      } catch (e) {
        result.errors.add('Invalid JSON format: $e');
        return result;
      }

      if (decoded is! List) {
        result.errors.add('Expected a JSON array of place objects');
        return result;
      }

      final uuid = const Uuid();

      for (int i = 0; i < decoded.length; i++) {
        final item = decoded[i];

        if (item is! Map<String, dynamic>) {
          result.errors.add('Item ${i + 1}: Not a valid object, skipped');
          result.skippedCount++;
          continue;
        }

        // Validate required fields: lat and lng.
        final lat = item['lat'];
        final lng = item['lng'];

        if (lat == null || lng == null) {
          result.errors.add(
            'Item ${i + 1}: Missing required lat/lng fields, skipped',
          );
          result.skippedCount++;
          continue;
        }

        if (lat is! num || lng is! num) {
          result.errors.add('Item ${i + 1}: lat/lng must be numbers, skipped');
          result.skippedCount++;
          continue;
        }

        // Validate lat/lng ranges.
        if (lat < -90 || lat > 90) {
          result.errors.add(
            'Item ${i + 1}: lat must be between -90 and 90, skipped',
          );
          result.skippedCount++;
          continue;
        }

        if (lng < -180 || lng > 180) {
          result.errors.add(
            'Item ${i + 1}: lng must be between -180 and 180, skipped',
          );
          result.skippedCount++;
          continue;
        }

        // Auto-complete missing optional fields.
        // Note: address field is IGNORED from JSON - will be auto-generated via geocoding.
        final place = Place(
          id: (item['id'] as String?) ?? uuid.v4(),
          lat: lat.toDouble(),
          lng: lng.toDouble(),
          note: (item['note'] as String?) ?? '',
          timestamp:
              (item['timestamp'] as String?) ??
              DateTime.now().toUtc().toIso8601String(),
          address: null, // Address will be fetched via reverse geocoding.
          isLocal: false,
        );

        result.places.add(place);
      }

      return result;
    } catch (e) {
      result.errors.add('Unexpected error: $e');
      return result;
    }
  }

  /// Merges imported places into existing Pod places.
  ///
  /// Avoids duplicates based on ID. If a place with the same ID exists,
  /// it will be skipped (not overwritten).
  ///
  /// This method also fetches addresses for imported places via reverse geocoding.
  ///
  /// Returns true if merge and save was successful.
  static Future<bool> mergeImportedPlaces(
    List<Place> importedPlaces,
    BuildContext context,
    Widget returnWidget, {
    void Function(int current, int total)? onProgress,
  }) async {
    try {
      if (!await checkLoggedIn()) {
        return false;
      }

      final existingPlaces = await fetchPodPlaces();
      final existingIds = existingPlaces.map((p) => p.id).toSet();

      // Filter out duplicates.
      final newPlaces = importedPlaces
          .where((p) => !existingIds.contains(p.id))
          .toList();

      if (newPlaces.isEmpty && importedPlaces.isNotEmpty) {
        // All places were duplicates.
        return true;
      }

      // Fetch addresses for new places via reverse geocoding.
      final placesWithAddresses = <Place>[];
      for (int i = 0; i < newPlaces.length; i++) {
        final place = newPlaces[i];
        onProgress?.call(i + 1, newPlaces.length);

        // Fetch address via reverse geocoding.
        final address = await GeocodingService.getAddress(place.lat, place.lng);

        placesWithAddresses.add(
          Place(
            id: place.id,
            lat: place.lat,
            lng: place.lng,
            note: place.note,
            timestamp: place.timestamp,
            address: address,
            isLocal: false,
          ),
        );
      }

      // Merge: new places first, then existing.
      final mergedPlaces = [...placesWithAddresses, ...existingPlaces];

      final jsonList = mergedPlaces.map((p) => p.toJson()).toList();
      final jsonContent = jsonEncode(jsonList);

      final success = await _writeJsonFile(jsonContent);

      // Clear cache after successful write
      if (success) {
        await clearCache();
        // Notify listeners that places data has changed
        placesChangeNotifier.value++;
      }

      return success;
    } catch (_) {
      return false;
    }
  }

  /// Clears all user's saved places from the Pod.
  ///
  /// Returns true if clear was successful.
  static Future<bool> clearAllPlaces(
    BuildContext context,
    Widget returnWidget,
  ) async {
    try {
      if (!await checkLoggedIn()) {
        return false;
      }

      // Write empty array to clear all places.
      final success = await _writeJsonFile('[]');

      // Clear cache after successful write
      if (success) {
        await clearCache();
        // Notify listeners that places data has changed
        placesChangeNotifier.value++;
      }

      return success;
    } catch (_) {
      return false;
    }
  }

  /// Updates an existing place in the Pod.
  ///
  /// If coordinates changed, automatically fetches new address via geocoding.
  ///
  /// Returns true if update was successful.
  static Future<bool> updatePlace(
    Place updatedPlace,
    BuildContext context,
    Widget returnWidget, {
    bool coordinatesChanged = false,
  }) async {
    try {
      if (!await checkLoggedIn()) {
        return false;
      }

      final existingPlaces = await fetchPodPlaces();

      // Create a mutable copy
      final updatedPlaces = List<Place>.from(existingPlaces);
      final index = updatedPlaces.indexWhere((p) => p.id == updatedPlace.id);

      if (index == -1) {
        // Place not found, add as new.
        updatedPlaces.insert(0, updatedPlace);
      } else {
        // If coordinates changed, fetch new address.
        Place placeToSave = updatedPlace;
        if (coordinatesChanged) {
          final newAddress = await GeocodingService.getAddress(
            updatedPlace.lat,
            updatedPlace.lng,
          );
          placeToSave = Place(
            id: updatedPlace.id,
            lat: updatedPlace.lat,
            lng: updatedPlace.lng,
            note: updatedPlace.note,
            timestamp: updatedPlace.timestamp,
            address: newAddress,
            isLocal: false,
          );
        }
        updatedPlaces[index] = placeToSave;
      }

      final jsonList = updatedPlaces.map((p) => p.toJson()).toList();
      final jsonContent = jsonEncode(jsonList);

      final success = await _writeJsonFile(jsonContent);

      // Clear cache after successful write
      if (success) {
        await clearCache();
        // Notify listeners that places data has changed
        placesChangeNotifier.value++;
      }

      return success;
    } catch (_) {
      return false;
    }
  }
}

/// Result of an import operation.
class ImportResult {
  /// Successfully parsed and validated places.
  final List<Place> places = [];

  /// Error messages for skipped items.
  final List<String> errors = [];

  /// Number of items that were skipped due to validation errors.
  int skippedCount = 0;

  /// Whether the user cancelled the file picker.
  bool cancelled = false;

  /// Whether the import was successful (at least one place imported).
  bool get hasPlaces => places.isNotEmpty;

  /// Whether there were any errors during import.
  bool get hasErrors => errors.isNotEmpty;
}

/// Preloads places data in the background to warm up cache.
/// Call this early (e.g., on app startup or after login) to reduce perceived lag.
/// This is fire-and-forget - errors are silently ignored.
Future<void> preloadPlacesData() async {
  try {
    // Skip login check - let fetchPlaces handle it internally
    // This allows preload to be called anytime (before/after login)
    // If not logged in, it will just load local places which is still useful

    // Fire preload without blocking caller
    unawaited(
      PlacesService.fetchPlaces(forceRefresh: false).catchError((_) {
        // Silently ignore preload errors - return empty list
        return <Place>[];
      }),
    );
  } catch (_) {
    // Silently ignore preload errors
  }
}
