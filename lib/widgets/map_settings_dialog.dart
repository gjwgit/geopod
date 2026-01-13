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

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:solidpod/solidpod.dart';
import 'package:solidui/solidui.dart';

import 'package:geopod/services/map_settings_service.dart';
import 'package:geopod/widgets/settings/color_picker_tile.dart';
import 'package:geopod/widgets/settings/viewport_selector.dart';

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

  // Snapshot of initial settings to detect actual changes
  late MapSettings _initialSnapshot;

  @override
  void initState() {
    super.initState();
    _initialSnapshot = widget.currentSettings;
    _showLocalPlaces = widget.currentSettings.showLocalPlaces;
    _userPlacesColor = widget.currentSettings.userPlacesColor;
    _localPlacesColor = widget.currentSettings.localPlacesColor;
    _mapSource = widget.currentSettings.mapSource;
    _rememberViewport = widget.currentSettings.rememberViewport;
    _initialLat = widget.currentSettings.initialLat;
    _initialLng = widget.currentSettings.initialLng;
    _initialZoom = widget.currentSettings.initialZoom;
  }

  /// Check if current settings differ from initial snapshot.
  bool _hasActualChanges() {
    return _showLocalPlaces != _initialSnapshot.showLocalPlaces ||
        _userPlacesColor != _initialSnapshot.userPlacesColor ||
        _localPlacesColor != _initialSnapshot.localPlacesColor ||
        _mapSource != _initialSnapshot.mapSource ||
        _rememberViewport != _initialSnapshot.rememberViewport ||
        _initialLat != _initialSnapshot.initialLat ||
        _initialLng != _initialSnapshot.initialLng ||
        _initialZoom != _initialSnapshot.initialZoom;
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
    // Use responsive width: larger on desktop/tablet, adapt on mobile
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth < 400 ? screenWidth * 0.9 : 380.0;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.settings, color: Colors.grey),
          SizedBox(width: 12),
          Text('Map Settings'),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
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
              const Divider(height: 24),

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
                InitialViewportSelector(
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
              const Divider(height: 24),

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
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
              const SizedBox(height: 12),
              const Divider(height: 24),

              // Color customization.
              const Text(
                'Marker Colors',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),

              // User places color.
              ColorPickerTile(
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
              ColorPickerTile(
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
              const SizedBox(height: 20),

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
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            // Only sync to POD if there were actual changes
            if (_hasActualChanges()) {
              unawaited(MapSettingsService.syncToPod());
            }
          },
          child: const Text('Done'),
        ),
      ],
    );
  }
}
