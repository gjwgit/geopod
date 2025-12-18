/// Dialog for configuring map display settings.
///
// Time-stamp: <2025-12-05 Miduo>
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

import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:solidpod/solidpod.dart';
import 'package:solidui/solidui.dart';

import 'package:geopod/services/map_settings_service.dart';

/// Dialog for configuring map display settings.
///
/// Allows users to:
/// - Toggle visibility of local (canned) example places
/// - Customize colors for user places and example places
class MapSettingsDialog extends StatefulWidget {
  const MapSettingsDialog({
    super.key,
    required this.currentSettings,
    required this.onSettingsChanged,
  });

  /// Current settings to display.
  final MapSettings currentSettings;

  /// Callback when settings are changed.
  final void Function(MapSettings) onSettingsChanged;

  @override
  State<MapSettingsDialog> createState() => _MapSettingsDialogState();
}

class _MapSettingsDialogState extends State<MapSettingsDialog> {
  late bool _showLocalPlaces;
  late Color _userPlacesColor;
  late Color _localPlacesColor;
  late MapSource _mapSource;
  late bool _rememberViewport;
  late double _initialLat;
  late double _initialLng;
  late double _initialZoom;

  @override
  void initState() {
    super.initState();
    _showLocalPlaces = widget.currentSettings.showLocalPlaces;
    _userPlacesColor = widget.currentSettings.userPlacesColor;
    _localPlacesColor = widget.currentSettings.localPlacesColor;
    _mapSource = widget.currentSettings.mapSource;
    _rememberViewport = widget.currentSettings.rememberViewport;
    _initialLat = widget.currentSettings.initialLat;
    _initialLng = widget.currentSettings.initialLng;
    _initialZoom = widget.currentSettings.initialZoom;
  }

  /// Saves current settings and notifies parent.
  void _saveAndNotify() {
    final newSettings = MapSettings(
      showLocalPlaces: _showLocalPlaces,
      userPlacesColor: _userPlacesColor,
      localPlacesColor: _localPlacesColor,
      mapSource: _mapSource,
      rememberViewport: _rememberViewport,
      initialLat: _initialLat,
      initialLng: _initialLng,
      initialZoom: _initialZoom,
    );

    // Save to SharedPreferences.
    MapSettingsService.saveSettings(newSettings);

    // Notify parent widget.
    widget.onSettingsChanged(newSettings);
  }

  /// Shows color picker dialog for selecting a color.
  Future<void> _showColorPicker({
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

  /// Resets all settings to defaults.
  void _resetToDefaults() {
    setState(() {
      _showLocalPlaces = true;
      _userPlacesColor = defaultUserColor;
      _localPlacesColor = defaultLocalColor;
      _mapSource = MapSettings.getDefaultMapSource();
      _rememberViewport = true;
      _initialLat = defaultInitialLat;
      _initialLng = defaultInitialLng;
      _initialZoom = defaultInitialZoom;
    });
    _saveAndNotify();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.settings, color: Colors.grey),
          SizedBox(width: 12),
          Text('Map Settings'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Visibility toggle.
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
              value: _showLocalPlaces,
              onChanged: (value) {
                setState(() => _showLocalPlaces = value);
                _saveAndNotify();
              },
              secondary: Icon(
                _showLocalPlaces ? Icons.visibility : Icons.visibility_off,
                color: _showLocalPlaces ? Colors.green : Colors.grey,
              ),
            ),
            const Divider(height: 32),

            // Viewport Settings
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
              value: _rememberViewport,
              onChanged: (value) {
                setState(() => _rememberViewport = value);
                _saveAndNotify();
              },
              secondary: Icon(
                _rememberViewport ? Icons.restore : Icons.home,
                color: _rememberViewport ? Colors.blue : Colors.grey,
              ),
            ),
            if (!_rememberViewport) ...[
              const SizedBox(height: 12),
              _InitialViewportSelector(
                lat: _initialLat,
                lng: _initialLng,
                zoom: _initialZoom,
                onChanged: (lat, lng, zoom) {
                  setState(() {
                    _initialLat = lat;
                    _initialLng = lng;
                    _initialZoom = zoom;
                  });
                  _saveAndNotify();
                },
              ),
            ],
            const Divider(height: 32),

            // Map Source Selection
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
                value: _mapSource,
                isExpanded: true,
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down),
                items: MapSource.values.map((source) {
                  return DropdownMenuItem<MapSource>(
                    value: source,
                    child: Row(
                      children: [
                        Icon(
                          source.icon,
                          size: 20,
                          color: Colors.grey.shade700,
                        ),
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
                    setState(() => _mapSource = newValue);
                    _saveAndNotify();
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 32),

            // Color customization.
            const Text(
              'Marker Colors',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),

            // User places color.
            _ColorPickerTile(
              label: 'My Places',
              subtitle: 'Your saved locations',
              color: _userPlacesColor,
              onTap: () => _showColorPicker(
                title: 'My Places Color',
                currentColor: _userPlacesColor,
                onColorChanged: (color) {
                  setState(() => _userPlacesColor = color);
                  _saveAndNotify();
                },
              ),
            ),
            const SizedBox(height: 12),

            // Local places color.
            _ColorPickerTile(
              label: 'Example Places',
              subtitle: 'Canned example locations',
              color: _localPlacesColor,
              onTap: () => _showColorPicker(
                title: 'Example Places Color',
                currentColor: _localPlacesColor,
                onColorChanged: (color) {
                  setState(() => _localPlacesColor = color);
                  _saveAndNotify();
                },
              ),
            ),
            const SizedBox(height: 24),

            // Reset button.
            Center(
              child: TextButton.icon(
                onPressed: _resetToDefaults,
                icon: const Icon(Icons.restore, size: 18),
                label: const Text('Reset to Defaults'),
                style: TextButton.styleFrom(foregroundColor: Colors.grey),
              ),
            ),

            const SizedBox(height: 12),

            // Logout button - only show if user is logged in
            FutureBuilder<String?>(
              future: getWebId(),
              builder: (context, snapshot) {
                final isLoggedIn =
                    snapshot.data != null && snapshot.data!.isNotEmpty;
                if (!isLoggedIn) return const SizedBox.shrink();

                return Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      // Close settings dialog first
                      Navigator.pop(context);
                      // Then handle logout
                      await SolidAuthHandler.instance.handleLogout(context);
                    },
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Logout'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade400,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

/// A tile widget for displaying and selecting a color.
class _ColorPickerTile extends StatelessWidget {
  const _ColorPickerTile({
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Color preview.
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.location_on,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // Label and subtitle.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            // Edit icon.
            Icon(Icons.edit, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}

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
class _InitialViewportSelector extends StatelessWidget {
  const _InitialViewportSelector({
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
