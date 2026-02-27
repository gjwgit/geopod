/// MediaItem data model – represents a single audio or video resource.
///
// Time-stamp: <2026-02-19 GitHub Copilot>
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

/// A single media resource – either a bundled asset or a remote Pod file.
///
/// Exactly one of [assetPath] or [remoteUrl] must be supplied.
class MediaItem {
  const MediaItem({
    required this.name,
    required this.type,
    this.assetPath,
    this.remoteUrl,
    this.locationId,
  }) : assert(
         assetPath != null || remoteUrl != null,
         'MediaItem requires either assetPath or remoteUrl.',
       );

  /// Human-readable label shown in the list tile.
  final String name;

  /// Audio or video.
  final MediaType type;

  /// Path within the Flutter asset bundle, e.g. `'assets/audio/example.mp3'`.
  /// `null` for remote items.
  final String? assetPath;

  /// Absolute URL for a Pod-hosted or external resource.
  /// `null` for asset-backed items.
  final String? remoteUrl;

  /// Optional ID of the map POI this media is linked to (Issue #27).
  final String? locationId;

  /// `true` when backed by a remote URL rather than a bundled asset.
  bool get isRemote => remoteUrl != null;
}
