/// Solid Pod service for managing audio and video media items.
///
// Time-stamp: <2026-02-28 GitHub Copilot>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

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
import 'package:geopod/services/pod/pod_file_system.dart';
import 'package:geopod/services/pod/pod_http.dart';
import 'package:geopod/services/pod/pod_path.dart';
import 'package:geopod/utils/platform_io.dart'
    if (dart.library.html) 'package:geopod/utils/platform_web.dart';

const _uuid = Uuid();

/// Service that manages audio and video items on the user's Solid Pod.
///
/// **Storage layout** (all paths relative to Pod data directory):
/// ```
/// audio/
///   audio_index.json          ← unencrypted metadata index
///   <filename>.mp3            ← unencrypted binary file
///   <filename>.enc            ← encrypted base-64 ciphertext (solidpod)
/// video/
///   video_index.json
///   <filename>.mp4
///   <filename>.enc
/// ```
class MediaPodService {
  MediaPodService._();

  // Per-session flags: setInheritKeyDir only needs to run once per type per session.
  static bool _audioKeyReady = false;
  static bool _videoKeyReady = false;

  // ── In-memory index cache ─────────────────────────────────────────────────
  // Avoids repeated Pod round-trips when querying or updating the same index
  // within the same session.  Both caches are invalidated on write.

  static List<MediaItem>? _audioCache;
  static List<MediaItem>? _videoCache;

  /// In-flight fetch futures – ensures only one Pod request per type is
  /// issued at a time even when many callers ask concurrently.
  static Future<List<MediaItem>>? _audioFetch;
  static Future<List<MediaItem>>? _videoFetch;

  static List<MediaItem>? _getCache(MediaType type) =>
      type == MediaType.audio ? _audioCache : _videoCache;

  static void _setCache(MediaType type, List<MediaItem> items) {
    if (type == MediaType.audio) {
      _audioCache = items;
    } else {
      _videoCache = items;
    }
  }

