/// Form widget for adding a new place to the user's Solid Pod.
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:geopod/services/geocoding_service.dart';
import 'package:geopod/services/places_service_v2.dart';

/// Result returned from AddPlaceForm containing the place data.
/// Used for optimistic updates - the Place is returned immediately
/// before the save completes.
class AddPlaceResult {
  final Place place;

  AddPlaceResult({required this.place});
}

/// A form widget that allows users to add a new place with coordinates and
/// a note. Returns immediately with optimistic data for instant UI updates.
class AddPlaceForm extends StatefulWidget {
  const AddPlaceForm({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    required this.returnWidget,
  });

  /// Optional initial latitude value (e.g., from map tap).
  final double? initialLatitude;

  /// Optional initial longitude value (e.g., from map tap).
  final double? initialLongitude;

  /// The widget to return to after the write operation.
  final Widget returnWidget;

  @override
  State<AddPlaceForm> createState() => _AddPlaceFormState();
}

class _AddPlaceFormState extends State<AddPlaceForm> {
  final _formKey = GlobalKey<FormState>();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _noteController = TextEditingController();

  String? _addressPreview;
  bool _isLoadingAddress = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    // Pre-fill coordinates if provided.
    if (widget.initialLatitude != null) {
      _latitudeController.text = widget.initialLatitude!.toStringAsFixed(6);
    }
    if (widget.initialLongitude != null) {
      _longitudeController.text = widget.initialLongitude!.toStringAsFixed(6);
    }

    // Listen to coordinate changes for live preview
    _latitudeController.addListener(_onCoordinateChanged);
    _longitudeController.addListener(_onCoordinateChanged);

    // Load initial address preview if coordinates provided
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _loadAddressPreview();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Called when coordinates change - triggers debounced address lookup
  void _onCoordinateChanged() {
    // Cancel previous timer
    _debounceTimer?.cancel();

    // Start new timer (wait 800ms after user stops typing)
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      _loadAddressPreview();
    });
  }

  /// Loads address preview from coordinates
  Future<void> _loadAddressPreview() async {
    final latText = _latitudeController.text.trim();
    final lngText = _longitudeController.text.trim();

    // Validate coordinates
    final lat = double.tryParse(latText);
    final lng = double.tryParse(lngText);

    if (lat == null || lng == null) {
      setState(() {
        _addressPreview = null;
        _isLoadingAddress = false;
      });
      return;
    }

    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      setState(() {
        _addressPreview = null;
        _isLoadingAddress = false;
      });
      return;
    }

    // Show loading state
    setState(() {
      _isLoadingAddress = true;
      _addressPreview = null;
    });

    try {
      // Call geocoding API
      final address = await GeocodingService.getAddress(lat, lng);

      if (mounted) {
        setState(() {
          _addressPreview = address;
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _addressPreview = 'Failed to load address';
          _isLoadingAddress = false;
        });
      }
    }
  }

  /// Validates that the input is a valid latitude (-90 to 90).
  String? _validateLatitude(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Latitude is required';
    }
    final lat = double.tryParse(value.trim());
    if (lat == null) {
      return 'Enter a valid number';
    }
    if (lat < -90 || lat > 90) {
      return 'Latitude must be between -90 and 90';
    }
    return null;
  }

  /// Validates that the input is a valid longitude (-180 to 180).
  String? _validateLongitude(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Longitude is required';
    }
    final lng = double.tryParse(value.trim());
    if (lng == null) {
      return 'Enter a valid number';
    }
    if (lng < -180 || lng > 180) {
      return 'Longitude must be between -180 and 180';
    }
    return null;
  }

  /// Validates that the note is not empty.
  String? _validateNote(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Note is required';
    }
    return null;
  }

  /// INSTANT SAVE: Returns immediately with optimistic Place data.
  /// The actual save (geocoding + writePod) happens in the parent widget.
  void _handleSave() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final lat = double.parse(_latitudeController.text.trim());
    final lng = double.parse(_longitudeController.text.trim());

    // Create optimistic Place with "Loading..." address.
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final place = Place(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      lat: lat,
      lng: lng,
      note: _noteController.text.trim(),
      timestamp: timestamp,
      address: 'Loading address...', // Placeholder - updated after geocoding.
    );

    // INSTANT: Close dialog and return Place for optimistic update.
    Navigator.pop(context, AddPlaceResult(place: place));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.add_location_alt, color: Colors.green),
          SizedBox(width: 12),
          Text('Add New Place'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Latitude field.
                TextFormField(
                  controller: _latitudeController,
                  decoration: const InputDecoration(
                    labelText: 'Latitude',
                    hintText: 'e.g., -12.4634',
                    prefixIcon: Icon(Icons.north),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
                  ],
                  validator: _validateLatitude,
                ),
                const SizedBox(height: 16),

                // Longitude field.
                TextFormField(
                  controller: _longitudeController,
                  decoration: const InputDecoration(
                    labelText: 'Longitude',
                    hintText: 'e.g., 130.8456',
                    prefixIcon: Icon(Icons.east),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
                  ],
                  validator: _validateLongitude,
                ),
                const SizedBox(height: 16),

                // Address preview
                if (_isLoadingAddress || _addressPreview != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 20,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Address Preview',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (_isLoadingAddress)
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Loading address...',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ],
                                )
                              else if (_addressPreview != null)
                                Text(
                                  _addressPreview!,
                                  style: const TextStyle(fontSize: 13),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_isLoadingAddress || _addressPreview != null)
                  const SizedBox(height: 16),

                // Note field.
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                    hintText: 'Describe this place...',
                    prefixIcon: Icon(Icons.notes),
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                  validator: _validateNote,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _handleSave,
          icon: const Icon(Icons.add),
          label: const Text('Add Place'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
