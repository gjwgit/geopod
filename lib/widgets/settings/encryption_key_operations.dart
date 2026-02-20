/// Encryption key operations for settings dialog.
///
// Time-stamp: <Wednesday 2026-02-18 07:58:54 +1100 Graham Williams>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';

import 'package:solidpod/solidpod.dart';

/// Deletes encryption keys from the server.
///
/// This is a DEBUG function that removes:
/// - enc-keys.ttl (verification key + private key)
/// - ind-keys.ttl (individual file keys)
/// - public-key.ttl (public key)
///
/// WARNING: All encrypted data will become unreadable after this operation.

Future<void> deleteEncryptionKeys(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Encryption Keys'),
      content: const Text(
        'This will delete all encryption keys from the server.\n\n'
        'This includes:\n'
        '• enc-keys.ttl (verification key + private key)\n'
        '• ind-keys.ttl (individual file keys)\n'
        '• public-key.ttl (public key)\n\n'
        'WARNING: All encrypted data will become unreadable!\n'
        'This action cannot be undone.',
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
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    // Show loading indicator.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // Get the webId to construct full URLs.
    final webId = await getWebId();
    if (webId == null || webId.isEmpty) {
      throw Exception('User not logged in');
    }

    // appDirName for geopod is 'geopod', files are relative to POD root
    // deleteFile expects path relative to POD root (not appDirName)
    // The file paths should be: geopod/encryption/enc-keys.ttl etc.
    final filesToDelete = [
      'geopod/encryption/enc-keys.ttl',
      'geopod/encryption/ind-keys.ttl',
      'geopod/sharing/public-key.ttl',
    ];

    final deletedFiles = <String>[];
    final failedFiles = <String>[];

    for (final filePath in filesToDelete) {
      try {
        debugPrint('Attempting to delete: $filePath');

        // deleteFile() with isKey: true only deletes the file without trying to
        // revoke permissions or remove individual keys.

        await deleteFile(fileUrl: filePath, isKey: true);
        deletedFiles.add(filePath);
        debugPrint('Deleted: $filePath');
      } catch (e) {
        failedFiles.add(filePath);
        debugPrint('Failed to delete $filePath: $e');
      }
    }

    // Clear local key cache.
    await KeyManager.clear();

    if (context.mounted) {
      Navigator.pop(context); // Close loading
      Navigator.pop(context); // Close settings dialog

      final message = deletedFiles.isNotEmpty
          ? 'Deleted ${deletedFiles.length} files. '
                '${failedFiles.isNotEmpty ? "Failed: ${failedFiles.length}" : ""}'
                '\nPlease logout and login.'
          : 'No files were deleted. ${failedFiles.length} failures.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: deletedFiles.isNotEmpty ? Colors.orange : Colors.red,
        ),
      );
    }
  } catch (e) {
    debugPrint('Error deleting encryption keys: $e');
    if (context.mounted) {
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
