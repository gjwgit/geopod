/// Dialog for configuring map display settings.
///
// Time-stamp: <2026-01-07 Miduo>
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

import 'package:solidpod/solidpod.dart' show authStateNotifier;

import 'package:geopod/services/map_settings_service.dart';
import 'package:geopod/services/places/encrypted_places_service.dart';
import 'package:geopod/widgets/settings/settings_actions.dart';
import 'package:geopod/widgets/settings/settings_sections.dart';

/// Dialog for configuring map display settings.
///
/// Allows users to:
/// - Toggle visibility of local (canned) example places
/// - Customize colors for user places and example places
/// - Select map source
/// - Configure viewport settings.

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
  late bool _showEncryptedPlaces;
  late bool _hideAllMarkers;
  late Color _userPlacesColor;
  late Color _localPlacesColor;
  late Color _encryptedPlacesColor;
  late MapSource _mapSource;
  late bool _rememberViewport;
  late double _initialLat;
  late double _initialLng;
  late double _initialZoom;
  bool _isLoadingEncrypted = false;

  // Snapshot of initial settings to detect actual changes.

  late MapSettings _initialSnapshot;

  @override
  void initState() {
    super.initState();
    _initialSnapshot = widget.currentSettings;
    _showLocalPlaces = widget.currentSettings.showLocalPlaces;
    _showEncryptedPlaces = widget.currentSettings.showEncryptedPlaces;
    _hideAllMarkers = widget.currentSettings.hideAllMarkers;
    _userPlacesColor = widget.currentSettings.userPlacesColor;
    _localPlacesColor = widget.currentSettings.localPlacesColor;
    _encryptedPlacesColor = widget.currentSettings.encryptedPlacesColor;
    _mapSource = widget.currentSettings.mapSource;
    _rememberViewport = widget.currentSettings.rememberViewport;
    _initialLat = widget.currentSettings.initialLat;
    _initialLng = widget.currentSettings.initialLng;
    _initialZoom = widget.currentSettings.initialZoom;
  }

  /// Check if current settings differ from initial snapshot.

  bool _hasActualChanges() {
    return _showLocalPlaces != _initialSnapshot.showLocalPlaces ||
        _showEncryptedPlaces != _initialSnapshot.showEncryptedPlaces ||
        _hideAllMarkers != _initialSnapshot.hideAllMarkers ||
        _userPlacesColor != _initialSnapshot.userPlacesColor ||
        _localPlacesColor != _initialSnapshot.localPlacesColor ||
        _encryptedPlacesColor != _initialSnapshot.encryptedPlacesColor ||
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
      showEncryptedPlaces: _showEncryptedPlaces,
      hideAllMarkers: _hideAllMarkers,
      userPlacesColor: _userPlacesColor,
      localPlacesColor: _localPlacesColor,
      encryptedPlacesColor: _encryptedPlacesColor,
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

  /// Resets all settings to defaults.

  void _resetToDefaults() {
    setState(() {
      _showLocalPlaces = true;
      _showEncryptedPlaces = false;
      _hideAllMarkers = false;
      _userPlacesColor = defaultUserColor;
      _localPlacesColor = defaultLocalColor;
      _encryptedPlacesColor = defaultEncryptedColor;
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
    // Use responsive width: larger on desktop/tablet, adapt on mobile.
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
              // Visibility section.
              buildVisibilitySection(
                showLocalPlaces: _showLocalPlaces,
                showEncryptedPlaces: _showEncryptedPlaces,
                hideAllMarkers: _hideAllMarkers,
                isLoadingEncrypted: _isLoadingEncrypted,
                isLoggedIn: authStateNotifier.value,
                onShowLocalChanged: (value) {
                  setState(() => _showLocalPlaces = value);
                  _saveAndNotify();
                },
                onShowEncryptedChanged: (value) async {
                  if (value) {
                    // Enabling encrypted places - verify security key first.
                    setState(() => _isLoadingEncrypted = true);

                    // Check if security key is available, prompt if not.
                    final hasKey =
                        await EncryptedPlacesService.ensureSecurityKey(
                          context,
                          widget,
                        );

                    if (!mounted) return;

                    if (hasKey) {
                      // Security key verified, enable the setting.
                      setState(() {
                        _showEncryptedPlaces = true;
                        _isLoadingEncrypted = false;
                      });
                      _saveAndNotify();
                    } else {
                      // User cancelled or key verification failed.
                      setState(() => _isLoadingEncrypted = false);

                      // Don't change _showEncryptedPlaces - it stays false.
                    }
                  } else {
                    // Disabling encrypted places - no verification needed.
                    setState(() => _showEncryptedPlaces = false);
                    _saveAndNotify();
                  }
                },
                onHideAllMarkersChanged: (value) {
                  setState(() => _hideAllMarkers = value);
                  _saveAndNotify();
                },
              ),
              const Divider(height: 24),

              // Viewport section.

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

              // Map source section.

              buildMapSourceSection(
                mapSource: _mapSource,
                onMapSourceChanged: (source) {
                  setState(() => _mapSource = source);
                  _saveAndNotify();
                },
              ),
              const SizedBox(height: 12),
              const Divider(height: 24),

              // Marker colors section.

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

              // Reset button.

              buildResetButton(onReset: _resetToDefaults),
              const SizedBox(height: 12),

              // User actions (logout, debug buttons)

              buildUserActionsSection(context),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);

            // Only sync to POD if there were actual changes.

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
