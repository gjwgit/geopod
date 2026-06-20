/// A list tile widget for displaying a single user place.
///
// Time-stamp: <2025-12-04 Miduo>
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

import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:gap/gap.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import 'package:geopod/models/place.dart';
import 'package:geopod/services/navigation_service.dart'
    show currentPageNotifier, pendingNavTarget;
import 'package:geopod/widgets/locations/detail_row.dart';
import 'package:geopod/widgets/media/media_link_picker_dialog.dart';
import 'package:geopod/widgets/media/place_media_section.dart';

/// A list tile widget for displaying a single user place.
///
/// Only displays user's Pod data (not local canned examples).

class PlaceListTile extends StatelessWidget {
  const PlaceListTile({
    super.key,
    required this.place,
    this.onEdit,
    this.onDelete,
  });

  final Place place;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(Icons.place, color: Colors.white),
        ),
        title: Text(
          place.displayTitle,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (place.note.isNotEmpty) ...[
              const Gap(2),
              Text(
                place.note,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const Gap(4),
            Row(
              children: [
                Icon(
                  Icons.home_outlined,
                  size: 14,
                  color: place.address != null ? Colors.blue : Colors.grey,
                ),
                const Gap(4),
                Expanded(
                  child: Text(
                    place.shortAddress,
                    style: TextStyle(
                      fontSize: 12,
                      color: place.address != null
                          ? Colors.blue.shade700
                          : Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Gap(2),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const Gap(4),
                Text(
                  place.coordinates,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const Gap(2),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const Gap(4),
                Text(
                  place.formattedDate,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onEdit != null)
              IconButton(
                icon: Icon(Icons.edit_outlined, color: Colors.blue.shade600),
                onPressed: onEdit,
                tooltip: 'Edit',
              ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: onDelete,
                tooltip: 'Delete',
              ),
          ],
        ),
        isThreeLine: true,
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.place, color: Colors.blue),
                  const Gap(8),
                  Expanded(child: Text(place.displayTitle)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (place.note.isNotEmpty) ...[
                      Text(
                        'Notes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const Gap(4),
                      MarkdownBody(data: place.note),
                      const Gap(12),
                    ],
                    DetailRow(
                      label: 'Address',
                      value: place.address ?? 'No address available',
                    ),
                    const Gap(12),
                    DetailRow(
                      label: 'Latitude',
                      value: place.lat.toStringAsFixed(6),
                    ),
                    const Gap(8),
                    DetailRow(
                      label: 'Longitude',
                      value: place.lng.toStringAsFixed(6),
                    ),
                    const Gap(8),
                    DetailRow(label: 'Saved', value: place.formattedDate),
                    PlaceMediaSection(
                      placeId: place.id,
                      onManageLinks: () => showMediaLinkPickerDialog(
                        context,
                        placeId: place.id,
                        placeTitle: place.displayTitle,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    pendingNavTarget.value = LatLng(place.lat, place.lng);
                    currentPageNotifier.value = 0;
                  },
                  icon: const Icon(Icons.near_me),
                  label: const Text('Navigate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
