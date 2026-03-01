/// Bottom sheet for displaying marker details.
///
// Time-stamp: <Monday 2025-12-08 08:22:27 +1100 Graham Williams>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program.  If not, see <https://opensource.org/license/gpl-3-0>.
///
/// Authors: Graham Williams, Miduo

library;

import 'package:flutter/material.dart';

import 'package:geopod/widgets/map/marker_data.dart';
import 'package:geopod/widgets/media/place_media_section.dart';
import 'package:geopod/widgets/weather_dialog.dart';

/// Shows detailed information about a marker in a scrollable bottom sheet.
///
/// Includes a [PlaceMediaSection] that lists any audio/video items linked to
/// this place and lets the user play them inline.

void showMarkerDetailsSheet(
  BuildContext context,
  MarkerData marker, {
  VoidCallback? onDelete,
  VoidCallback? onEdit,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      // Use a ConstrainedBox instead of DraggableScrollableSheet so the
      // sheet auto-sizes to its content height and avoids a large empty gap
      // at the bottom when there is little content.
      return SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
          ),
          child: _MarkerDetailsSheetContent(
            marker: marker,
            sheetContext: sheetContext,
            onDelete: onDelete,
            onEdit: onEdit,
          ),
        ),
      );
    },
  );
}

// ── Sheet content widget ─────────────────────────────────────────────────────

class _MarkerDetailsSheetContent extends StatelessWidget {
  const _MarkerDetailsSheetContent({
    required this.marker,
    required this.sheetContext,
    this.onDelete,
    this.onEdit,
  });

  final MarkerData marker;
  final BuildContext sheetContext;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final markerColor = marker.color;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: icon + title + weather + close ─────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: marker.isSaving
                      ? Colors.orange.shade50
                      : markerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: marker.isSaving
                    ? SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.orange.shade600,
                        ),
                      )
                    : Icon(Icons.place, color: markerColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      marker.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (marker.isSaving)
                      Text(
                        'Saving...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade600,
                        ),
                      )
                    else if (marker.isLocal)
                      Text(
                        'Example Location',
                        style: TextStyle(fontSize: 12, color: markerColor),
                      )
                    else
                      Text(
                        'Your Saved Place',
                        style: TextStyle(fontSize: 12, color: markerColor),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.cloud_outlined),
                onPressed: () => showWeatherDialog(
                  context: sheetContext,
                  latitude: marker.position.latitude,
                  longitude: marker.position.longitude,
                  address: marker.address,
                ),
                tooltip: 'View Weather',
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(sheetContext),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),

          // ── Description ────────────────────────────────────────────────
          if (marker.description.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notes, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    marker.description,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // ── Address ────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.home_outlined,
                size: 20,
                color:
                    marker.isSaving ? Colors.orange.shade600 : markerColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  marker.address ?? 'Address not available',
                  style: TextStyle(
                    fontSize: 14,
                    color: marker.isSaving
                        ? Colors.orange.shade600
                        : marker.address != null
                        ? markerColor
                        : Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Coordinates ────────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.location_on, size: 20, color: Colors.grey.shade600),
              const SizedBox(width: 12),
              Text(
                marker.coordinates,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
            ],
          ),

          // ── Linked media (audio / video) ───────────────────────────────
          PlaceMediaSection(placeId: marker.id),

          // ── Action buttons (edit / delete) ─────────────────────────────
          if (!marker.isLocal &&
              !marker.isSaving &&
              (onEdit != null || onDelete != null)) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                if (onEdit != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        onEdit!();
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (onEdit != null && onDelete != null)
                  const SizedBox(width: 12),
                if (onDelete != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        onDelete!();
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ],

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
