/// BackupScreen — export and import a full geopod backup ZIP.
///
// Time-stamp: <2026-06-16 Graham Williams>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.
//
// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the Free
// Software Foundation, either version 3 of the License, or (at your option)
// any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program.  If not, see <https://opensource.org/license/gpl-3-0>.
///
/// Authors: Graham Williams

library;

import 'package:flutter/material.dart';

import 'package:gap/gap.dart';
import 'package:markdown_tooltip/markdown_tooltip.dart';

import 'package:geopod/models/media_item.dart';
import 'package:geopod/services/backup_service.dart';
import 'package:geopod/services/media/media_pod_service.dart';
import 'package:geopod/services/places_service.dart';
import 'package:geopod/widgets/backup/import_message_banner.dart';

// ignore_for_file: use_build_context_synchronously

/// Full-page backup and restore screen, shown as a left-menu item.

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _loading = false;
  String? _message;
  bool _messageError = false;

  // Counts read directly from in-memory caches — no async fetch needed.
  int get _locationCount =>
      (PlacesCacheManager().allPlaces ?? PlacesCacheManager().podPlaces)
          ?.where((p) => !p.isLocal)
          .length ??
      0;
  int _audioCount = 0;
  int _videoCount = 0;

  @override
  void initState() {
    super.initState();
    placesChangeNotifier.addListener(_rebuild);
    _loadMediaCounts();
  }

  @override
  void dispose() {
    placesChangeNotifier.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _loadMediaCounts() async {
    final audio = await MediaPodService.listItemsCached(MediaType.audio);
    final video = await MediaPodService.listItemsCached(MediaType.video);
    if (!mounted) return;
    setState(() {
      _audioCount = audio.length;
      _videoCount = video.length;
    });
  }

  void _setMsg(String msg, {bool error = false}) => setState(() {
    _message = msg;
    _messageError = error;
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final countsLabel =
        '$_locationCount location(s), $_audioCount audio file(s), '
        'and $_videoCount video file(s)';

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Backup & Restore',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Gap(8),
            Text(
              'Save all your locations and media (audio & video) to a single '
              'ZIP file, or restore everything from a previously saved backup.',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            if (_message != null) ...[
              const Gap(12),
              ImportMessageBanner(
                message: _message!,
                isError: _messageError,
                cs: cs,
              ),
            ],
            const Gap(16),
            Row(
              children: [
                MarkdownTooltip(
                  message:
                      '**Export Backup**\n\n'
                      'Downloads a ZIP file containing $countsLabel. '
                      'Keep it somewhere safe so you can restore everything '
                      'later or move it to a new Pod.',
                  child: FilledButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Export Backup'),
                    onPressed: _loading ? null : _exportBackup,
                  ),
                ),
                const Gap(12),
                MarkdownTooltip(
                  message:
                      '**Import Backup**\n\n'
                      'Restore locations and media from a previously exported '
                      'geopod backup ZIP. Locations are merged with any already '
                      'on your Pod; media files are re-uploaded.',
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.upload),
                    label: const Text('Import Backup'),
                    onPressed: _loading ? null : _importBackup,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportBackup() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final places = await PlacesService.fetchPodPlaces();
      final ok = await BackupService.exportBackup(
        places,
        onProgress: (_, _, msg) {
          if (mounted) setState(() => _message = msg);
        },
      );
      if (ok) {
        _setMsg('Backup exported successfully.');
      } else {
        if (mounted) setState(() => _message = null);
      }
    } catch (e) {
      _setMsg('Export failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _importBackup() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final result = await BackupService.importBackup(
        onProgress: (_, _, msg) {
          if (mounted) setState(() => _message = msg);
        },
      );
      if (result.placesRestored == 0 &&
          result.mediaRestored == 0 &&
          !result.hasErrors) {
        _setMsg('Nothing to restore (file may be empty).');
        return;
      }
      final parts = <String>[];
      if (result.placesRestored > 0) {
        parts.add('${result.placesRestored} location(s) restored');
      }
      if (result.mediaRestored > 0) {
        parts.add('${result.mediaRestored} media file(s) restored');
      }
      if (result.mediaFailed > 0) {
        parts.add('${result.mediaFailed} media file(s) failed');
      }
      if (result.hasErrors) parts.add('${result.errors.length} warning(s)');
      _setMsg(
        '${parts.join(', ')}.',
        error: result.mediaFailed > 0 || result.hasErrors,
      );
      if (result.hasErrors && mounted) {
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Warnings'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: result.errors
                    .take(20)
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• $e',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _setMsg('Import failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
