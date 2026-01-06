/// Place save handler for optimistic saving with background updates.
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

import 'package:flutter_map/flutter_map.dart';
import 'package:solidpod/solidpod.dart';

import 'package:geopod/services/geocoding_service.dart';
import 'package:geopod/services/places/encrypted_places_service.dart';
import 'package:geopod/services/places_service.dart';
import 'package:geopod/widgets/add_place_form.dart';
import 'package:geopod/widgets/geomap.dart';
import 'package:geopod/widgets/map/login_required_dialog.dart';

/// Shows a saving snackbar for optimistic save.
void showSavingSnackbar(BuildContext context, Place place) {
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
          Expanded(child: Text('Saving "${place.displayTitle}"...')),
        ],
      ),
      backgroundColor: Colors.blue.shade600,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}

/// Shows a success snackbar after place is saved.
void showSaveSuccessSnackbar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.white),
          SizedBox(width: 12),
          Expanded(child: Text('Place saved successfully!')),
        ],
      ),
      backgroundColor: Colors.green.shade600,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}

/// Shows an error snackbar when save fails.
void showSaveErrorSnackbar(BuildContext context, dynamic error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text('Failed to save: $error')),
        ],
      ),
      backgroundColor: Colors.red.shade600,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ),
  );
}

/// Performs background save of a place with address lookup.
/// Note: Context is passed through to PlacesService which handles mounted checks internally.
/// If [encrypted] is true, saves to encrypted storage.
Future<Place?> performBackgroundSave(
  Place originalPlace,
  BuildContext context, {
  bool encrypted = false,
}) async {
  final address = await GeocodingService.getAddress(
    originalPlace.lat,
    originalPlace.lng,
  );
  final updatedPlace = Place(
    id: originalPlace.id,
    lat: originalPlace.lat,
    lng: originalPlace.lng,
    note: originalPlace.note,
    timestamp: originalPlace.timestamp,
    address: address,
    isEncrypted: encrypted,
  );
  if (!context.mounted) return null;

  bool success;
  if (encrypted) {
    // Save to encrypted storage
    success = await EncryptedPlacesService.addEncryptedPlace(
      updatedPlace,
      context,
      const GeoMapWidget(),
    );
  } else {
    // Save to regular storage
    success = await PlacesService.addPlace(
      updatedPlace,
      context,
      const GeoMapWidget(),
    );
  }

  if (success) {
    return updatedPlace;
  } else {
    throw Exception(encrypted ? 'Encrypted save failed' : 'WritePod failed');
  }
}

/// Shows the add place dialog and returns the result.
/// Returns null if user is not logged in or cancels.
/// Returns AddPlaceResult with place and encryption flag.
Future<AddPlaceResult?> showAddPlaceDialogIfLoggedIn({
  required BuildContext context,
  double? latitude,
  double? longitude,
}) async {
  final webId = await getWebId();
  if (webId == null || webId.isEmpty) {
    if (!context.mounted) return null;
    await showLoginRequiredDialog(context);
    return null;
  }
  if (!context.mounted) return null;
  final result = await showDialog<AddPlaceResult>(
    context: context,
    builder: (_) => AddPlaceForm(
      initialLatitude: latitude,
      initialLongitude: longitude,
      returnWidget: const GeoMapWidget(),
    ),
  );
  return result;
}

/// Zoom in the map by a fixed amount.
void zoomIn(MapController mapController) {
  final z = mapController.camera.zoom;
  mapController.move(mapController.camera.center, (z + 0.6).clamp(3.0, 18.0));
}

/// Zoom out the map by a fixed amount.
void zoomOut(MapController mapController) {
  final z = mapController.camera.zoom;
  mapController.move(mapController.camera.center, (z - 0.6).clamp(3.0, 18.0));
}
