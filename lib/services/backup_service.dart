/// Backup and restore service for places and media.
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

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';

import 'package:geopod/models/media_item.dart';
import 'package:geopod/models/place.dart';
import 'package:geopod/services/media/media_pod_service.dart';
import 'package:geopod/services/places/places_import_export.dart';

/// Entry in the media manifest stored inside the backup ZIP.

class _MediaManifestEntry {
  const _MediaManifestEntry({
    required this.podItemId,
    required this.name,
    required this.type,
    required this.filename,
    required this.locationIds,
  });

  final String podItemId;
  final String name;
  final String type; // 'audio' or 'video'
  final String filename; // path inside the ZIP (e.g. 'audio/song.mp3')
  final List<String> locationIds;

  Map<String, dynamic> toJson() => {
    'podItemId': podItemId,
    'name': name,
    'type': type,
    'filename': filename,
    'locationIds': locationIds,
  };

  factory _MediaManifestEntry.fromJson(Map<String, dynamic> j) =>
      _MediaManifestEntry(
        podItemId: j['podItemId'] as String,
        name: j['name'] as String,
        type: j['type'] as String,
        filename: j['filename'] as String,
        locationIds: (j['locationIds'] as List<dynamic>)
            .map((e) => e as String)
            .toList(),
      );
}

/// Result of a restore operation.

class RestoreResult {
  int placesRestored = 0;
  int mediaRestored = 0;
  int mediaFailed = 0;
  final List<String> errors = [];

  bool get hasErrors => errors.isNotEmpty;
}

/// Progress callback: (current, total, message).
typedef BackupProgress = void Function(int current, int total, String message);

/// Zero-padded timestamp string for filenames: YYYYMMDD_HHMM.
String _ts(DateTime t) =>
    '${t.year}'
    '${t.month.toString().padLeft(2, '0')}'
    '${t.day.toString().padLeft(2, '0')}'
    '_${t.hour.toString().padLeft(2, '0')}'
    '${t.minute.toString().padLeft(2, '0')}';

/// Service for exporting and importing a full geopod backup ZIP.
///
/// ZIP structure:
/// ```
/// places.json
/// media_manifest.json
/// audio/<filename>
/// video/<filename>
/// ```

class BackupService {
  BackupService._();

  // ── Export ───────────────────────────────────────────────────────────────

