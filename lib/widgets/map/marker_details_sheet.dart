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

/// Shows detailed information about a marker in a bottom sheet.
void showMarkerDetailsSheet(
  BuildContext context,
  MarkerData marker, {
  VoidCallback? onDelete,
}) {
  // Use marker's custom color for UI elements.
  final markerColor = marker.color;

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),

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

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.home_outlined,
                size: 20,
                color: marker.isSaving ? Colors.orange.shade600 : markerColor,
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

          // Delete button for user's saved places only.
          if (!marker.isLocal && !marker.isSaving && onDelete != null) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  onDelete();
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete This Place'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}
