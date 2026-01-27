/// Import and export functionality for places data.
///
// Time-stamp: <Wednesday 2026-01-28 09:03:29 +1100 Graham Williams>
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

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:uuid/uuid.dart';

import 'package:geopod/models/place.dart';

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

/// Service for importing and exporting places data.
class PlacesImportExport {
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
        name: 'places.json',
        bytes: bytes,
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
      final pickResult = await FilePicker.pickFiles(
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
}
