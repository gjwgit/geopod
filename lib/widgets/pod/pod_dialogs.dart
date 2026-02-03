/// Dialog utilities for POD file browser.
///
// Time-stamp: <2026-01-02 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';

/// Show confirmation dialog for deleting the main places.json file.

Future<bool> showDeletePlacesConfirmation(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete All Places?'),
          content: const Text(
            'This will delete all your saved places data, including the main '
            'places.json file and all individual place files.\n\n'
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete All'),
            ),
          ],
        ),
      ) ??
      false;
}

/// Show snackbar for file operation result.

void showFileOperationSnackBar(
  BuildContext context, {
  required String message,
  required bool success,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: success ? Colors.green : Colors.red,
    ),
  );
}

/// Show snackbar for delete in progress.

void showDeletingSnackBar(BuildContext context, String fileName) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Deleting $fileName...'),
      duration: const Duration(seconds: 1),
    ),
  );
}
