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

import 'package:http/http.dart' as http;
import 'package:solidpod/solidpod.dart';

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

  Place({
    required this.id,
    required this.lat,
    required this.lng,
    required this.note,
    required this.timestamp,
    this.address,
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
      address: json['address'] as String?,
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
  /// Gets the full file path within the app's data directory.
  static Future<String> _getFullFilePath() async {
    final dataDirPath = await getDataDirPath();
    return '$dataDirPath/$_placesFileName';
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

  /// Fetches all saved places from the user's Pod.
  static Future<List<Place>> fetchPlaces() async {
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
                places.add(Place.fromJson(item));
              } catch (_) {
                // Skip malformed entries.
              }
            }
          }
        } else if (decoded is Map<String, dynamic>) {
          try {
            places.add(Place.fromJson(decoded));
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

      final existingPlaces = await fetchPlaces();
      existingPlaces.insert(0, place);

      final jsonList = existingPlaces.map((p) => p.toJson()).toList();
      final jsonContent = jsonEncode(jsonList);

      return await _writeJsonFile(jsonContent);
    } catch (_) {
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

      final existingPlaces = await fetchPlaces();
      existingPlaces.removeWhere((p) => p.id == placeId);

      final jsonList = existingPlaces.map((p) => p.toJson()).toList();
      final jsonContent = jsonEncode(jsonList);

      return await _writeJsonFile(jsonContent);
    } catch (_) {
      return false;
    }
  }
}
