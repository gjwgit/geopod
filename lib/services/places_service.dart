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

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:http/http.dart' as http;
import 'package:solidpod/solidpod.dart';
import 'package:uuid/uuid.dart';

import 'package:geopod/services/geocoding_service.dart';

/// The file name for storing all places.
const String _placesFileName = 'places.json';

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
  String get displayTitle {
    if (note.length > 30) {
      return '${note.substring(0, 30)}...';
    }
    return note;
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
  static Future<String> _getFullFilePath() async {
    final dataDirPath = await getDataDirPath();
    return '$dataDirPath/$_placesFileName';
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
  static Future<List<Place>> fetchPlaces() async {
    final allPlaces = <Place>[];

    // Step 1: Load local canned examples.
    final localPlaces = await loadLocalPlaces();

    // Step 2: Load user's Pod places (if logged in).
    final podPlaces = await fetchPodPlaces();

    // Step 3: Merge - Pod places first (user data), then local examples.
    allPlaces.addAll(podPlaces);
    allPlaces.addAll(localPlaces);

    return allPlaces;
  }

  /// Fetches only the user's saved places from the Pod.
  static Future<List<Place>> fetchPodPlaces() async {
    final places = <Place>[];

    try {
      if (!await checkLoggedIn()) {
        return places;
      }

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
    } catch (_) {
      // Return empty list on error.
    }

    return places;
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

      // Only fetch Pod places (not local) for updating.
      final existingPlaces = await fetchPodPlaces();
      existingPlaces.insert(0, place);

      final jsonList = existingPlaces.map((p) => p.toJson()).toList();
      final jsonContent = jsonEncode(jsonList);

      return await _writeJsonFile(jsonContent);
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

      // Only fetch Pod places (not local) for updating.
      final existingPlaces = await fetchPodPlaces();
      existingPlaces.removeWhere((p) => p.id == placeId);

      final jsonList = existingPlaces.map((p) => p.toJson()).toList();
      final jsonContent = jsonEncode(jsonList);

      return await _writeJsonFile(jsonContent);
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

      return await _writeJsonFile(jsonContent);
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
      return await _writeJsonFile('[]');
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
      final index = existingPlaces.indexWhere((p) => p.id == updatedPlace.id);

      if (index == -1) {
        // Place not found, add as new.
        existingPlaces.insert(0, updatedPlace);
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
        existingPlaces[index] = placeToSave;
      }

      final jsonList = existingPlaces.map((p) => p.toJson()).toList();
      final jsonContent = jsonEncode(jsonList);

      return await _writeJsonFile(jsonContent);
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
