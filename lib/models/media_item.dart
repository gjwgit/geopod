/// MediaItem data model – represents a single audio or video resource.
///
// Time-stamp: <2026-02-28 GitHub Copilot>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
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
/// Authors: GitHub Copilot

library;

/// Discriminates between audio and video resources.
enum MediaType { audio, video }

/// A single media resource – either a bundled asset, a remote Pod file, or a
/// Pod-hosted item that is loaded on demand.
///
/// Exactly one of [assetPath] or [remoteUrl] or [podRelativePath] must be set.
class MediaItem {
  const MediaItem({
    required this.name,
    required this.type,
    this.assetPath,
    this.remoteUrl,
    this.podRelativePath,
    this.isEncrypted = false,
    this.podItemId,
    this.uploadedAt,
    this.locationIds = const [],
  }) : assert(
         assetPath != null || remoteUrl != null || podRelativePath != null,
         'MediaItem requires assetPath, remoteUrl, or podRelativePath.',
       );

  /// Human-readable label shown in the list tile.
  final String name;

  /// Audio or video.
  final MediaType type;

  /// Path within the Flutter asset bundle, e.g. `'assets/audio/example.mp3'`.
  /// `null` for remote / Pod items.
  final String? assetPath;

  /// Absolute URL for an externally-accessible resource (not behind Solid auth).
  /// `null` for asset-backed or Pod items.
  final String? remoteUrl;

  /// Path relative to the Pod **data** directory for items stored in the Pod,
  /// e.g. `'audio/example.mp3'` or `'audio/example.enc'`.
  /// `null` for asset-backed or external URL items.
  final String? podRelativePath;

  /// Whether the Pod file is encrypted (base64 + solidpod encryption).
  final bool isEncrypted;

  /// Stable identifier for the item in the Pod index. Usually a UUID.
  final String? podItemId;

  /// When this item was uploaded to the Pod.
  final DateTime? uploadedAt;

  /// IDs of the map POIs / places this media is linked to (many-to-many).
  /// A media item can be associated with multiple locations, and a location
  /// can have multiple media items.
  final List<String> locationIds;

  /// `true` when backed by a remote URL (not a bundled asset or Pod item).
  bool get isRemote => remoteUrl != null;

  /// `true` when this item lives in the user's Solid Pod.
  bool get isPodItem => podRelativePath != null;

  // ── JSON serialisation ───────────────────────────────────────────────────

  /// Parses [locationIds] from JSON, with backward-compat for legacy
  /// single-string `locationId` field.
  static List<String> _parseLocationIds(Map<String, dynamic> json) {
    final list = json['locationIds'];
    if (list is List) return List<String>.from(list);
    // Backward compat: legacy single-ID field.
    final single = json['locationId'] as String?;
    if (single != null && single.isNotEmpty) return [single];
    return const [];
  }

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      name: json['name'] as String,
      type: json['type'] == 'video' ? MediaType.video : MediaType.audio,
      podRelativePath: json['podRelativePath'] as String?,
      isEncrypted: (json['isEncrypted'] as bool?) ?? false,
      podItemId: json['podItemId'] as String?,
      uploadedAt: json['uploadedAt'] != null
          ? DateTime.tryParse(json['uploadedAt'] as String)
          : null,
      locationIds: _parseLocationIds(json),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type == MediaType.video ? 'video' : 'audio',
    if (podRelativePath != null) 'podRelativePath': podRelativePath,
    'isEncrypted': isEncrypted,
    if (podItemId != null) 'podItemId': podItemId,
    if (uploadedAt != null) 'uploadedAt': uploadedAt!.toIso8601String(),
    if (locationIds.isNotEmpty) 'locationIds': locationIds,
  };

  /// Create a copy with updated fields.
  MediaItem copyWith({
    String? name,
    MediaType? type,
    String? assetPath,
    String? remoteUrl,
    String? podRelativePath,
    bool? isEncrypted,
    String? podItemId,
    DateTime? uploadedAt,
    List<String>? locationIds,
  }) {
    return MediaItem(
      name: name ?? this.name,
      type: type ?? this.type,
      assetPath: assetPath ?? this.assetPath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      podRelativePath: podRelativePath ?? this.podRelativePath,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      podItemId: podItemId ?? this.podItemId,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      locationIds: locationIds ?? this.locationIds,
    );
  }
}
