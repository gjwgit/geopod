/// Video library page – lists video files and plays them inline.
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
import 'package:geopod/services/media/media_pod_service.dart';
import 'package:geopod/services/pod/pod_auth.dart';
import 'package:geopod/widgets/media/media_list_widget.dart';
import 'package:geopod/widgets/media/upload_media_dialog.dart';
import 'package:geopod/widgets/media/video_player_widget.dart';

/// Page listing short video files stored on the user's Pod.
class VideoPage extends StatefulWidget {
  const VideoPage({super.key});

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  // Bundled demo assets.
  static const List<MediaItem> _assets = [
    MediaItem(
      name: 'Example Video 1',
      type: MediaType.video,
      assetPath: 'assets/video/example1.mp4',
    ),
    MediaItem(
      name: 'Example Video 2',
      type: MediaType.video,
      assetPath: 'assets/video/example2.mp4',
    ),
  ];

  List<MediaItem> _podItems = [];
  bool _isLoadingPod = false;

  List<MediaItem> get _allItems => [..._assets, ..._podItems];

  @override
  void initState() {
    super.initState();
    _loadPodItems();
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
      final items = await MediaPodService.listItems(MediaType.video);
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
    final item = await showUploadMediaDialog(context, MediaType.video);
    if (item != null && mounted) {
      setState(() => _podItems = [..._podItems, item]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MediaListWidget<MediaItem>(
          title: 'Video',
          items: _allItems,
          isLoading: _isLoadingPod,
          emptyMessage: 'No video files. Upload some to your Pod!',
          titleOf: (i) => i.name,
          subtitleOf: (i) {
            if (i.isPodItem) {
              return i.isEncrypted ? 'Pod · Encrypted' : 'Pod';
            }
            return i.isRemote ? 'Pod' : 'Local';
          },
          iconOf: (i) {
            if (i.isPodItem && i.isEncrypted) return Icons.lock;
            return Icons.video_file;
          },
          playerBuilder: (ctx, i) => VideoPlayerWidget(item: i),
          onDelete: (i) async {
            if (i.isPodItem) await _delete(i);
          },
        ),

        // Upload FAB – only shown when logged in.
        if (PodAuth.isLoggedInSync())
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              heroTag: 'video_upload_fab',
              onPressed: _upload,
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload'),
            ),
          ),
      ],
    );
  }
}
