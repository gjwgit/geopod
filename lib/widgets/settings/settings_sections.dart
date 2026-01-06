/// Settings sections for map settings dialog.
///
// Time-stamp: <2026-01-07 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';

import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'package:geopod/services/map_settings_service.dart';
import 'package:geopod/widgets/settings/color_picker_tile.dart';
import 'package:geopod/widgets/settings/viewport_selector.dart';

/// Shows color picker dialog for selecting a color.
Future<void> showColorPickerDialog({
  required BuildContext context,
  required String title,
  required Color currentColor,
  required void Function(Color) onColorChanged,
}) async {
  Color selectedColor = currentColor;

  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: BlockPicker(
          pickerColor: currentColor,
          onColorChanged: (color) {
            selectedColor = color;
          },
          availableColors: const [
            Colors.red,
            Colors.pink,
            Colors.purple,
            Colors.deepPurple,
            Colors.indigo,
            Colors.blue,
            Colors.lightBlue,
            Colors.cyan,
            Colors.teal,
            Colors.green,
            Colors.lightGreen,
            Colors.lime,
            Colors.yellow,
            Colors.amber,
            Colors.orange,
            Colors.deepOrange,
            Colors.brown,
            Colors.grey,
            Colors.blueGrey,
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            onColorChanged(selectedColor);
            Navigator.pop(context);
          },
          child: const Text('Select'),
        ),
      ],
    ),
  );
}

/// Builds the visibility section of settings.
Widget buildVisibilitySection({
  required bool showLocalPlaces,
  required bool showEncryptedPlaces,
  required bool isLoadingEncrypted,
  required void Function(bool) onShowLocalChanged,
  required void Function(bool) onShowEncryptedChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Visibility',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
      const SizedBox(height: 8),
      SwitchListTile(
        title: const Text('Show Example Locations'),
        subtitle: const Text('Display canned examples on map'),
        value: showLocalPlaces,
        onChanged: onShowLocalChanged,
        secondary: Icon(
          showLocalPlaces ? Icons.visibility : Icons.visibility_off,
          color: showLocalPlaces ? Colors.green : Colors.grey,
        ),
      ),
      const SizedBox(height: 8),
      SwitchListTile(
        title: const Text('Show Encrypted Places'),
        subtitle: Text(
          isLoadingEncrypted
              ? 'Loading encrypted data...'
              : 'Display encrypted places (requires key)',
        ),
        value: showEncryptedPlaces,
        onChanged: isLoadingEncrypted ? null : onShowEncryptedChanged,
        secondary: isLoadingEncrypted
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                showEncryptedPlaces ? Icons.lock_open : Icons.lock,
                color: showEncryptedPlaces ? Colors.purple : Colors.grey,
              ),
      ),
    ],
  );
}

/// Builds the viewport section of settings.
Widget buildViewportSection({
  required bool rememberViewport,
  required double initialLat,
  required double initialLng,
  required double initialZoom,
  required void Function(bool) onRememberViewportChanged,
  required void Function(double lat, double lng, double zoom) onViewportChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Viewport',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
      const SizedBox(height: 8),
      SwitchListTile(
        title: const Text('Remember Viewport'),
        subtitle: const Text('Resume from last viewed position'),
        value: rememberViewport,
        onChanged: onRememberViewportChanged,
        secondary: Icon(
          rememberViewport ? Icons.restore : Icons.home,
          color: rememberViewport ? Colors.blue : Colors.grey,
        ),
      ),
      if (!rememberViewport) ...[
        const SizedBox(height: 12),
        InitialViewportSelector(
          lat: initialLat,
          lng: initialLng,
          zoom: initialZoom,
          onChanged: onViewportChanged,
        ),
      ],
    ],
  );
}

/// Builds the map source selection section.
Widget buildMapSourceSection({
  required MapSource mapSource,
  required void Function(MapSource) onMapSourceChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Map Source',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButton<MapSource>(
          value: mapSource,
          isExpanded: true,
          underline: const SizedBox(),
          icon: const Icon(Icons.arrow_drop_down),
          items: MapSource.values.map((source) {
            return DropdownMenuItem<MapSource>(
              value: source,
              child: Row(
                children: [
                  Icon(source.icon, size: 20, color: Colors.grey.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          source.displayName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          source.description,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (MapSource? newValue) {
            if (newValue != null) {
              onMapSourceChanged(newValue);
            }
          },
        ),
      ),
    ],
  );
}

/// Builds the marker colors section.
Widget buildMarkerColorsSection({
  required BuildContext context,
  required Color userPlacesColor,
  required Color localPlacesColor,
  required void Function(Color) onUserColorChanged,
  required void Function(Color) onLocalColorChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Marker Colors',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
      const SizedBox(height: 12),
      ColorPickerTile(
        label: 'My Places',
        subtitle: 'Your saved locations',
        color: userPlacesColor,
        onTap: () => showColorPickerDialog(
          context: context,
          title: 'My Places Color',
          currentColor: userPlacesColor,
          onColorChanged: onUserColorChanged,
        ),
      ),
      const SizedBox(height: 12),
      ColorPickerTile(
        label: 'Example Places',
        subtitle: 'Canned example locations',
        color: localPlacesColor,
        onTap: () => showColorPickerDialog(
          context: context,
          title: 'Example Places Color',
          currentColor: localPlacesColor,
          onColorChanged: onLocalColorChanged,
        ),
      ),
    ],
  );
}
