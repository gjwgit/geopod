/// Locations page header widget.
///
// Time-stamp: <2025-12-08 Graham Williams>
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

/// Header section showing title and count of places.

class LocationsPageHeader extends StatelessWidget {
  final int placeCount;
  final bool isLoading;
  final VoidCallback onRefresh;

  const LocationsPageHeader({
    super.key,
    required this.placeCount,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.blue),
          const SizedBox(width: 8),
          Text(
            'My Places ($placeCount)',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: onRefresh,
              tooltip: 'Refresh',
            ),
        ],
      ),
    );
  }
}

/// Action buttons row for import/export/clear, with optional encrypted toggle.

class LocationsActionButtons extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onExport;
  final VoidCallback onImport;
  final VoidCallback onClearAll;

  /// Whether to show the encrypted-places toggle inline.
  final bool showEncryptedToggle;

  /// Current state of the encrypted-places toggle.
  final bool showEncryptedPlaces;

  /// Callback when the toggle is changed.
  final void Function(bool)? onToggleEncrypted;

  const LocationsActionButtons({
    super.key,
    required this.isLoading,
    required this.onExport,
    required this.onImport,
    required this.onClearAll,
    this.showEncryptedToggle = false,
    this.showEncryptedPlaces = false,
    this.onToggleEncrypted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isLoading ? null : onExport,
              icon: const Icon(Icons.file_upload_outlined, size: 18),
              label: const Text('Export'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green.shade700,
                side: BorderSide(color: Colors.green.shade300),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isLoading ? null : onImport,
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('Import'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue.shade700,
                side: BorderSide(color: Colors.blue.shade300),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isLoading ? null : onClearAll,
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: const Text('Clear All'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300),
              ),
            ),
          ),
          if (showEncryptedToggle) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: 'Show encrypted places',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: Colors.purple,
                  ),
                  Switch(
                    value: showEncryptedPlaces,
                    onChanged: isLoading ? null : onToggleEncrypted,
                    activeThumbColor: Colors.purple,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
