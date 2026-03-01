/// Dialog for selecting which media items are linked to a place.
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

import 'package:flutter/material.dart';

import 'package:geopod/models/media_item.dart';
import 'package:geopod/services/media/builtin_media.dart';
import 'package:geopod/services/media/place_media_service.dart';
import 'package:geopod/services/pod/pod_auth.dart';
import 'package:geopod/widgets/map/login_required_dialog.dart';

/// Shows a dialog that lets the user toggle which media items are linked to the
/// place identified by [placeId].
///
/// Loads all available media (Pod-hosted items + bundled demo assets),
/// pre-selects the items already linked to [placeId], and persists any changes
/// via [PlaceMediaService].
///
/// Returns `true` if any changes were saved, `false` / `null` otherwise.
Future<bool?> showMediaLinkPickerDialog(
  BuildContext context, {
  required String placeId,
  required String placeTitle,
}) async {
  if (!PodAuth.isLoggedInSync()) {
    await showLoginRequiredDialog(context);
    return null;
  }
  return showDialog<bool>(
    context: context,
    builder: (_) =>
        _MediaLinkPickerDialog(placeId: placeId, placeTitle: placeTitle),
  );
}

class _MediaLinkPickerDialog extends StatefulWidget {
  const _MediaLinkPickerDialog({
    required this.placeId,
    required this.placeTitle,
  });

  final String placeId;
  final String placeTitle;

  @override
  State<_MediaLinkPickerDialog> createState() => _MediaLinkPickerDialogState();
}

class _MediaLinkPickerDialogState extends State<_MediaLinkPickerDialog> {
  // Full merged list (Pod items + builtins, deduplicated).
  List<MediaItem> _allMedia = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  /// podItemIds of initially linked items – used to compute the save delta.
  Set<String> _original = {};

  /// Current checkbox state: podItemIds of selected items.
  Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    try {
      // Fetch Pod media (includes previously upserted builtins).
      final podMedia = await PlaceMediaService.getAllPodMedia();

      // Merge builtins, deduplicating by podItemId so items that have already
      // been upserted into the Pod index are not shown twice.
      final podIds = podMedia
          .map((i) => i.podItemId)
          .whereType<String>()
          .toSet();
      final extraBuiltins = allBuiltinItems
          .where((b) => b.podItemId != null && !podIds.contains(b.podItemId))
          .toList();

      final merged = [...extraBuiltins, ...podMedia];

      // Pre-select items already linked to this place.
      final linked = merged
          .where(
            (i) =>
                i.podItemId != null && i.locationIds.contains(widget.placeId),
          )
          .map((i) => i.podItemId!)
          .toSet();

      if (mounted) {
        setState(() {
          _allMedia = merged;
          _original = Set<String>.from(linked);
          _selected = Set<String>.from(linked);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    // Items added (selected now but not before).
    final added = _selected.difference(_original);
    // Items removed (deselected now but were selected before).
    final removed = _original.difference(_selected);

    bool anyOk = false;
    for (final item in _allMedia) {
      if (item.podItemId == null) continue;
      if (added.contains(item.podItemId)) {
        final ok = await PlaceMediaService.linkToPlace(item, widget.placeId);
        if (ok) anyOk = true;
      } else if (removed.contains(item.podItemId)) {
        final ok = await PlaceMediaService.unlinkFromPlace(
          item,
          widget.placeId,
        );
        if (ok) anyOk = true;
      }
    }

    if (!mounted) return;
    Navigator.pop(context, anyOk || (added.isEmpty && removed.isEmpty));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 480, maxWidth: 840),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  const Icon(Icons.place, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Link media to "${widget.placeTitle}"',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: _buildContent(),
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: OverflowBar(
                alignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: _saving || _loading ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }

    if (_allMedia.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No media available.\nUpload audio or video files first.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final allIds = _allMedia
        .map((m) => m.podItemId)
        .whereType<String>()
        .toSet();
    final allSelected = allIds.every(_selected.contains);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Select the media to link to this place:',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
            TextButton.icon(
              onPressed: _saving
                  ? null
                  : () {
                      setState(() {
                        if (allSelected) {
                          _selected.removeAll(allIds);
                        } else {
                          _selected.addAll(allIds);
                        }
                      });
                    },
              icon: Icon(
                allSelected
                    ? Icons.deselect_outlined
                    : Icons.select_all_outlined,
                size: 18,
              ),
              label: Text(allSelected ? 'Deselect all' : 'Select all'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _allMedia.length,
            itemBuilder: (_, i) {
              final item = _allMedia[i];
              final id = item.podItemId;
              if (id == null) return const SizedBox.shrink();
              final isAudio = item.type == MediaType.audio;
              final color = isAudio ? Colors.teal : Colors.deepPurple;
              final icon = isAudio ? Icons.headphones : Icons.videocam;
              final subtitle = item.isPodItem
                  ? (item.isEncrypted ? 'Pod · Encrypted' : 'Pod')
                  : 'Built-in demo';
              return CheckboxListTile(
                dense: true,
                value: _selected.contains(id),
                title: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
                secondary: CircleAvatar(
                  radius: 14,
                  backgroundColor: color,
                  child: Icon(icon, color: Colors.white, size: 14),
                ),
                onChanged: _saving
                    ? null
                    : (checked) {
                        setState(() {
                          if (checked == true) {
                            _selected.add(id);
                          } else {
                            _selected.remove(id);
                          }
                        });
                      },
              );
            },
          ),
        ),
      ],
    );
  }
}
