/// Place operations handlers for LocationsPage.
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

import 'package:geopod/services/places_service_v2.dart';
import 'package:geopod/widgets/locations_page.dart';

/// Shows delete confirmation dialog.
Future<bool> showDeletePlaceConfirmation(
  BuildContext context,
  Place place,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Place'),
      content: Text('Are you sure you want to delete "${place.displayTitle}"?'),
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

/// Shows clear all confirmation dialog.
Future<bool> showClearAllConfirmation(BuildContext context, int count) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange),
          SizedBox(width: 8),
          Text('Clear All Places'),
        ],
      ),
      content: Text(
        'Are you sure you want to delete ALL $count saved places?\n\nThis action cannot be undone.',
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
          child: const Text('Clear All'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Deletes a place and shows appropriate snackbars.
Future<bool> deletePlaceWithFeedback(BuildContext context, Place place) async {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Deleting place...'),
      duration: Duration(seconds: 1),
    ),
  );
  final success = await PlacesServiceV2.deletePlaceById(
    place.id,
    context,
    const LocationsPage(),
  );
  if (!context.mounted) return success;
  if (success) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Place deleted successfully'),
        backgroundColor: Colors.green,
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Failed to delete place'),
        backgroundColor: Colors.red,
      ),
    );
  }
  return success;
}

/// Clears all places and shows appropriate snackbars.
Future<bool> clearAllPlacesWithFeedback(BuildContext context, int count) async {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Clearing all places...'),
      duration: Duration(seconds: 1),
    ),
  );
  final success = await PlacesServiceV2.clearAllPlaces(
    context,
    const LocationsPage(),
  );
  if (!context.mounted) return success;
  if (success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text('Cleared $count places successfully'),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Failed to clear places'),
        backgroundColor: Colors.red,
      ),
    );
  }
  return success;
}

/// Shows export success/failure snackbar.
void showExportResultSnackbar(BuildContext context, bool success, int count) {
  ScaffoldMessenger.of(context).showSnackBar(
    success
        ? SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Exported $count places successfully'),
              ],
            ),
            backgroundColor: Colors.green,
          )
        : const SnackBar(
            content: Text('Failed to export places'),
            backgroundColor: Colors.red,
          ),
  );
}

/// Shows updating place snackbar.
void showUpdatingPlaceSnackbar(BuildContext context, bool coordsChanged) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            coordsChanged
                ? 'Updating place and fetching new address...'
                : 'Updating place...',
          ),
        ],
      ),
      backgroundColor: Colors.blue,
      duration: const Duration(seconds: 2),
    ),
  );
}

/// Shows update success snackbar.
void showUpdateSuccessSnackbar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.white),
          SizedBox(width: 12),
          Text('Place updated successfully'),
        ],
      ),
      backgroundColor: Colors.green,
    ),
  );
}

/// Shows update failure snackbar.
void showUpdateFailureSnackbar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Failed to update place'),
      backgroundColor: Colors.red,
    ),
  );
}
