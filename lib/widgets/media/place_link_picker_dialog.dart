/// Dialog for selecting which places a media item is linked to.
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
import 'package:geopod/services/media/place_media_service.dart';
import 'package:geopod/services/places_service.dart';
import 'package:geopod/services/pod/pod_auth.dart';
import 'package:geopod/widgets/map/login_required_dialog.dart';

/// Shows a dialog that lets the user toggle which places [item] is linked to.
///
/// Loads the full places list, pre-selects the places already in
/// [MediaItem.locationIds], and persists changes via [PlaceMediaService].
///
/// Returns `true` if any changes were saved, `false` / `null` otherwise.
Future<bool?> showPlaceLinkPickerDialog(
  BuildContext context,
  MediaItem item,
) async {
  if (!PodAuth.isLoggedInSync()) {
    await showLoginRequiredDialog(context);
    return null;
  }
  return showDialog<bool>(
    context: context,
    builder: (_) => _PlaceLinkPickerDialog(item: item),
  );
}

class _PlaceLinkPickerDialog extends StatefulWidget {
  const _PlaceLinkPickerDialog({required this.item});
  final MediaItem item;

  @override
  State<_PlaceLinkPickerDialog> createState() => _PlaceLinkPickerDialogState();
}

class _PlaceLinkPickerDialogState extends State<_PlaceLinkPickerDialog> {
  List<Place>? _places;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  /// Current selection of place IDs.
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.item.locationIds);
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    try {
      final places = await PlacesService.fetchPlaces();
      if (mounted) {
        setState(() {
          _places = places;
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
    final ok = await PlaceMediaService.setLinkedPlaces(
      widget.item,
      _selected.toList(),
    );
    if (!mounted) return;
    Navigator.pop(context, ok);
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.item.type == MediaType.audio
        ? Colors.teal
        : Colors.deepPurple;
    final icon = widget.item.type == MediaType.audio
        ? Icons.headphones
        : Icons.videocam;
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
                  Icon(icon, color: iconColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Link "${widget.item.name}"',
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
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 300),
                  child: _buildContent(),
                ),
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: OverflowBar(
                alignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _saving ? null : () => Navigator.pop(context, false),
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

    final places = _places ?? [];

    if (places.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No places available.\nSave a location first.'),
        ),
      );
    }

    final allIds = places.map((p) => p.id).toSet();
    final allSelected = allIds.every(_selected.contains);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Select the locations to link this media to:',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
            // Select-all / deselect-all toggle.
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
            itemCount: places.length,
            itemBuilder: (_, i) {
              final p = places[i];
              return CheckboxListTile(
                value: _selected.contains(p.id),
                title: Text(
                  p.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  p.shortAddress,
                  style: const TextStyle(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                secondary: CircleAvatar(
                  radius: 14,
                  backgroundColor: p.isEncrypted ? Colors.purple : Colors.blue,
                  child: Icon(
                    p.isEncrypted ? Icons.lock : Icons.place,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                onChanged: _saving
                    ? null
                    : (checked) {
                        setState(() {
                          if (checked == true) {
                            _selected.add(p.id);
                          } else {
                            _selected.remove(p.id);
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
