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
  final path = _indexPath(type);
  // silentOnNotFound: 404 is the expected state before any media exists.
  final existing = await PodFileSystem.readFile(path, silentOnNotFound: true);
  if (existing != null) {
    // File already exists (empty or with items) – nothing to do.
    return;
  }
  await PodFileSystem.writeFile(
    path,
    '[]',
    contentType: PodContentType.json,
    createParentDirs: false,
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
    // silentOnNotFound: index files are bootstrapped by ensureIndexFiles() at
    // login, but a 404 can still occur in edge cases – e.g. the file was
    // manually deleted via the file browser, or this read races the
    // (unawaited) ensureIndexFiles() call during the first login.
    final content = await PodFileSystem.readFile(
      _indexPath(type),
      silentOnNotFound: true,
    );
    if (content == null) {
      // null means a hard error (401 unauthorised, network failure, 404, or
      // not logged in).  Do NOT cache – this is a transient failure.  The
      // next PlaceMediaSection open will retry once the condition clears.
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

// ── Index write ───────────────────────────────────────────────────────────

Future<bool> _writeIndex(MediaType type, List<MediaItem> items) async {
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
