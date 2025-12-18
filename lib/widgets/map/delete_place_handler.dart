/// Delete place handler for GeoMap.
///
// Time-stamp: <2025-12-18 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';

import 'package:geopod/widgets/map/marker_data.dart';

/// Shows a confirmation dialog for deleting a place.
Future<bool> showDeleteConfirmationDialog(
  BuildContext context,
  MarkerData marker,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Place'),
      content: SingleChildScrollView(
        child: Text(
          'Are you sure you want to delete "${marker.title}"?\n\n'
          'This action cannot be undone.',
        ),
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
  return confirmed == true;
}

/// Shows a snackbar indicating place not found.
void showPlaceNotFoundSnackbar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Place not found'),
      backgroundColor: Colors.orange,
    ),
  );
}

/// Shows a snackbar indicating deletion in progress.
void showDeletingSnackbar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Deleting place...'),
      duration: Duration(seconds: 1),
    ),
  );
}

/// Shows a success snackbar after place is deleted.
void showDeleteSuccessSnackbar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.white),
          SizedBox(width: 12),
          Expanded(child: Text('Place deleted successfully')),
        ],
      ),
      backgroundColor: Colors.green.shade600,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Shows an error snackbar when delete fails.
void showDeleteErrorSnackbar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Row(
        children: [
          Icon(Icons.error_outline, color: Colors.white),
          SizedBox(width: 12),
          Expanded(child: Text('Failed to delete place')),
        ],
      ),
      backgroundColor: Colors.red.shade600,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
