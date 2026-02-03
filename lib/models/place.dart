/// Data model representing a saved place.
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

  /// Whether this place is stored encrypted.
  /// Encrypted places are stored in a separate encrypted file.
  final bool isEncrypted;

  Place({
    required this.id,
    required this.lat,
    required this.lng,
    required this.note,
    required this.timestamp,
    this.address,
    this.isLocal = false,
    this.isEncrypted = false,
  });

  /// Creates a Place from JSON map.
  ///
  /// [isLocalSource] indicates if the JSON comes from local assets.

  factory Place.fromJson(
    Map<String, dynamic> json, {
    bool isLocalSource = false,
    bool isEncryptedSource = false,
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
      isEncrypted: isEncryptedSource,
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

  /// Creates a copy of this Place with optional field overrides.

  Place copyWith({
    String? id,
    double? lat,
    double? lng,
    String? note,
    String? timestamp,
    String? address,
    bool? isLocal,
    bool? isEncrypted,
  }) {
    return Place(
      id: id ?? this.id,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      note: note ?? this.note,
      timestamp: timestamp ?? this.timestamp,
      address: address ?? this.address,
      isLocal: isLocal ?? this.isLocal,
      isEncrypted: isEncrypted ?? this.isEncrypted,
    );
  }
}