  /// Exports all Pod places and media to a single ZIP file.
  ///
  /// Returns true on success.
  static Future<bool> exportBackup(
    List<Place> places, {
    BackupProgress? onProgress,
  }) async {
    try {
      final archive = Archive();

      // ── 1. Places JSON ────────────────────────────────────────────────
      onProgress?.call(0, 1, 'Exporting locations…');
      final userPlaces = places.where((p) => !p.isLocal).toList();
      final placesJson = const JsonEncoder.withIndent(
        '  ',
      ).convert(userPlaces.map((p) => p.toJson()).toList());
      final placesBytes = Uint8List.fromList(utf8.encode(placesJson));
      archive.addFile(
        ArchiveFile('places.json', placesBytes.length, placesBytes),
      );

      // ── 2. Media ──────────────────────────────────────────────────────
      final audioItems = await MediaPodService.listItems(MediaType.audio);
      final videoItems = await MediaPodService.listItems(MediaType.video);
      final podItems = [
        ...audioItems,
        ...videoItems,
      ].where((i) => i.isPodItem).toList();
      final manifest = <_MediaManifestEntry>[];

      for (int i = 0; i < podItems.length; i++) {
        final item = podItems[i];
        onProgress?.call(
          i + 1,
          podItems.length,
          'Exporting media ${i + 1}/${podItems.length}: ${item.name}',
        );

        final url = await MediaPodService.loadPlaybackUrl(item);
        if (url == null) {
          debugPrint('BackupService: skipping ${item.name} – could not load');
          continue;
        }
        final bytes = _bytesFromPlaybackUrl(url);
        await MediaPodService.releasePlaybackUrl(url);
        if (bytes == null) {
          debugPrint('BackupService: skipping ${item.name} – no bytes');
          continue;
        }

        final storedName = _cleanFilename(item);
        final dir = item.type == MediaType.audio ? 'audio' : 'video';
        final zipPath = '$dir/$storedName';
        archive.addFile(ArchiveFile(zipPath, bytes.length, bytes));
        manifest.add(
          _MediaManifestEntry(
            podItemId: item.podItemId ?? '',
            name: item.name,
            type: dir,
            filename: zipPath,
            locationIds: item.locationIds,
          ),
        );
      }

      // ── 3. Media manifest ─────────────────────────────────────────────
      final manifestBytes = Uint8List.fromList(
        utf8.encode(
          const JsonEncoder.withIndent(
            '  ',
          ).convert(manifest.map((e) => e.toJson()).toList()),
        ),
      );
      archive.addFile(
        ArchiveFile('media_manifest.json', manifestBytes.length, manifestBytes),
      );

      // ── 4. Save ZIP ───────────────────────────────────────────────────
      onProgress?.call(0, 1, 'Choosing save location…');
      final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));
      final filename = 'geopod_backup_${_ts(DateTime.now())}.zip';
      final savePath = await FilePicker.saveFile(
        dialogTitle: 'Save Backup',
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (savePath == null) return false; // user cancelled
      await File(savePath).writeAsBytes(zipBytes);
      return true;
    } catch (e) {
      debugPrint('BackupService.exportBackup error: $e');
      return false;
    }
  }

  // ── Import ───────────────────────────────────────────────────────────────

  /// Prompts the user for a backup ZIP and restores places and media.
  ///
  /// Returns a [RestoreResult] describing what happened.
  static Future<RestoreResult> importBackup({
    BackupProgress? onProgress,
  }) async {
    final result = RestoreResult();

    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return result;

    final fileBytes = picked.files.first.bytes;
    if (fileBytes == null) {
      result.errors.add('Could not read the selected file.');
      return result;
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(fileBytes);
    } catch (e) {
      result.errors.add('Not a valid ZIP file: $e');
      return result;
    }

    final fileMap = <String, ArchiveFile>{
      for (final f in archive.files)
        if (f.isFile) f.name: f,
    };

    // ── Restore places ────────────────────────────────────────────────
    final placesFile = fileMap['places.json'];
    if (placesFile != null) {
      onProgress?.call(0, 1, 'Restoring locations…');
      try {
        final importResult = PlacesImportExport.importFromJsonString(
          utf8.decode(placesFile.content as List<int>),
        );
        result.placesRestored = importResult.places.length;
        if (importResult.hasErrors) result.errors.addAll(importResult.errors);
      } catch (e) {
        result.errors.add('Failed to restore places: $e');
      }
    }

    // ── Restore media ─────────────────────────────────────────────────
    final manifestFile = fileMap['media_manifest.json'];
    if (manifestFile != null) {
      try {
        final manifestList =
            (jsonDecode(utf8.decode(manifestFile.content as List<int>))
                    as List<dynamic>)
                .whereType<Map<String, dynamic>>()
                .map(_MediaManifestEntry.fromJson)
                .toList();

        for (int i = 0; i < manifestList.length; i++) {
          final entry = manifestList[i];
          onProgress?.call(
            i + 1,
            manifestList.length,
            'Restoring media ${i + 1}/${manifestList.length}: ${entry.name}',
          );

          final mediaFile = fileMap[entry.filename];
          if (mediaFile == null) {
            result.errors.add('Missing file in ZIP: ${entry.filename}');
            result.mediaFailed++;
            continue;
          }

          final type = entry.type == 'audio'
              ? MediaType.audio
              : MediaType.video;
          final uploaded = await MediaPodService.uploadItem(
            name: entry.name,
            filename: entry.filename.split('/').last,
            bytes: Uint8List.fromList(mediaFile.content as List<int>),
            type: type,
          );

          if (uploaded == null) {
            result.errors.add('Failed to upload: ${entry.name}');
            result.mediaFailed++;
          } else {
            if (entry.locationIds.isNotEmpty) {
              await MediaPodService.updateItem(
                uploaded.copyWith(locationIds: entry.locationIds),
              );
            }
            result.mediaRestored++;
          }
        }
      } catch (e) {
        result.errors.add('Failed to restore media: $e');
      }
    }

    return result;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Decodes bytes from a data: URL (native platforms).
  /// Returns null for blob: URLs (web) — callers skip the item.
  static Uint8List? _bytesFromPlaybackUrl(String url) {
    if (!url.startsWith('data:')) return null;
    final comma = url.indexOf(',');
    if (comma == -1) return null;
    try {
      return base64Decode(url.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  /// Strips .enc and .enc.ttl suffixes from a media item's stored filename.
  static String _cleanFilename(MediaItem item) {
    var name = item.podRelativePath?.split('/').last ?? '${item.name}.bin';
    if (name.endsWith('.enc.ttl')) {
      name = name.substring(0, name.length - '.enc.ttl'.length);
    } else if (name.endsWith('.enc')) {
      name = name.substring(0, name.length - '.enc'.length);
    }
    return name;
  }
}
