/// User action handlers for GeoMap (add, save, delete places).
///
// Time-stamp: <Tuesday 2026-01-14 +1100>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.
///
/// Authors: Miduo

library;

import 'package:flutter/material.dart';

import 'package:geopod/services/places_service.dart';
import 'package:geopod/utils/ui_utils.dart';

/// Handles user actions for place management.
mixin GeoMapActionHandlers<T extends StatefulWidget> on State<T> {
  Set<String> get savingPlaceIds;
  List<Place> get allPlaces;
  set allPlaces(List<Place> value);
  bool get skipPlacesChangeNotification;
  set skipPlacesChangeNotification(bool value);
  bool get isLoadingPlaces;

  Future<void> loadAllPlaces();

  /// Handle refresh button tap - reload places and show success message.
  Future<void> handleRefreshPressed() async {
    if (isLoadingPlaces) return;

    try {
      await loadAllPlaces();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Refreshed successfully! ${allPlaces.length} places loaded',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refresh failed: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Handle optimistic save of place.
  Future<void> handleOptimisticSave(Place place) async {
    // Prevent places change notifications during save
    skipPlacesChangeNotification = true;

    // Show immediately (optimistic update)
    setState(() {
      savingPlaceIds.add(place.id);
      allPlaces = [...allPlaces, place];
    });

    try {
      final success = await PlacesService.addPlace(place, context, widget);

      if (mounted) {
        if (success) {
          SnackBarHelper.showSuccess(context, 'Place saved successfully');
        } else {
          // Rollback on failure
          setState(() {
            allPlaces = allPlaces.where((p) => p.id != place.id).toList();
          });
          SnackBarHelper.showError(context, 'Failed to save place');
        }
      }
    } catch (e) {
      // Rollback on error
      if (mounted) {
        setState(() {
          allPlaces = allPlaces.where((p) => p.id != place.id).toList();
        });
        SnackBarHelper.showError(context, 'Failed to save place: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          savingPlaceIds.remove(place.id);
        });
      }
      skipPlacesChangeNotification = false;
    }
  }

  /// Confirm and delete a place.
  Future<void> confirmAndDeletePlace(Place place) async {
    if (!mounted) return;

    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: 'Delete Place',
      content: 'Are you sure you want to delete "${place.displayTitle}"?',
      confirmText: 'Delete',
    );

    if (!confirmed || !mounted) return;

    try {
      final success = await PlacesService.deletePlace(
        place.id,
        context,
        widget,
      );

      if (!mounted) return;
      if (success) {
        SnackBarHelper.showSuccess(context, 'Place deleted successfully');
      } else {
        SnackBarHelper.showError(context, 'Failed to delete place');
      }
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(context, 'Failed to delete place: $e');
    }
  }
}
