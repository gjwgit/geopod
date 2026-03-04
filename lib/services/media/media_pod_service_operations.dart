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

// Part of media_pod_service.dart – upload, delete, playback, and item-update
// operations.

part of 'media_pod_service.dart';

// ── Upload ────────────────────────────────────────────────────────────────

Future<MediaItem?> _uploadItem({
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

  // Read the index up-front so we can (a) detect duplicate filenames and
  // (b) reuse the list when adding the new item to the index at the end.
  final existingItems = await _readIndex(type);

  final safeFilename = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._\-]'), '_');
  // solidpod writePod requires encrypted files to end with `.ttl` (Turtle
  // format is the only format it accepts for encrypted content).
  // Follow the solidui convention: use `.enc.ttl` suffix so the file is
  // visually identifiable as encrypted while still passing solidpod's check.
  //
  // _resolveUnique also deduplicates filenames: if a file with the same name
  // already exists in the index it appends (1), (2), … automatically.
  final (storedFilename, displayName) = _resolveUnique(
    safeFilename,
    name,
    existingItems,
    encrypt,
  );
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
    name: displayName,
    type: type,
    podRelativePath: relPath,
    isEncrypted: encrypt,
    podItemId: id,
    uploadedAt: DateTime.now(),
  );

  // Update index (reuse the pre-read list to avoid a second round-trip).
  existingItems.add(item);
  await _writeIndex(type, existingItems);

  // Notify file browser that the directory contents have changed.
  final dirPath = type == MediaType.audio
      ? getAudioDirPath()
      : getVideoDirPath();
  PodDirectoryService.invalidateCache(dirPath);
  PodDirectoryService.notifyChange();

  return item;
}

// ── Delete ────────────────────────────────────────────────────────────────

Future<bool> _deleteItem(MediaItem item) async {
  if (!item.isPodItem) return false;
  if (!PodAuth.isLoggedInSync()) return false;

  // Delete the actual file.
  final deleted = await PodFileSystem.deleteFile(item.podRelativePath!);

  // Always update the index, even if the file delete "failed" (may be 404).
  final existing = await _readIndex(item.type);
  existing.removeWhere((i) => i.podRelativePath == item.podRelativePath);
  await _writeIndex(item.type, existing);

  // Notify file browser that the directory contents have changed.
  final dirPath = item.type == MediaType.audio
      ? getAudioDirPath()
      : getVideoDirPath();
  PodDirectoryService.invalidateCache(dirPath);
  PodDirectoryService.notifyChange();

  return deleted;
}

// ── Playback URL ──────────────────────────────────────────────────────────

Future<String?> _loadPlaybackUrl(MediaItem item) async {
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

// ── Duplicate-filename resolution ─────────────────────────────────────────

/// Returns a (storedFilename, displayName) pair that is unique within
/// [existing].
///
/// - [safeFilename]  – already-sanitised base filename (no path component).
/// - [displayName]   – user-visible name to display in the media list.
/// - [existing]      – current index items (used to detect clashes).
/// - [encrypt]       – whether the file will be stored encrypted.
///
/// If the filename already exists in the index, appends `(1)`, `(2)`, …
/// to the base part (before the extension) until a unique name is found.  The
/// display name receives the same numeric suffix so users can tell entries
/// apart in the UI.
(String storedFilename, String displayName) _resolveUnique(
  String safeFilename,
  String displayName,
  List<MediaItem> existing,
  bool encrypt,
) {
  // Build the set of stored filenames already in use.
  final usedFilenames = existing
      .map((i) => i.podRelativePath?.split('/').last)
      .whereType<String>()
      .toSet();

  String candidate = encrypt ? '$safeFilename.enc.ttl' : safeFilename;
  if (!usedFilenames.contains(candidate)) {
    return (candidate, displayName);
  }

  // Split safeFilename into base + extension (e.g. 'song' + '.mp3').
  final dotIdx = safeFilename.lastIndexOf('.');
  final base = dotIdx != -1 ? safeFilename.substring(0, dotIdx) : safeFilename;
  final ext = dotIdx != -1 ? safeFilename.substring(dotIdx) : '';

  int counter = 1;
  while (true) {
    final uniqueSafe = '$base($counter)$ext';
    candidate = encrypt ? '$uniqueSafe.enc.ttl' : uniqueSafe;
    if (!usedFilenames.contains(candidate)) {
      return (candidate, '$displayName ($counter)');
    }
    counter++;
  }
}

// ── Update item ───────────────────────────────────────────────────────────

Future<bool> _updateItem(MediaItem item) async {
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
  final ok = await _writeIndex(item.type, existing);

  // Notify the file browser that the index file content has changed so
  // any open directory views refresh their cached data.
  if (ok) {
    final dirPath = item.type == MediaType.audio
        ? getAudioDirPath()
        : getVideoDirPath();
    PodDirectoryService.invalidateCache(dirPath);
    PodDirectoryService.notifyChange();
  }
  return ok;
}
