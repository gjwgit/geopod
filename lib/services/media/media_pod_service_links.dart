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

// Part of media_pod_service.dart – place-link management helpers.

part of 'media_pod_service.dart';

// ── Unlink a single place ─────────────────────────────────────────────────

Future<void> _unlinkAllForPlaceAsync(String placeId) async {
  try {
    if (!PodAuth.isLoggedInSync()) return;

    final results = await Future.wait([
      _readIndex(MediaType.audio),
      _readIndex(MediaType.video),
    ]);

    Future<void> cleanType(MediaType type, List<MediaItem> items) async {
      final changed = items
          .where((i) => i.locationIds.contains(placeId))
          .toList();
      if (changed.isEmpty) return;
      final updated = items.map((i) {
        if (!i.locationIds.contains(placeId)) return i;
        return i.copyWith(
          locationIds: i.locationIds.where((id) => id != placeId).toList(),
        );
      }).toList();
      await _writeIndex(type, updated);
    }

    await Future.wait([
      cleanType(MediaType.audio, results[0]),
      cleanType(MediaType.video, results[1]),
    ]);
  } catch (e) {
    debugPrint('MediaPodService._unlinkAllForPlaceAsync error: $e');
  }
}

// ── Clear all place links ─────────────────────────────────────────────────

Future<void> _clearAllPlaceLinksAsync() async {
  try {
    if (!PodAuth.isLoggedInSync()) return;

    final results = await Future.wait([
      _readIndex(MediaType.audio),
      _readIndex(MediaType.video),
    ]);

    Future<void> clearType(MediaType type, List<MediaItem> items) async {
      final hasLinks = items.any((i) => i.locationIds.isNotEmpty);
      if (!hasLinks) return;
      final updated = items
          .map((i) => i.copyWith(locationIds: const []))
          .toList();
      await _writeIndex(type, updated);
    }

    await Future.wait([
      clearType(MediaType.audio, results[0]),
      clearType(MediaType.video, results[1]),
    ]);
  } catch (e) {
    debugPrint('MediaPodService._clearAllPlaceLinksAsync error: $e');
  }
}
