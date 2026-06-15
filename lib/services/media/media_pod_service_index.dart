/// Solid Pod service for managing audio and video media items.
///
// Time-stamp: <2026-03-04 Miduo>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.
///
/// Authors: Miduo

// Part of media_pod_service.dart – index I/O, Pod bootstrapping,
// directory initialisation, and index read/write helpers.

part of 'media_pod_service.dart';

// ── Index path ────────────────────────────────────────────────────────────

String _indexPath(MediaType type) =>
    type == MediaType.audio ? getAudioIndexPath() : getVideoIndexPath();

// ── Pod index bootstrapping ───────────────────────────────────────────────

/// Ensures that both media index files exist on the Pod.
Future<void> _ensureIndexFiles() async {
  if (!await PodAuth.isLoggedIn()) return;
  await Future.wait([
    _ensureIndexFile(MediaType.audio),
    _ensureIndexFile(MediaType.video),
  ]);
}

Future<void> _ensureIndexFile(MediaType type) async {
  // readPod throws when the file is absent (the expected state before any
  // media exists); that is caught so we then create an empty encrypted index.
  try {
    await readPod(_indexSolidpodPath(type));
    // File already exists (empty or with items) – nothing to do.
    return;
  } catch (_) {
    // Not found – create an empty encrypted index below.
  }
  // The index is encrypted with the media directory's inherited key, so make
  // sure that key/ACL exists before writing.
  await _ensureDir(type);
  await writePod(
    _indexSolidpodPath(type),
    '[]',
    encrypted: true,
    overwrite: true,
    inheritKeyFrom: _indexDirName(type),
  );
}

// ── Directory initialisation ──────────────────────────────────────────────

/// Ensures the ACL file and encryption key are set up for the directory.
/// Skipped after the first successful call per session.
Future<void> _ensureDir(MediaType type) async {
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

// ── Index read ────────────────────────────────────────────────────────────

Future<List<MediaItem>> _readIndex(MediaType type) async {
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

Future<List<MediaItem>> _fetchFromPod(MediaType type) async {
  try {
    // readPod transparently decrypts encrypted indexes and also reads any
    // legacy plaintext index, so old data keeps working. It throws when the
    // file is missing; that is the expected pre-bootstrap state and is treated
    // as an empty/transient result (not cached).
    String content;
    try {
      content = await readPod(_indexSolidpodPath(type));
    } catch (e) {
      debugPrint(
        'MediaPodService._fetchFromPod: could not read ${_indexPath(type)} – skipping cache ($e)',
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

// ── Index encryption helpers ──────────────────────────────────────────────

/// solidpod relative path for an index file (strips the leading 'data/').
String _indexSolidpodPath(MediaType type) {
  final p = _indexPath(type);
  return p.startsWith('data/') ? p.substring('data/'.length) : p;
}

/// The directory (under data/) whose inherited key encrypts the index.
String _indexDirName(MediaType type) =>
    type == MediaType.audio ? audioDirName : videoDirName;

// ── Index write ───────────────────────────────────────────────────────────

Future<bool> _writeIndex(MediaType type, List<MediaItem> items) async {
  try {
    final content = jsonEncode(items.map((i) => i.toJson()).toList());
    // The index is always encrypted (it lists private items too), so ensure
    // the media directory's inherited key/ACL exists before writing — even for
    // unencrypted-media uploads, which would otherwise not have set it up.
    await _ensureDir(type);
    await writePod(
      _indexSolidpodPath(type),
      content,
      encrypted: true,
      overwrite: true,
      inheritKeyFrom: _indexDirName(type),
    );
    // writePod throws on failure (handled below), so reaching here is success.
    // Update the cache so subsequent reads are still fast.
    _setCache(type, List<MediaItem>.from(items));
    return true;
  } catch (e) {
    debugPrint('MediaPodService._writeIndex error: $e');
    _invalidateCache(type);
    return false;
  }
}
