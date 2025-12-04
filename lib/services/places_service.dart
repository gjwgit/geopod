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

import 'package:flutter/material.dart';

import 'package:solidpod/solidpod.dart';

/// The file name for storing all places (single file with JSON array).
const String placesFileName = 'places.json';

/// Data model representing a saved place.
class Place {
  final String id;
  final double lat;
  final double lng;
  final String note;
  final String timestamp;

  Place({
    required this.id,
    required this.lat,
    required this.lng,
    required this.note,
    required this.timestamp,
  });

  /// Creates a Place from JSON map.
  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      note: json['note'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
    );
  }

  /// Converts Place to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lat': lat,
      'lng': lng,
      'note': note,
      'timestamp': timestamp,
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
/// Uses a single JSON file (places.json) containing an array of places.
/// This approach:
/// - Reads existing places before writing
/// - Appends new places to the list
/// - Writes the complete list back
class PlacesService {
  /// Fetches all saved places from the user's Pod.
  ///
  /// Returns an empty list if:
  /// - User is not logged in
  /// - File doesn't exist
  /// - File is empty or corrupt
  static Future<List<Place>> fetchPlaces() async {
    final places = <Place>[];

    try {
      // Check if user is logged in.
      if (!await checkLoggedIn()) {
        debugPrint('PlacesService: User not logged in');
        return places;
      }

      // Try to read the places file.
      try {
        final content = await readPod(placesFileName);

        // Parse the JSON content.
        final decoded = jsonDecode(content);

        // Handle both array and object formats for backwards compatibility.
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              places.add(Place.fromJson(item));
            }
          }
        } else if (decoded is Map<String, dynamic>) {
          // Single object - wrap in list (backwards compatibility).
          places.add(Place.fromJson(decoded));
        }

        debugPrint('PlacesService: Loaded ${places.length} places');
      } catch (e) {
        // File might not exist yet - that's okay, return empty list.
        debugPrint('PlacesService: Could not read places file: $e');
      }

      // Sort by timestamp (newest first).
      places.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      debugPrint('PlacesService: Error fetching places: $e');
    }

    return places;
  }

  /// Adds a new place to the Pod.
  ///
  /// This method:
  /// 1. Reads the existing places list
  /// 2. Appends the new place
  /// 3. Writes the complete list back
  static Future<bool> addPlace(
    Place place,
    BuildContext context,
    Widget returnWidget,
  ) async {
    try {
      if (!await checkLoggedIn()) {
        throw Exception('User is not authenticated. Please log in first.');
      }

      // Read existing places.
      final existingPlaces = await fetchPlaces();

      // Add the new place.
      existingPlaces.insert(0, place); // Add at the beginning (newest first).

      // Convert to JSON array.
      final jsonList = existingPlaces.map((p) => p.toJson()).toList();
      final jsonContent = jsonEncode(jsonList);

      // Write back to Pod.
      // ignore: use_build_context_synchronously
      final status = await writePod(
        placesFileName,
        jsonContent,
        context,
        returnWidget,
        encrypted: false,
      );

      return status == SolidFunctionCallStatus.success;
    } catch (e) {
      debugPrint('PlacesService: Error adding place: $e');
      return false;
    }
  }

  /// Deletes a place from the Pod by its ID.
  static Future<bool> deletePlace(
    String placeId,
    BuildContext context,
    Widget returnWidget,
  ) async {
    try {
      if (!await checkLoggedIn()) {
        return false;
      }

      // Read existing places.
      final existingPlaces = await fetchPlaces();

      // Remove the place with matching ID.
      existingPlaces.removeWhere((p) => p.id == placeId);

      // Convert to JSON array.
      final jsonList = existingPlaces.map((p) => p.toJson()).toList();
      final jsonContent = jsonEncode(jsonList);

      // Write back to Pod.
      // ignore: use_build_context_synchronously
      final status = await writePod(
        placesFileName,
        jsonContent,
        context,
        returnWidget,
        encrypted: false,
      );

      return status == SolidFunctionCallStatus.success;
    } catch (e) {
      debugPrint('PlacesService: Error deleting place: $e');
      return false;
    }
  }
}