  static void _invalidateCache(MediaType type) {
    if (type == MediaType.audio) {
      _audioCache = null;
      _audioFetch = null;
    } else {
      _videoCache = null;
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

  // ── Directory initialisation ─────────────────────────────────────────────

  /// Call before any encrypted write to ensure the ACL file and encryption
  /// key are set up for the directory. Skipped after the first successful
  /// call per session (the directory is guaranteed to exist after Pod init).
  static Future<void> _ensureDir(MediaType type) async {
    final alreadyReady = type == MediaType.audio
        ? _audioKeyReady
        : _videoKeyReady;
    if (alreadyReady) return;

    final relDir = type == MediaType.audio
        ? getAudioDirPath()
        : getVideoDirPath();
    try {
      final dirUrl = await PodPath.getDirUrl(relDir);
      await setInheritKeyDir(dirUrl, createAcl: true);
      if (type == MediaType.audio) {
        _audioKeyReady = true;
      } else {
        _videoKeyReady = true;
      }
    } catch (e) {
      debugPrint('MediaPodService._ensureDir error: $e');
    }
  }

  // ── Index helpers ─────────────────────────────────────────────────────────

  static String _indexPath(MediaType type) =>
      type == MediaType.audio ? getAudioIndexPath() : getVideoIndexPath();

  static Future<List<MediaItem>> _readIndex(MediaType type) async {
    // Return cached copy if available – avoids a Pod round-trip.
    final cached = _getCache(type);
    if (cached != null) return List<MediaItem>.from(cached);

    // If a fetch is already in-flight, share it instead of issuing a second
    // identical HTTP request.
    final existing = type == MediaType.audio ? _audioFetch : _videoFetch;
    if (existing != null) return List<MediaItem>.from(await existing);

    // No cache, no in-flight request: start a new fetch.
    final fetch = _fetchFromPod(type);
    if (type == MediaType.audio) {
      _audioFetch = fetch;
    } else {
      _videoFetch = fetch;
    }
    final items = await fetch;
    // Clear the in-flight reference now that it has settled.
    if (type == MediaType.audio) {
      _audioFetch = null;
    } else {
      _videoFetch = null;
    }
    return List<MediaItem>.from(items);
  }

  static Future<List<MediaItem>> _fetchFromPod(MediaType type) async {
    try {
      // silentOnNotFound: 404 is the normal state before any media is uploaded.
      final content = await PodFileSystem.readFile(
        _indexPath(type),
        silentOnNotFound: true,
      );
      if (content == null) {
        // null means a hard error (401 unauthorised, network failure, not
        // logged in).  Do NOT cache – this is a transient failure.  The next
        // PlaceMediaSection open will retry, and will succeed once auth is
        // restored or the Pod becomes reachable.
        debugPrint(
          'MediaPodService._fetchFromPod: could not read ${_indexPath(type)} – skipping cache',
        );
        return [];
      }
      if (content.isEmpty) {
        // File found but empty – or the index was returned as an empty string.
        // Safe to cache as an empty list.
        _setCache(type, []);
        return [];
      }
      final list = jsonDecode(content) as List<dynamic>;
      final items = list
          .whereType<Map<String, dynamic>>()
          .map(MediaItem.fromJson)
          .toList();
      _setCache(type, items);
      return items;
    } catch (e) {
      debugPrint('MediaPodService._fetchFromPod error: $e');
      return [];
    }
  }

  static Future<bool> _writeIndex(MediaType type, List<MediaItem> items) async {
    try {
      final content = jsonEncode(items.map((i) => i.toJson()).toList());
      final ok = await PodFileSystem.writeFile(
        _indexPath(type),
        content,
        contentType: PodContentType.json,
        createParentDirs: false,
      );
      if (ok) {
        // Update the cache so subsequent reads are still fast.
        _setCache(type, List<MediaItem>.from(items));
      } else {
        // Write failed – invalidate so next read fetches fresh data.
        _invalidateCache(type);
      }
      return ok;
    } catch (e) {
      debugPrint('MediaPodService._writeIndex error: $e');
      _invalidateCache(type);
      return false;
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns all [type] media items stored in the Pod.
  /// Includes only Pod-hosted items; bundled assets are managed by the page.
  static Future<List<MediaItem>> listItems(MediaType type) async {
    if (!PodAuth.isLoggedInSync()) return [];
    return _readIndex(type);
  }

  /// Uploads [bytes] as a new media item to the Pod.
  ///
  /// * [name]      – display name
  /// * [filename]  – file name with extension, e.g. `'song.mp3'`
  /// * [bytes]     – raw file content
  /// * [type]      – audio or video
  /// * [encrypt]   – if `true`, base64-encodes and stores via solidpod encryption
  ///
  /// Returns the created [MediaItem] on success, `null` on failure.
  static Future<MediaItem?> uploadItem({
    required String name,
    required String filename,
    required Uint8List bytes,
    required MediaType type,
    bool encrypt = false,
  }) async {
    if (!PodAuth.isLoggedInSync()) {
      debugPrint('MediaPodService.uploadItem: not logged in');
      return null;
    }

    // Only encrypted uploads need ACL/key setup for the directory.
    if (encrypt) await _ensureDir(type);

    final id = _uuid.v4();
    final safeFilename = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._\-]'), '_');
    // solidpod writePod requires encrypted files to end with `.ttl` (Turtle
    // format is the only format it accepts for encrypted content).
    // Follow the solidui convention: use `.enc.ttl` suffix so the file is
    // visually identifiable as encrypted while still passing solidpod's check.
    final storedFilename = encrypt ? '$safeFilename.enc.ttl' : safeFilename;
    final relPath = type == MediaType.audio
        ? getAudioFilePath(storedFilename)
        : getVideoFilePath(storedFilename);

    bool uploadOk;
    if (encrypt) {
      // Base64-encode the bytes and store as a solidpod encrypted file.
      // writePod paths use PathType.relativeToData, so pass just the
      // subdirectory name (e.g. 'audio') for inheritKeyFrom.
      final base64Content = base64Encode(bytes);
      // relPath is 'data/audio/file.enc'; solidpod needs 'audio/file.enc'.
      final solidpodRelPath = relPath.startsWith('data/')
          ? relPath.substring('data/'.length)
          : relPath;
      final solidpodDirPath = type == MediaType.audio
          ? audioDirName
          : videoDirName;
      try {
        await writePod(
          solidpodRelPath,
          base64Content,
          encrypted: true,
          overwrite: true,
          inheritKeyFrom: solidpodDirPath,
        );
        uploadOk = true;
      } catch (e) {
        debugPrint('MediaPodService.uploadItem writePod error: $e');
        uploadOk = false;
      }
    } else {
      // Raw binary PUT.
      final mimeType = mimeTypeForFilename(filename);
      final url = await PodPath.getFileUrl(relPath);
      final response = await PodHttp.putBinary(url, bytes, mimeType);
      uploadOk = response.isSuccess;
      if (!uploadOk) {
        debugPrint(
          'MediaPodService.uploadItem putBinary failed: ${response.statusCode} ${response.body}',
        );
      }
    }

    if (!uploadOk) return null;

    final item = MediaItem(
      name: name,
      type: type,
      podRelativePath: relPath,
      isEncrypted: encrypt,
      podItemId: id,
      uploadedAt: DateTime.now(),
    );

    // Update index.
    final existing = await _readIndex(type);
    existing.add(item);
    await _writeIndex(type, existing);

    return item;
  }

  /// Deletes [item] from the Pod and removes it from the index.
  static Future<bool> deleteItem(MediaItem item) async {
    if (!item.isPodItem) return false;
    if (!PodAuth.isLoggedInSync()) return false;

    // Delete the actual file.
    final deleted = await PodFileSystem.deleteFile(item.podRelativePath!);

    // Always update the index, even if the file delete "failed" (may be 404).
    final existing = await _readIndex(item.type);
    existing.removeWhere((i) => i.podRelativePath == item.podRelativePath);
    await _writeIndex(item.type, existing);

    return deleted;
  }

  /// Downloads the media bytes for [item] and returns a local playback URL.
  ///
  /// * For unencrypted items: fetches raw bytes via authenticated GET.
  /// * For encrypted items: uses solidpod `readPod` to decrypt, then
  ///   base64-decodes the result back to bytes.
  ///
  /// Returns `null` if downloading or decryption fails.
  static Future<String?> loadPlaybackUrl(MediaItem item) async {
    if (!item.isPodItem) return null;
    if (!PodAuth.isLoggedInSync()) return null;

    final relPath = item.podRelativePath!;
    Uint8List? bytes;

    if (item.isEncrypted) {
      // readPod uses PathType.relativeToData, strip 'data/' prefix.
      final solidpodRelPath = relPath.startsWith('data/')
          ? relPath.substring('data/'.length)
          : relPath;
      final content = await readPod(solidpodRelPath);
      if (content == SolidFunctionCallStatus.notLoggedIn.toString() ||
          content == SolidFunctionCallStatus.fail.toString() ||
          content.isEmpty) {
        debugPrint('MediaPodService.loadPlaybackUrl: readPod failed');
        return null;
      }
      try {
        bytes = base64Decode(content.trim());
      } catch (e) {
        debugPrint('MediaPodService.loadPlaybackUrl: base64 decode error: $e');
        return null;
      }
    } else {
      // Download raw bytes with auth headers.
      final url = await PodPath.getFileUrl(relPath);
      bytes = await PodHttp.getBytes(url);
    }

    if (bytes == null) return null;

    // Determine the original filename (remove .enc suffix if present).
    var filename = relPath.split('/').last;
    if (filename.endsWith('.enc')) {
      filename = filename.substring(0, filename.length - 4);
    }

    final mimeType = mimeTypeForFilename(filename);
    return bytesToPlaybackUrl(bytes, mimeType, filename);
  }

  /// Releases the local playback URL created by [loadPlaybackUrl].
  /// Should be called when the player widget is disposed.
  static Future<void> releasePlaybackUrl(String url) async {
    await revokePlaybackUrl(url);
  }

  /// Updates (or on first link, inserts) an item's metadata in the Pod index.
  ///
  /// **Matching:** the item is located by [MediaItem.podItemId].
  ///
  /// **Upsert for bundled assets:** Asset items (`assetPath != null`,
  /// `podRelativePath == null`) that have been given a stable [podItemId] are
  /// appended to the index on their first link.  This lets [PlaceMediaSection]
  /// discover them without needing a separate link store.
  ///
  /// Returns `true` if the index was written successfully, `false` otherwise.
  static Future<bool> updateItem(MediaItem item) async {
    // Remote-URL items with no podItemId cannot be indexed.
    if (!item.isPodItem && item.podItemId == null) return false;
    if (!PodAuth.isLoggedInSync()) return false;

    final existing = await _readIndex(item.type);
    final idx = existing.indexWhere((i) => i.podItemId == item.podItemId);
    if (idx == -1) {
      // First-time registration of a built-in asset item: append to the index.
      existing.add(item);
    } else {
      existing[idx] = item;
    }
    return _writeIndex(item.type, existing);
  }
}
