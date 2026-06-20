/// Dialog for configuring map display settings.
///
// Time-stamp: <2026-01-07 Miduo>
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

import 'package:geopod/services/map_settings_service.dart';
import 'package:geopod/widgets/settings/settings_actions.dart';
import 'package:geopod/widgets/settings/settings_sections.dart';

/// Dialog for configuring map display settings.

class MapSettingsDialog extends StatefulWidget {
  const MapSettingsDialog({
    super.key,
    required this.currentSettings,
    required this.onSettingsChanged,
  });

  final MapSettings currentSettings;
  final void Function(MapSettings) onSettingsChanged;

  @override
  State<MapSettingsDialog> createState() => _MapSettingsDialogState();
}

class _MapSettingsDialogState extends State<MapSettingsDialog> {
  late bool _showLocalPlaces;
  late bool _hideAllMarkers;
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
    _hideAllMarkers = widget.currentSettings.hideAllMarkers;
    _userPlacesColor = widget.currentSettings.userPlacesColor;
    _localPlacesColor = widget.currentSettings.localPlacesColor;
    _mapSource = widget.currentSettings.mapSource;
    _rememberViewport = widget.currentSettings.rememberViewport;
    _initialLat = widget.currentSettings.initialLat;
    _initialLng = widget.currentSettings.initialLng;
    _initialZoom = widget.currentSettings.initialZoom;
  }

  void _saveAndNotify() {
    final newSettings = MapSettings(
      showLocalPlaces: _showLocalPlaces,
      hideAllMarkers: _hideAllMarkers,
      userPlacesColor: _userPlacesColor,
      localPlacesColor: _localPlacesColor,
      mapSource: _mapSource,
      rememberViewport: _rememberViewport,
      initialLat: _initialLat,
      initialLng: _initialLng,
      initialZoom: _initialZoom,
    );
    MapSettingsService.saveSettings(newSettings);
    widget.onSettingsChanged(newSettings);
  }

  void _resetToDefaults() {
    setState(() {
      _showLocalPlaces = true;
      _hideAllMarkers = false;
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
              buildVisibilitySection(
                showLocalPlaces: _showLocalPlaces,
                hideAllMarkers: _hideAllMarkers,
                onShowLocalChanged: (value) {
                  setState(() => _showLocalPlaces = value);
                  _saveAndNotify();
                },
                onHideAllMarkersChanged: (value) {
                  setState(() => _hideAllMarkers = value);
                  _saveAndNotify();
                },
              ),
              const Divider(height: 24),
              buildViewportSection(
                rememberViewport: _rememberViewport,
                initialLat: _initialLat,
                initialLng: _initialLng,
                initialZoom: _initialZoom,
                onRememberViewportChanged: (value) {
                  setState(() => _rememberViewport = value);
                  _saveAndNotify();
                },
                onViewportChanged: (lat, lng, zoom) {
                  setState(() {
                    _initialLat = lat;
                    _initialLng = lng;
                    _initialZoom = zoom;
                  });
                  _saveAndNotify();
                },
              ),
              const Divider(height: 24),
              buildMapSourceSection(
                mapSource: _mapSource,
                onMapSourceChanged: (source) {
                  setState(() => _mapSource = source);
                  _saveAndNotify();
                },
              ),
              const SizedBox(height: 12),
              const Divider(height: 24),
              buildMarkerColorsSection(
                context: context,
                userPlacesColor: _userPlacesColor,
                localPlacesColor: _localPlacesColor,
                onUserColorChanged: (color) {
                  setState(() => _userPlacesColor = color);
                  _saveAndNotify();
                },
                onLocalColorChanged: (color) {
                  setState(() => _localPlacesColor = color);
                  _saveAndNotify();
                },
              ),
              const SizedBox(height: 20),
              buildResetButton(onReset: _resetToDefaults),
              const SizedBox(height: 12),
              buildUserActionsSection(context),
            ],
          ),
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
