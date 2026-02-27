/// Audio library page – lists audio files and plays them inline.
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
import 'package:geopod/widgets/media/audio_player_widget.dart';
import 'package:geopod/widgets/media/media_list_widget.dart';

/// Page listing short audio files stored on the user's Pod.
///
/// Currently seeded from bundled `assets/audio/`.
/// Replace [_items] with a dynamic Pod fetch to satisfy Issue #27.
class AudioPage extends StatefulWidget {
  const AudioPage({super.key});

  @override
  State<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  List<MediaItem> _items = const [
    MediaItem(
      name: 'Example Audio',
      type: MediaType.audio,
      assetPath: 'assets/audio/example.mp3',
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
      title: 'Audio',
      items: _items,
      isLoading: false,
      emptyMessage: 'No audio files. Upload some to your Pod!',
      titleOf: (i) => i.name,
      subtitleOf: (i) => i.isRemote ? 'Pod' : 'Local',
      iconOf: (_) => Icons.audio_file,
      playerBuilder: (ctx, i) => AudioPlayerWidget(item: i),
      onDelete: _delete,
    );
  }
}
