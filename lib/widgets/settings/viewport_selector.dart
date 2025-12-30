/// Widget for selecting initial viewport location with presets.
///
// Time-stamp: <2025-12-05 Miduo>
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

/// Predefined viewport presets for quick selection.
enum ViewportPreset {
  australia('Australia', -25.2744, 133.7751, 4.0),
  sydney('Sydney', -33.8688, 151.2093, 11.0),
  melbourne('Melbourne', -37.8136, 144.9631, 11.0),
  brisbane('Brisbane', -27.4698, 153.0251, 11.0),
  perth('Perth', -31.9505, 115.8605, 11.0),
  adelaide('Adelaide', -34.9285, 138.6007, 11.0),
  darwin('Darwin', -12.4634, 130.8456, 11.0),
  hobart('Hobart', -42.8821, 147.3272, 11.0),
  canberra('Canberra', -35.2809, 149.1300, 11.0);

  const ViewportPreset(this.displayName, this.lat, this.lng, this.zoom);

  final String displayName;
  final double lat;
  final double lng;
  final double zoom;
}

/// Widget for selecting initial viewport location.
class InitialViewportSelector extends StatelessWidget {
  const InitialViewportSelector({
    super.key,
    required this.lat,
    required this.lng,
    required this.zoom,
    required this.onChanged,
  });

  final double lat;
  final double lng;
  final double zoom;
  final void Function(double lat, double lng, double zoom) onChanged;

  String get _currentLocationName {
    // Find matching preset
    for (final preset in ViewportPreset.values) {
      if ((preset.lat - lat).abs() < 0.01 &&
          (preset.lng - lng).abs() < 0.01 &&
          (preset.zoom - zoom).abs() < 0.5) {
        return preset.displayName;
      }
    }
    return 'Custom (${lat.toStringAsFixed(2)}, ${lng.toStringAsFixed(2)})';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<ViewportPreset?>(
        value: null,
        hint: Row(
          children: [
            Icon(Icons.my_location, size: 20, color: Colors.grey.shade700),
            const SizedBox(width: 12),
            Text(_currentLocationName),
          ],
        ),
        isExpanded: true,
        underline: const SizedBox(),
        icon: const Icon(Icons.arrow_drop_down),
        items: ViewportPreset.values.map((preset) {
          return DropdownMenuItem<ViewportPreset>(
            value: preset,
            child: Row(
              children: [
                Icon(Icons.place, size: 20, color: Colors.grey.shade700),
                const SizedBox(width: 12),
                Text(preset.displayName),
              ],
            ),
          );
        }).toList(),
        onChanged: (ViewportPreset? preset) {
          if (preset != null) {
            onChanged(preset.lat, preset.lng, preset.zoom);
          }
        },
      ),
    );
  }
}
