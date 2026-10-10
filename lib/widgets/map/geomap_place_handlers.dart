/// Place save/delete handlers for GeoMapWidget.
///
// Time-stamp: <2025-12-31 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.
///
/// Authors: Graham Williams, Miduo

library;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:geopod/models/place.dart';
import 'package:geopod/widgets/map/delete_place_handler.dart';
import 'package:geopod/widgets/map/marker_data.dart';
import 'package:geopod/widgets/map/place_save_handler.dart';

/// Handles optimistic save of a place.
///
/// Updates UI immediately, then performs the save.  The returned future
/// completes only when the Pod write has finished, so a window close can wait
/// on it rather than killing the write mid-flight.
/// If [encrypted] is true, the place will be marked as encrypted for
/// immediate purple marker display.

Future<void> handleOptimisticPlaceSave({
  required Place place,
  required List<Place> allPlaces,
  required Set<String> savingPlaceIds,
  required BuildContext context,
  required void Function(void Function()) setState,
  required Future<void> Function(Place) performBackgroundSave,
  bool encrypted = false,
}) async {
  // Mark place as encrypted if saving to encrypted storage.
  final placeToSave = encrypted ? place.copyWith(isEncrypted: true) : place;

  // Update state first.

  setState(() {
    allPlaces.insert(0, placeToSave);
    savingPlaceIds.add(placeToSave.id);
  });

  // Show snackbar after frame to avoid jank.

  SchedulerBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) {
      showSavingSnackbar(context, placeToSave);
    }
  });

  // Start the save, awaited so the caller can wait for the Pod write.

  await performBackgroundSave(placeToSave);
}

/// Performs background save and updates UI on completion.
///
/// [allPlaces] is read when the save completes rather than captured up front:
/// the write fires placesChangeNotifier, whose reload replaces the widget's
/// list, so a list captured before the save may no longer be the one shown.
/// The services keep the places cache up to date themselves.

Future<void> performPlaceBackgroundSave({
  required Place originalPlace,
  required BuildContext context,
  required List<Place> Function() allPlaces,
  required Set<String> savingPlaceIds,
  required void Function(void Function()) setState,
  bool encrypted = false,
}) async {
  try {
    final updatedPlace = await performBackgroundSave(
      originalPlace,
      context,
      encrypted: encrypted,
    );
    if (!context.mounted) return;
    if (updatedPlace != null) {
      // Schedule state update after current frame to avoid animation jank.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        setState(() {
          final places = allPlaces();
          final index = places.indexWhere((x) => x.id == originalPlace.id);
          if (index != -1) places[index] = updatedPlace;
          savingPlaceIds.remove(originalPlace.id);
        });
        showSaveSuccessSnackbar(context);
      });
    }
  } catch (_) {
    // Schedule the rollback of the optimistic marker after the current frame.

    if (context.mounted) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        setState(() {
          allPlaces().removeWhere((x) => x.id == originalPlace.id);
          savingPlaceIds.remove(originalPlace.id);
        });
      });
    }

    // Rethrow so the form that started this save knows the write failed and
    // keeps the user's text instead of closing over the top of it. The form
    // reports the failure as a modal dialog.

    rethrow;
  }
}

/// Confirms and deletes a place with optimistic UI updates.

Future<void> confirmAndDeletePlace({
  required MarkerData marker,
  required BuildContext context,
  required List<Place> allPlaces,
  required void Function(void Function()) setState,
}) async {
  final confirmed = await showDeleteConfirmationDialog(context, marker);
  if (!confirmed || !context.mounted) return;

  final prep = prepareDeletePlace(marker: marker, allPlaces: allPlaces);
  if (!prep.success) {
    if (context.mounted) showPlaceNotFoundSnackbar(context);
    return;
  }

  setState(() => allPlaces.removeAt(prep.removedIndex!));
  if (!context.mounted) return;

  // Update cache BEFORE server delete to prevent race condition
  // (placesChangeNotifier triggers _loadAllPlaces which would restore old data)

  updateCacheAfterDelete(allPlaces);

  showDeletingSnackbar(context);
  final success = await performDeleteOnServer(
    placeId: marker.id,
    context: context,
    isEncrypted: marker.isEncrypted,
  );

  if (!context.mounted) return;
  if (success) {
    showDeleteSuccessSnackbar(context);
  } else {
    setState(
      () => restorePlace(
        allPlaces: allPlaces,
        originalIndex: prep.removedIndex!,
        removedPlace: prep.removedPlace!,
      ),
    );
    showDeleteErrorSnackbar(context);
  }
}
