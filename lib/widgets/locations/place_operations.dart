/// Place operations handlers for LocationsPage.
///
// Time-stamp: <Tuesday 2026-01-14 +1100>
///
/// Copyright (C) 2025-2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';

import 'package:geopod/services/places_service.dart';
import 'package:geopod/utils/ui_utils.dart';
import 'package:geopod/widgets/locations_page.dart';

/// Shows delete confirmation dialog.

Future<bool> showDeletePlaceConfirmation(BuildContext context, Place place) {
  return DialogHelper.showDestructiveConfirmation(
    context,
    title: 'Delete Place',
    content: 'Are you sure you want to delete "${place.displayTitle}"?',
    confirmText: 'Delete',
  );
}

/// Shows clear all confirmation dialog.

Future<bool> showClearAllConfirmation(BuildContext context, int count) {
  return DialogHelper.showDestructiveConfirmation(
    context,
    title: 'Clear All Places',
    content:
        'Are you sure you want to delete ALL $count saved places?\n\nThis action cannot be undone.',
    confirmText: 'Clear All',
  );
}

/// Deletes a place and shows appropriate snackbars.

Future<bool> deletePlaceWithFeedback(BuildContext context, Place place) async {
  SnackBarHelper.showInfo(
    context,
    'Deleting place...',
    duration: const Duration(seconds: 1),
  );

  final success = await PlacesService.deletePlace(
    place.id,
    context,
    const LocationsPage(),
  );

  if (!context.mounted) return success;

  if (success) {
    SnackBarHelper.showSuccess(context, 'Place deleted successfully');
  } else {
    SnackBarHelper.showError(context, 'Failed to delete place');
  }
  return success;
}

/// Clears all places and shows appropriate snackbars.

Future<bool> clearAllPlacesWithFeedback(BuildContext context, int count) async {
  SnackBarHelper.showInfo(
    context,
    'Clearing all places...',
    duration: const Duration(seconds: 1),
  );

  final success = await PlacesService.clearAllPlaces(
    context,
    const LocationsPage(),
  );

  if (!context.mounted) return success;

  if (success) {
    SnackBarHelper.showSuccess(context, 'Cleared $count places successfully');
  } else {
    SnackBarHelper.showError(context, 'Failed to clear places');
  }
  return success;
}

/// Shows export success/failure snackbar.

void showExportResultSnackbar(BuildContext context, bool success, int count) {
  if (success) {
    SnackBarHelper.showSuccess(context, 'Exported $count places successfully');
  } else {
    SnackBarHelper.showError(context, 'Failed to export places');
  }
}

/// Shows updating place snackbar.

void showUpdatingPlaceSnackbar(BuildContext context, bool coordsChanged) {
  SnackBarHelper.showLoading(
    context,
    coordsChanged
        ? 'Updating place and fetching new address...'
        : 'Updating place...',
  );
}

/// Shows update success snackbar.

void showUpdateSuccessSnackbar(BuildContext context) {
  SnackBarHelper.showSuccess(context, 'Place updated successfully');
}

/// Shows update failure snackbar.

void showUpdateFailureSnackbar(BuildContext context) {
  SnackBarHelper.showError(context, 'Failed to update place');
}
