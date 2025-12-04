/// Geocoding service using OpenStreetMap Nominatim API.
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

import 'package:http/http.dart' as http;

/// Service for reverse geocoding coordinates to human-readable addresses.
///
/// Uses OpenStreetMap's Nominatim API which is free and works on both
/// Web and Desktop platforms without requiring any API keys.
class GeocodingService {
  /// Nominatim API endpoint for reverse geocoding.
  static const String _nominatimEndpoint =
      'https://nominatim.openstreetmap.org/reverse';

  /// User-Agent header required by Nominatim API.
  static const String _userAgent = 'GeopodApp/1.0 (Flutter)';

  /// Converts latitude/longitude coordinates to a human-readable address.
  ///
  /// Returns "Address not found" if the request fails or no address is found.
  /// Always returns addresses in English.
  static Future<String> getAddress(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        '$_nominatimEndpoint?format=json&lat=$lat&lon=$lng'
        '&zoom=18&addressdetails=1&accept-language=en',
      );

      final response = await http
          .get(
            uri,
            headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Request timed out'),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final displayName = data['display_name'] as String?;

        if (displayName != null && displayName.isNotEmpty) {
          return displayName;
        }
      }

      return 'Address not found';
    } catch (_) {
      return 'Address not found';
    }
  }

  /// Gets a shortened version of the address (city, state, country).
  ///
  /// This extracts key parts from the full address for display in limited space.
  static Future<String> getShortAddress(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        '$_nominatimEndpoint?format=json&lat=$lat&lon=$lng'
        '&zoom=14&addressdetails=1&accept-language=en',
      );

      final response = await http
          .get(
            uri,
            headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;

        if (address != null) {
          final parts = <String>[];

          final suburb =
              address['suburb'] ?? address['city'] ?? address['town'];
          if (suburb != null) parts.add(suburb as String);

          final state = address['state'];
          if (state != null) parts.add(state as String);

          final country = address['country'];
          if (country != null) parts.add(country as String);

          if (parts.isNotEmpty) {
            return parts.join(', ');
          }
        }

        final displayName = data['display_name'] as String?;
        if (displayName != null) {
          if (displayName.length > 50) {
            return '${displayName.substring(0, 47)}...';
          }
          return displayName;
        }
      }

      return 'Unknown location';
    } catch (_) {
      return 'Unknown location';
    }
  }
}
