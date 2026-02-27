/// Video library page – lists video files and plays them inline.
///
// Time-stamp: <2026-02-19 GitHub Copilot>
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

import 'package:geopod/models/media_item.dart';
import 'package:geopod/widgets/media/media_list_widget.dart';
import 'package:geopod/widgets/media/video_player_widget.dart';

/// Page listing short video files stored on the user's Pod.
///
/// Currently seeded from bundled `assets/video/`.
/// Replace [_items] with a dynamic Pod fetch to satisfy Issue #27.
class VideoPage extends StatefulWidget {
  const VideoPage({super.key});

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  List<MediaItem> _items = const [
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
    // TODO(issue-27): append Pod-fetched MediaItems here.
  ];

  Future<void> _delete(MediaItem item) async {
    setState(() => _items = List.of(_items)..remove(item));
    // TODO(issue-27): delete from Solid Pod.
  }

  @override
  Widget build(BuildContext context) {
    return MediaListWidget<MediaItem>(
      title: 'Video',
      items: _items,
      isLoading: false,
      emptyMessage: 'No video files. Upload some to your Pod!',
      titleOf: (i) => i.name,
      subtitleOf: (i) => i.isRemote ? 'Pod' : 'Local',
      iconOf: (_) => Icons.video_file,
      playerBuilder: (ctx, i) => VideoPlayerWidget(item: i),
      onDelete: _delete,
    );
  }
}
