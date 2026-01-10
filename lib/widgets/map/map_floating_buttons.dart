/// Map floating action buttons widget.
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

/// Column of floating action buttons for map controls.
class MapFloatingButtons extends StatelessWidget {
  final bool isLoadingPlaces;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onRefresh;

  const MapFloatingButtons({
    super.key,
    required this.isLoadingPlaces,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton.small(
          heroTag: 'zoomIn',
          onPressed: onZoomIn,
          tooltip: 'Zoom In',
          backgroundColor: Colors.grey.shade800,
          foregroundColor: Colors.white,
          child: const Icon(Icons.add, size: 20),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'zoomOut',
          onPressed: onZoomOut,
          tooltip: 'Zoom Out',
          backgroundColor: Colors.grey.shade800,
          foregroundColor: Colors.white,
          child: const Icon(Icons.remove, size: 20),
        ),
        const SizedBox(height: 16),
        FloatingActionButton.small(
          heroTag: 'refresh',
          onPressed: isLoadingPlaces ? null : onRefresh,
          tooltip: 'Refresh Places',
          backgroundColor: isLoadingPlaces ? Colors.grey : Colors.blue,
          foregroundColor: Colors.white,
          child: isLoadingPlaces
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.refresh),
        ),
      ],
    );
  }
}
