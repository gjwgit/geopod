/// Debug utility: delete all geopod data from the user's Solid Pod.
///
/// This is a developer-facing helper intentionally kept separate from
/// production services so that the blast-radius of the import graph is
/// limited.  Do NOT use in production code paths.
///
// Time-stamp: <2026-03-03 Miduo>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';

import 'package:solidpod/solidpod.dart' show logoutPod;

import 'package:geopod/app.dart';
import 'package:geopod/services/media/media_pod_service.dart';
import 'package:geopod/services/places/encrypted_places_service.dart';
import 'package:geopod/services/places/places_cache_manager.dart';
import 'package:geopod/services/places/places_cache_persistence.dart';
import 'package:geopod/services/places/places_cache_service.dart';
import 'package:geopod/services/places_service.dart' show placesChangeNotifier;
import 'package:geopod/services/pod/pod_directory_service.dart';
import 'package:geopod/services/pod/pod_file_system.dart';

/// Result of a full-data-delete operation.

class DeleteAllResult {
  final bool success;
  final String? error;

  const DeleteAllResult({required this.success, this.error});
}

/// Service that orchestrates deletion of all geopod data from the Pod.
///
/// Deletes the following data subdirectories entirely (recursively):
/// - `data/places`           – regular place files
/// - `data/encrypted_data`   – encrypted place files
/// - `data/audio`            – audio index + binary/encrypted audio files
/// - `data/video`            – video index + binary/encrypted video files
///
/// All local in-memory and persistent caches are also cleared.
///
/// Encryption keys are NOT touched — use [deleteEncryptionKeys] for that.

class DebugDataService {
  DebugDataService._();

  /// Delete all geopod data and clear caches.
  ///
  /// Shows a confirmation dialog first.  Displays loading state while
  /// executing and a result snackbar when done.  Closes the settings dialog on
  /// success.

  static Future<void> deleteAllGeopodData(BuildContext context) async {
    final confirmed = await _confirmDialog(context);
    if (confirmed != true || !context.mounted) return;

    // Show loading overlay.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    DeleteAllResult result;
    try {
      result = await _performDelete();
    } catch (e) {
      result = DeleteAllResult(success: false, error: e.toString());
    }

    if (!context.mounted) return;
    Navigator.pop(context); // Close loading

    if (result.success) {
      // Force logout after wiping all data.
      // Ignore return value: "No logout URL" just means the OAuth2 endpoint
      // was unavailable, but local auth data is already cleared — that is
      // sufficient for our purposes.
      await logoutPod();

      if (!context.mounted) return;

      // Use the ROOT navigator so we escape any nested dialog/settings
      // navigator and truly clear the entire navigation stack.
      await Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const App()),
        (_) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting data: ${result.error}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  static Future<bool?> _confirmDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Geopod Data'),
        content: const Text(
          'This will permanently delete EVERYTHING inside your Geopod '
          'directory and log you out:\n\n'
          '• All regular and encrypted places\n'
          '• All audio and video media files\n'
          '• All other files and folders under geopod/\n'
          '• All local caches\n\n'
          'You will be automatically logged out afterwards.\n\n'
          'WARNING: This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  /// Deletes every item inside the geopod root directory by recursively
  /// listing and removing all children (files and sub-containers).
  ///
  /// The root container (geopod/) itself is NOT deleted — only its contents.

  static Future<DeleteAllResult> _performDelete() async {
    // List everything directly under geopod/ (the app root directory).
    final rootItems = await PodDirectoryService.listDirectory(
      '',
      forceRefresh: true,
    );

    // Delete each top-level entry in parallel.
    await Future.wait(
      rootItems.map((item) async {
        if (item.isDirectory) {
          await PodDirectoryService.deleteDirectoryRecursive(item.path);
        } else {
          await PodFileSystem.deleteFile(item.path);
        }
      }),
    );

    // ── Clear all in-memory and persistent caches ─────────────────────────
    PlacesCacheManager().clearCache();
    await Future.wait([
      PlacesCachePersistence.clearPodPlacesCache(),
      EncryptedPlacesService.resetSessionState(),
    ]);
    EncryptedPlacesService.clearCache();
    MediaPodService.clearCache();
    await PlacesCacheService.clearPodCacheOnly();

    // ── Notify all listeners ──────────────────────────────────────────────
    placesChangeNotifier.value++;
    PodDirectoryService.clearCache();
    PodDirectoryService.notifyChange();

    return const DeleteAllResult(success: true);
  }
}
