/// Path constants for media (audio / video) storage in the Solid Pod.
///
// Time-stamp: <2026-02-28 Miduo>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

// ── Directory names ──────────────────────────────────────────────────────────

/// Sub-directory under `geopod/data/` for audio files.
const String audioDirName = 'audio';

/// Sub-directory under `geopod/data/` for video files.
const String videoDirName = 'video';

// ── Index file names ─────────────────────────────────────────────────────────

/// JSON index file that lists all audio items.
const String audioIndexFileName = 'audio_index.json';

/// JSON index file that lists all video items.
const String videoIndexFileName = 'video_index.json';

// ── Path helpers (relative to the Pod data directory, passed to PodPath) ────
//
// PodPath.getFilePath('data/audio') → 'geopod/data/audio'
// so all relative paths below should start with 'data/'.

/// `data/audio`
String getAudioDirPath() => 'data/$audioDirName';

/// `data/video`
String getVideoDirPath() => 'data/$videoDirName';

/// `data/audio/audio_index.json`
String getAudioIndexPath() => 'data/$audioDirName/$audioIndexFileName';

/// `data/video/video_index.json`
String getVideoIndexPath() => 'data/$videoDirName/$videoIndexFileName';

/// `data/audio/<filename>`
String getAudioFilePath(String filename) => 'data/$audioDirName/$filename';

/// `data/video/<filename>`
String getVideoFilePath(String filename) => 'data/$videoDirName/$filename';

// ── MIME type helpers ─────────────────────────────────────────────────────────

/// Returns the best-guess MIME type for a file based on its extension.
String mimeTypeForFilename(String filename) {
  final ext = filename.split('.').last.toLowerCase();
  return _mimeMap[ext] ?? 'application/octet-stream';
}

const Map<String, String> _mimeMap = {
  'mp3': 'audio/mpeg',
  'mp4': 'video/mp4',
  'm4a': 'audio/mp4',
  'aac': 'audio/aac',
  'ogg': 'audio/ogg',
  'wav': 'audio/wav',
  'webm': 'audio/webm',
  'mov': 'video/quicktime',
  'mkv': 'video/x-matroska',
  'avi': 'video/x-msvideo',
  'webmv': 'video/webm',
};
