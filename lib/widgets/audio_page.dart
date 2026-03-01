/// Audio library page – lists audio files and plays them inline.
///
// Time-stamp: <2026-02-28 GitHub Copilot>
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
// this program.  If not, see <https://opensource.org/license/gpl-3-0>.
///
/// Authors: GitHub Copilot

library;

import 'package:flutter/material.dart';

import 'package:solidpod/solidpod.dart' show authStateNotifier;

import 'package:geopod/models/media_item.dart';
import 'package:geopod/services/media/builtin_media.dart';
import 'package:geopod/services/media/media_pod_service.dart';
import 'package:geopod/services/pod/pod_auth.dart';
import 'package:geopod/widgets/map/login_required_dialog.dart';
import 'package:geopod/widgets/media/audio_player_widget.dart';
import 'package:geopod/widgets/media/media_list_widget.dart';
import 'package:geopod/widgets/media/place_link_picker_dialog.dart';
import 'package:geopod/widgets/media/upload_media_dialog.dart';

/// Page listing short audio files stored on the user's Pod.
class AudioPage extends StatefulWidget {
  const AudioPage({super.key});

  @override
  State<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  // Bundled demo assets – defined in builtin_media.dart so the same items are
  // accessible from the media-link picker dialog.
  static final List<MediaItem> _assets = builtinAudioItems;

  List<MediaItem> _podItems = [];
  bool _isLoadingPod = false;

  /// Merges assets and Pod items, deduplicating by [podItemId] so that a
  /// built-in asset registered in the Pod index (after its first link) does
  /// not appear twice in the list.
  List<MediaItem> get _allItems {
    final podIds = _podItems
        .map((i) => i.podItemId)
        .whereType<String>()
        .toSet();
    final deduped = _assets
        .where((a) => a.podItemId == null || !podIds.contains(a.podItemId))
        .toList();
    return [...deduped, ..._podItems];
  }

  @override
  void initState() {
    super.initState();
    _loadPodItems();
    // Reload when login state changes.
    authStateNotifier.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    authStateNotifier.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() => _loadPodItems();

  Future<void> _loadPodItems() async {
    if (!PodAuth.isLoggedInSync()) {
      if (mounted) setState(() => _podItems = []);
      return;
    }
    if (mounted) setState(() => _isLoadingPod = true);
    try {
      final items = await MediaPodService.listItems(MediaType.audio);
      if (mounted) setState(() => _podItems = items);
    } finally {
      if (mounted) setState(() => _isLoadingPod = false);
    }
  }

  Future<void> _delete(MediaItem item) async {
    if (item.isPodItem) {
      await MediaPodService.deleteItem(item);
    }
    setState(() => _podItems = List.of(_podItems)..remove(item));
  }

  Future<void> _upload() async {
    final item = await showUploadMediaDialog(context, MediaType.audio);
    if (item != null && mounted) {
      setState(() => _podItems = [..._podItems, item]);
    }
  }

  /// Opens the place-link picker dialog for [item] and reloads the index
  /// so any updated [locationIds] are reflected in the UI.
  Future<void> _manageLinks(MediaItem item) async {
    if (!PodAuth.isLoggedInSync()) {
      await showLoginRequiredDialog(context);
      return;
    }
    final changed = await showPlaceLinkPickerDialog(context, item);
    if (changed == true && mounted) {
      // Reload Pod index to get the freshly saved locationIds.
      await _loadPodItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MediaListWidget<MediaItem>(
          title: 'Audio',
          items: _allItems,
          isLoading: _isLoadingPod,
          emptyMessage: 'No audio files. Upload some to your Pod!',
          titleOf: (i) => i.name,
          subtitleOf: (i) {
            if (i.isPodItem) {
              return i.isEncrypted ? 'Pod · Encrypted' : 'Pod';
            }
            return i.isRemote ? 'Pod' : 'Local';
          },
          iconOf: (i) {
            if (i.isPodItem && i.isEncrypted) return Icons.lock;
            return Icons.audio_file;
          },
          playerBuilder: (ctx, i) => AudioPlayerWidget(item: i),
          // Hide delete for bundled demo assets (they are not Pod files).
          canDelete: (i) => i.isPodItem,
          onDelete: (i) async {
            if (i.isPodItem) await _delete(i);
          },
          // Allow linking for both Pod items and bundled assets (assets with a
          // stable podItemId are upserted into the index on first link).
          onManageLinks: (i) async {
            if (i.podItemId != null) await _manageLinks(i);
          },
        ),

        // Upload FAB – only shown when logged in.
        if (PodAuth.isLoggedInSync())
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              heroTag: 'audio_upload_fab',
              onPressed: _upload,
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload'),
            ),
          ),
      ],
    );
  }
}
