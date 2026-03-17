/// Reusable widget showing audio/video items linked to a place.
///
// Time-stamp: <2026-03-01 Miduo>
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
/// Authors: Miduo

library;

import 'package:flutter/material.dart';

import 'package:geopod/models/media_item.dart';
import 'package:geopod/services/media/place_media_service.dart';
import 'package:geopod/widgets/media/audio_player_widget.dart';
import 'package:geopod/widgets/media/video_player_widget.dart';

/// Displays audio and video items linked to [placeId] and lets the user
/// play them inline via a bottom sheet.
///
/// Call [PlaceMediaSection.reload] key if you need to refresh the list
/// after link changes.
class PlaceMediaSection extends StatefulWidget {
  const PlaceMediaSection({
    super.key,
    required this.placeId,
    this.extraItems = const [],
    this.onManageLinks,
  });

  /// The ID of the place whose linked media should be shown.
  final String placeId;

  /// Additional in-memory items (e.g. bundled asset items) to include in the
  /// filter.  These are read-only and won't be shown unless they have a
  /// matching [MediaItem.locationIds] entry.
  final List<MediaItem> extraItems;

  /// Optional callback that opens a media-link management dialog.  When
  /// provided, an edit icon button is shown in the "Linked Media" header.
  /// The section automatically reloads its list after the callback completes.
  final Future<void> Function()? onManageLinks;

  @override
  State<PlaceMediaSection> createState() => _PlaceMediaSectionState();
}

class _PlaceMediaSectionState extends State<PlaceMediaSection> {
  List<MediaItem>? _items;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PlaceMediaSection old) {
    super.didUpdateWidget(old);
    if (old.placeId != widget.placeId) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await PlaceMediaService.getMediaForPlace(
      widget.placeId,
      extraItems: widget.extraItems,
    );
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<void> _handleManageLinks() async {
    if (widget.onManageLinks != null) {
      await widget.onManageLinks!();
      // Invalidate the cached index so the reload picks up fresh data.
      await _load();
    }
  }

  void _openPlayer(MediaItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _MediaPlayerSheet(item: item),
    );
  }

  Widget _buildChip(MediaItem item) {
    final isAudio = item.type == MediaType.audio;
    final color = isAudio ? Colors.teal : Colors.deepPurple;
    final icon = isAudio ? Icons.headphones : Icons.videocam;

    return ActionChip(
      avatar: Icon(icon, size: 14, color: Colors.white),
      label: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      backgroundColor: color,
      labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
      onPressed: () => _openPlayer(item),
      tooltip: 'Tap to play "${item.name}"',
      padding: const EdgeInsets.symmetric(horizontal: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final items = _items ?? [];
    // When no manage callback is provided, stay invisible if there is nothing
    // to show.  When a callback is provided, always render so the user can
    // open the manager even when the list is empty.
    if (items.isEmpty && widget.onManageLinks == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.perm_media, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                'Linked Media',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              if (items.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  '(tap to play)',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
              const Spacer(),
              // Manage-links button – only shown when a callback is wired up
              // AND there are already linked items (empty state shows its own
              // standalone "Link to media" button instead).
              if (widget.onManageLinks != null && items.isNotEmpty)
                InkWell(
                  onTap: _handleManageLinks,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 14,
                          color: Colors.blue.shade600,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Manage',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: OutlinedButton.icon(
              onPressed: _handleManageLinks,
              icon: const Icon(Icons.add_link, size: 16),
              label: const Text('Link to media'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue.shade600,
                side: BorderSide(color: Colors.blue.shade300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                textStyle: const TextStyle(fontSize: 13),
                visualDensity: VisualDensity.compact,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: items.map(_buildChip).toList(),
            ),
          ),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ── Inline player sheet ──────────────────────────────────────────────────────

/// A bottom sheet that shows an inline audio or video player for [item].
class _MediaPlayerSheet extends StatelessWidget {
  const _MediaPlayerSheet({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final isAudio = item.type == MediaType.audio;
    final color = isAudio ? Colors.teal : Colors.deepPurple;
    final icon = isAudio ? Icons.headphones : Icons.videocam;

    return Padding(
      padding: MediaQuery.viewInsetsOf(
        context,
      ).copyWith(left: 16, right: 16, top: 16, bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      isAudio ? 'Audio' : 'Video',
                      style: TextStyle(fontSize: 12, color: color),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          // Player
          if (isAudio)
            AudioPlayerWidget(item: item)
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.45,
              ),
              child: VideoPlayerWidget(item: item),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
