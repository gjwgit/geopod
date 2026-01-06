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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:geopod/models/place.dart';
import 'package:geopod/services/places_service.dart' show PlacesCacheManager;
import 'package:geopod/widgets/map/delete_place_handler.dart';
import 'package:geopod/widgets/map/marker_data.dart';
import 'package:geopod/widgets/map/place_save_handler.dart';

/// Handles optimistic save of a place.
///
/// Updates UI immediately, then performs background save.
/// If [encrypted] is true, the place will be marked as encrypted for
/// immediate purple marker display.
void handleOptimisticPlaceSave({
  required Place place,
  required List<Place> allPlaces,
  required Set<String> savingPlaceIds,
  required BuildContext context,
  required void Function(void Function()) setState,
  required Future<void> Function(Place) performBackgroundSave,
  bool encrypted = false,
}) {
  // Mark place as encrypted if saving to encrypted storage
  final placeToSave = encrypted ? place.copyWith(isEncrypted: true) : place;
  // Update state first
  setState(() {
    allPlaces.insert(0, placeToSave);
    savingPlaceIds.add(placeToSave.id);
  });
  // Show snackbar after frame to avoid jank
  SchedulerBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) {
      showSavingSnackbar(context, placeToSave);
    }
  });
  // Start background save
  unawaited(performBackgroundSave(placeToSave));
}

/// Performs background save and updates UI on completion.
Future<void> performPlaceBackgroundSave({
  required Place originalPlace,
  required BuildContext context,
  required List<Place> allPlaces,
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
      // Schedule state update after current frame to avoid animation jank
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        setState(() {
          final index = allPlaces.indexWhere((x) => x.id == originalPlace.id);
          if (index != -1) allPlaces[index] = updatedPlace;
          savingPlaceIds.remove(originalPlace.id);
        });
        PlacesCacheManager().cacheAllPlaces(allPlaces);
        showSaveSuccessSnackbar(context);
      });
    }
  } catch (e) {
    if (!context.mounted) return;
    // Schedule error handling after current frame
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      setState(() {
        allPlaces.removeWhere((x) => x.id == originalPlace.id);
        savingPlaceIds.remove(originalPlace.id);
      });
      showSaveErrorSnackbar(context, e);
    });
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
