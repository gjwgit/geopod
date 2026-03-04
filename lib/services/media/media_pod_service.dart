/// Solid Pod service for managing audio and video media items.
///
// Time-stamp: <2026-02-28 Miduo>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.
///
/// Authors: Miduo

// ignore_for_file: use_build_context_synchronously

library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:solidpod/solidpod.dart'
    show readPod, writePod, setInheritKeyDir, SolidFunctionCallStatus;
import 'package:uuid/uuid.dart';

import 'package:geopod/models/media_item.dart';
import 'package:geopod/services/media/media_pod_paths.dart';
import 'package:geopod/services/pod/pod_auth.dart';
import 'package:geopod/services/pod/pod_directory_service.dart';
import 'package:geopod/services/pod/pod_file_system.dart';
import 'package:geopod/services/pod/pod_http.dart';
import 'package:geopod/services/pod/pod_path.dart';
import 'package:geopod/utils/platform_io.dart'
    if (dart.library.html) 'package:geopod/utils/platform_web.dart';

part 'media_pod_service_index.dart';
part 'media_pod_service_operations.dart';
part 'media_pod_service_links.dart';

const _uuid = Uuid();

// Library-private state shared across all part files in this library.

// Per-session flags: setInheritKeyDir only needs to run once per type per session.
bool _audioKeyReady = false;
bool _videoKeyReady = false;

// In-memory index cache - avoids repeated Pod round-trips within a session.
// Both caches are invalidated on write.
List<MediaItem>? _audioCache;
List<MediaItem>? _videoCache;

/// In-flight fetch futures - ensures only one Pod request per type is
/// issued at a time even when many callers ask concurrently.
Future<List<MediaItem>>? _audioFetch;
Future<List<MediaItem>>? _videoFetch;

// Library-private cache helpers - shared across all part files.

List<MediaItem>? _getCache(MediaType type) =>
    type == MediaType.audio ? _audioCache : _videoCache;

void _setCache(MediaType type, List<MediaItem> items) {
  if (type == MediaType.audio) {
    _audioCache = items;
  } else {
    _videoCache = items;
  }
}

void _invalidateCache(MediaType type) {
  if (type == MediaType.audio) {
    _audioCache = null;
    _audioFetch = null;
  } else {
    _videoCache = null;
    _videoFetch = null;
  }
}

/// Service that manages audio and video items on the user''s Solid Pod.
///
/// **Storage layout** (all paths relative to Pod data directory):
/// ```
/// audio/
///   audio_index.json          <- unencrypted metadata index
///   <filename>.mp3            <- unencrypted binary file
///   <filename>.enc            <- encrypted base-64 ciphertext (solidpod)
/// video/
///   video_index.json
///   <filename>.mp4
///   <filename>.enc
/// ```
class MediaPodService {
  MediaPodService._();

  // Cache management

  /// Clear the in-memory cache for a specific media type.
  ///
  /// Use this when an index file is externally deleted (e.g. via the file
  /// browser) so that the next [listItems] call re-fetches from the Pod.
  static void clearCacheForType(MediaType type) {
    _invalidateCache(type);
    if (type == MediaType.audio) {
      _audioFetch = null;
    } else {
      _videoFetch = null;
    }
  }

  /// Clears both in-memory caches.  Call when the user logs out or when a
  /// full refresh is needed.
  static void clearCache() {
    _audioCache = null;
    _videoCache = null;
    _audioFetch = null;
    _videoFetch = null;
  }

  // Public API
  // Implementations live in the part files; the class methods are thin wrappers.

  /// Ensures that both media index files exist on the Pod.
  ///
  /// Called once after login so that the first [listItems] request does not
  /// produce spurious 404 responses.  If the files already exist nothing is
  /// written.  Safe to call with [unawaited] - failures are logged but do not
  /// propagate.
  static Future<void> ensureIndexFiles() => _ensureIndexFiles();

  /// Returns all [type] media items stored in the Pod.
  /// Includes only Pod-hosted items; bundled assets are managed by the page.
  static Future<List<MediaItem>> listItems(MediaType type) async {
    if (!PodAuth.isLoggedInSync()) return [];
    return _readIndex(type);
  }

  /// Uploads [bytes] as a new media item to the Pod.
  ///
  /// * [name]      - display name
  /// * [filename]  - file name with extension, e.g. `''song.mp3''`
  /// * [bytes]     - raw file content
  /// * [type]      - audio or video
  /// * [encrypt]   - if `true`, base64-encodes and stores via solidpod encryption
  ///
  /// Returns the created [MediaItem] on success, `null` on failure.
  static Future<MediaItem?> uploadItem({
    required String name,
    required String filename,
    required Uint8List bytes,
    required MediaType type,
    bool encrypt = false,
  }) => _uploadItem(
    name: name,
    filename: filename,
    bytes: bytes,
    type: type,
    encrypt: encrypt,
  );

  /// Deletes [item] from the Pod and removes it from the index.
  static Future<bool> deleteItem(MediaItem item) => _deleteItem(item);

  /// Downloads the media bytes for [item] and returns a local playback URL.
  ///
  /// * For unencrypted items: fetches raw bytes via authenticated GET.
  /// * For encrypted items: uses solidpod `readPod` to decrypt, then
  ///   base64-decodes the result back to bytes.
  ///
  /// Returns `null` if downloading or decryption fails.
  static Future<String?> loadPlaybackUrl(MediaItem item) =>
      _loadPlaybackUrl(item);

  /// Releases the local playback URL created by [loadPlaybackUrl].
  /// Should be called when the player widget is disposed.
  static Future<void> releasePlaybackUrl(String url) => revokePlaybackUrl(url);

  /// Updates (or on first link, inserts) an item''s metadata in the Pod index.
  ///
  /// **Matching:** the item is located by [MediaItem.podItemId].
  ///
  /// **Upsert for bundled assets:** Asset items (`assetPath != null`,
  /// `podRelativePath == null`) that have been given a stable [podItemId] are
  /// appended to the index on their first link.  This lets [PlaceMediaSection]
  /// discover them without needing a separate link store.
  ///
  /// Returns `true` if the index was written successfully, `false` otherwise.
  static Future<bool> updateItem(MediaItem item) => _updateItem(item);

  // Place-link helpers

  /// Synchronously checks the in-memory index cache to determine whether
  /// [placeId] has any linked media items (audio or video).
  ///
  /// Returns `null` if either media index has not been loaded into cache yet
  /// (caller should treat as "unknown", not "no links").
  /// Returns `true` / `false` once both caches are populated.
  ///
  /// This is a pure cache read - no network request is made.
  static bool? hasLinkedMediaSync(String placeId) {
    final audio = _audioCache;
    final video = _videoCache;
    if (audio == null || video == null) return null;
    return [...audio, ...video].any((i) => i.locationIds.contains(placeId));
  }

  /// Removes [placeId] from every media item''s [MediaItem.locationIds] in
  /// both audio and video indices and persists the changes to the Pod.
  ///
  /// This is a fire-and-forget cleanup called when a place is deleted so that
  /// media items do not keep stale location references.
  ///
  /// Runs in the background without blocking the caller.
  static void unlinkAllForPlace(String placeId) =>
      _unlinkAllForPlaceAsync(placeId);

  /// Clears [MediaItem.locationIds] for ALL media items in both indices.
  ///
  /// Called when all places are deleted so no media item references a
  /// now-nonexistent place.
  static void clearAllPlaceLinks() => _clearAllPlaceLinksAsync();
}
