/// Shared catalogue of bundled demo media items.
///
// Time-stamp: <2026-03-01 Miduo>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:geopod/models/media_item.dart';

/// Bundled demo audio files that ship with the app.
///
/// Each item has a stable [MediaItem.podItemId] so place-links survive
/// across sessions (they are upserted into the Pod index on first link).
const List<MediaItem> builtinAudioItems = [
  MediaItem(
    name: 'Example Audio',
    type: MediaType.audio,
    assetPath: 'assets/audio/example.mp3',
    podItemId: 'builtin-audio-example',
  ),
];

/// Bundled demo video files that ship with the app.
const List<MediaItem> builtinVideoItems = [
  MediaItem(
    name: 'Example Video 1',
    type: MediaType.video,
    assetPath: 'assets/video/example1.mp4',
    podItemId: 'builtin-video-example1',
  ),
  MediaItem(
    name: 'Example Video 2',
    type: MediaType.video,
    assetPath: 'assets/video/example2.mp4',
    podItemId: 'builtin-video-example2',
  ),
];

/// All bundled demo items combined.
const List<MediaItem> allBuiltinItems = [
  ...builtinAudioItems,
  ...builtinVideoItems,
];
