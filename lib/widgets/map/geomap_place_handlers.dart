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

import 'package:geopod/models/place.dart';
import 'package:geopod/services/places_service.dart' show PlacesCacheManager;
import 'package:geopod/widgets/map/delete_place_handler.dart';
import 'package:geopod/widgets/map/marker_data.dart';
import 'package:geopod/widgets/map/place_save_handler.dart';

/// Handles optimistic save of a place.
///
/// Updates UI immediately, then performs background save.
void handleOptimisticPlaceSave({
  required Place place,
  required List<Place> allPlaces,
  required Set<String> savingPlaceIds,
  required BuildContext context,
  required void Function(void Function()) setState,
  required Future<void> Function(Place) performBackgroundSave,
}) {
  setState(() {
    allPlaces.insert(0, place);
    savingPlaceIds.add(place.id);
  });
  showSavingSnackbar(context, place);
  unawaited(performBackgroundSave(place));
}

/// Performs background save and updates UI on completion.
Future<void> performPlaceBackgroundSave({
  required Place originalPlace,
  required BuildContext context,
  required List<Place> allPlaces,
  required Set<String> savingPlaceIds,
  required void Function(void Function()) setState,
}) async {
  try {
    final updatedPlace = await performBackgroundSave(originalPlace, context);
    if (!context.mounted) return;
    if (updatedPlace != null) {
      setState(() {
        final index = allPlaces.indexWhere((x) => x.id == originalPlace.id);
        if (index != -1) allPlaces[index] = updatedPlace;
        savingPlaceIds.remove(originalPlace.id);
      });
      PlacesCacheManager().cacheAllPlaces(allPlaces);
      showSaveSuccessSnackbar(context);
    }
  } catch (e) {
    if (!context.mounted) return;
    setState(() {
      allPlaces.removeWhere((x) => x.id == originalPlace.id);
      savingPlaceIds.remove(originalPlace.id);
    });
    showSaveErrorSnackbar(context, e);
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

  showDeletingSnackbar(context);
  final success = await performDeleteOnServer(
    placeId: marker.id,
    context: context,
  );

  if (!context.mounted) return;
  if (success) {
    updateCacheAfterDelete(allPlaces);
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
