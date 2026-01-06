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

import 'package:geopod/models/place.dart';
import 'package:geopod/services/places/encrypted_places_service.dart';
import 'package:geopod/services/places_service.dart'
    show PlacesService, PlacesCacheManager;
import 'package:geopod/widgets/geomap.dart';
import 'package:geopod/widgets/map/marker_data.dart';

/// Result of a delete operation.
class DeletePlaceResult {
  final bool success;
  final int? removedIndex;
  final Place? removedPlace;

  const DeletePlaceResult({
    required this.success,
    this.removedIndex,
    this.removedPlace,
  });
}

/// Prepares a place for deletion by finding it in the list.
DeletePlaceResult prepareDeletePlace({
  required MarkerData marker,
  required List<Place> allPlaces,
}) {
  final index = allPlaces.indexWhere((p) => p.id == marker.id);
  if (index == -1) {
    return const DeletePlaceResult(success: false);
  }
  return DeletePlaceResult(
    success: true,
    removedIndex: index,
    removedPlace: allPlaces[index],
  );
}

/// Restores a place after failed deletion.
void restorePlace({
  required List<Place> allPlaces,
  required int originalIndex,
  required Place removedPlace,
}) {
  if (originalIndex >= 0 && originalIndex <= allPlaces.length) {
    allPlaces.insert(originalIndex, removedPlace);
  } else {
    allPlaces.add(removedPlace);
  }
}

/// Updates cache after successful deletion.
void updateCacheAfterDelete(List<Place> allPlaces) {
  PlacesCacheManager().cacheAllPlaces(allPlaces);
}

/// Performs the delete operation on the server.
/// Routes to appropriate service based on whether the place is encrypted.
Future<bool> performDeleteOnServer({
  required String placeId,
  required BuildContext context,
  required bool isEncrypted,
}) async {
  if (isEncrypted) {
    // Delete from encrypted places service
    return await EncryptedPlacesService.deleteEncryptedPlace(
      placeId,
      context,
      const GeoMapWidget(),
    );
  } else {
    // Delete from regular places service
    return await PlacesService.deletePlace(
      placeId,
      context,
      const GeoMapWidget(),
    );
  }
}

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
