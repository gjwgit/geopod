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
  try {
    await readPod(_indexSolidpodPath(type));
    // File already exists (empty or with items) – nothing to do.
    return;
  } on ResourceNotExistException {
    // Not found – create an empty encrypted index below.
  } catch (e) {
    // Any other failure (network, no security key yet) says nothing about
    // whether the index exists, so it must not be overwritten with '[]'.
    debugPrint('MediaPodService._ensureIndexFile: skipped ($e)');
    return;
  }
  try {
    // The index is encrypted with the media directory's inherited key, so
    // make sure that key/ACL exists before writing.
    await _ensureDir(type);
    // Tracked so closing the window waits for the write to land.
    await SolidPendingWrites.track(
      writePod(
        _indexSolidpodPath(type),
        '[]',
        encrypted: true,
        overwrite: true,
        inheritKeyFrom: _indexDirName(type),
      ),
    );
  } catch (e) {
    debugPrint('MediaPodService._ensureIndexFile: create failed ($e)');
  }
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

/// Reads the index, throwing if it exists but could not be read.
///
/// Every caller that writes the index back must use this rather than
/// [_readIndexOrEmpty]: treating a failed read as an empty index and then
/// writing it would wipe every other item.
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
  try {
    return List<MediaItem>.from(await fetch);
  } finally {
    // Clear the in-flight reference now that it has settled, failed or not,
    // so a failed fetch is retried next time.
    if (type == MediaType.audio) {
      if (identical(_audioFetch, fetch)) _audioFetch = null;
    } else {
      if (identical(_videoFetch, fetch)) _videoFetch = null;
    }
  }
}

/// Reads the index for display, treating an unreadable index as empty.
Future<List<MediaItem>> _readIndexOrEmpty(MediaType type) async {
  try {
    return await _readIndex(type);
  } catch (e) {
    debugPrint('MediaPodService: could not read ${_indexPath(type)} ($e)');
    return [];
  }
}

Future<List<MediaItem>> _fetchFromPod(MediaType type) async {
  // readPod decrypts the index. A missing index is the expected state before
  // any media exists and genuinely means "no items"; every other failure is
  // rethrown so writers do not mistake it for an empty index.
  String content;
  try {
    content = await readPod(_indexSolidpodPath(type));
  } on ResourceNotExistException {
    _setCache(type, []);
    return [];
  }
  if (content.trim().isEmpty) {
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
    await SolidPendingWrites.track(
      writePod(
        _indexSolidpodPath(type),
        content,
        encrypted: true,
        overwrite: true,
        inheritKeyFrom: _indexDirName(type),
      ),
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
