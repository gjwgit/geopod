/// Service for managing many-to-many links between places and media items.
///
// Time-stamp: <2026-03-01 GitHub Copilot>
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
// this program.  If not, see <https://opensource.org/licenses/gpl-3-0>.
///
/// Authors: GitHub Copilot

library;

import 'package:geopod/models/media_item.dart';
import 'package:geopod/services/media/media_pod_service.dart';
import 'package:geopod/services/pod/pod_auth.dart';

/// Manages many-to-many associations between places and media items.
///
/// **Design:** associations are stored directly on each [MediaItem] as
/// [MediaItem.locationIds].  This avoids a separate linking table while
/// supporting the full many-to-many relationship:
///
/// * A media item can be linked to multiple places.
/// * A place can have multiple media items of any type.
///
/// All write operations persist the change to the Pod index via
/// [MediaPodService.updateItem].
class PlaceMediaService {
  PlaceMediaService._();

  // ── Query ─────────────────────────────────────────────────────────────────

  /// Returns all [MediaItem]s (audio + video) linked to [placeId].
  ///
  /// [extraItems] are additional media items not stored in the Pod (e.g.
  /// bundled asset items) that callers pass in so the service can also filter
  /// them without making duplicate Pod calls.  Asset items are read-only and
  /// will not be returned here because they have no [locationIds] set by
  /// default.
  static Future<List<MediaItem>> getMediaForPlace(
    String placeId, {
    List<MediaItem> extraItems = const [],
  }) async {
    if (!PodAuth.isLoggedInSync()) {
      // Still filter extraItems in case they have locationIds set.
      return extraItems
          .where((item) => item.locationIds.contains(placeId))
          .toList();
    }

    // Fetch both indices in parallel – halves the Pod round-trip count.
    final results = await Future.wait([
      MediaPodService.listItems(MediaType.audio),
      MediaPodService.listItems(MediaType.video),
    ]);
    final podAudio = results[0];
    final podVideo = results[1];

    final all = [...extraItems, ...podAudio, ...podVideo];
    return all.where((item) => item.locationIds.contains(placeId)).toList();
  }

  /// Returns all [MediaItem]s (audio + video) from the Pod, regardless of
  /// place links.  Useful when showing the full list for a link-picker dialog.
  static Future<List<MediaItem>> getAllPodMedia() async {
    if (!PodAuth.isLoggedInSync()) return [];
    final results = await Future.wait([
      MediaPodService.listItems(MediaType.audio),
      MediaPodService.listItems(MediaType.video),
    ]);
    return [...results[0], ...results[1]];
  }

  // ── Mutate ────────────────────────────────────────────────────────────────

  /// Adds [placeId] to [item.locationIds] and persists to the Pod.
  ///
  /// No-op (returns `true`) if the link already exists.
  static Future<bool> linkToPlace(MediaItem item, String placeId) async {
    if (item.locationIds.contains(placeId)) return true;
    final updated = item.copyWith(locationIds: [...item.locationIds, placeId]);
    return MediaPodService.updateItem(updated);
  }

  /// Removes [placeId] from [item.locationIds] and persists to the Pod.
  ///
  /// No-op (returns `true`) if the link does not exist.
  static Future<bool> unlinkFromPlace(MediaItem item, String placeId) async {
    if (!item.locationIds.contains(placeId)) return true;
    final updated = item.copyWith(
      locationIds: item.locationIds.where((id) => id != placeId).toList(),
    );
    return MediaPodService.updateItem(updated);
  }

  /// Replaces the entire [locationIds] list of [item] with [placeIds] and
  /// persists to the Pod.
  ///
  /// Useful when saving the result of a checkbox-style picker in bulk.
  static Future<bool> setLinkedPlaces(
    MediaItem item,
    List<String> placeIds,
  ) async {
    final updated = item.copyWith(locationIds: placeIds);
    return MediaPodService.updateItem(updated);
  }
}
