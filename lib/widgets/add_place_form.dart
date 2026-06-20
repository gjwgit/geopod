/// Form widget for adding a new place to the user's Solid Pod.
///
// Time-stamp: <2026-06-20 Graham Williams>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.
///
/// Authors: Graham Williams, Miduo

library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:emacs_text_field/emacs_text_field.dart';
import 'package:gap/gap.dart';

import 'package:geopod/services/geocoding_service.dart';
import 'package:geopod/services/places_service.dart';
import 'package:geopod/utils/ui_utils.dart';
import 'package:geopod/utils/widget_utils.dart';
import 'package:geopod/widgets/weather_dialog.dart';

/// Result returned from AddPlaceForm containing the place data.

class AddPlaceResult {
  final Place place;
  final bool encrypted;

  AddPlaceResult({required this.place, this.encrypted = false});
}

/// Form for adding a new place. Returns immediately (optimistic) with a Place
/// that has a placeholder address; the caller geocodes in the background.

class AddPlaceForm extends StatefulWidget {
  const AddPlaceForm({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    required this.returnWidget,
  });

  final double? initialLatitude;
  final double? initialLongitude;
  final Widget returnWidget;

  @override
  State<AddPlaceForm> createState() => _AddPlaceFormState();
}

class _AddPlaceFormState extends State<AddPlaceForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _noteController = TextEditingController();

  String? _addressPreview;
  bool _isLoadingAddress = false;
  Timer? _debounceTimer;

  // All places are stored encrypted; there is no opt-out.
  static const bool _encrypt = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null) {
      _latitudeController.text = widget.initialLatitude!.toStringAsFixed(6);
    }
    if (widget.initialLongitude != null) {
      _longitudeController.text = widget.initialLongitude!.toStringAsFixed(6);
    }
    _latitudeController.addListener(_onCoordinateChanged);
    _longitudeController.addListener(_onCoordinateChanged);
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _loadAddressPreview();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _titleController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onCoordinateChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(milliseconds: 800),
      _loadAddressPreview,
    );
  }

  Future<void> _loadAddressPreview() async {
    final lat = double.tryParse(_latitudeController.text.trim());
    final lng = double.tryParse(_longitudeController.text.trim());
    if (lat == null ||
        lng == null ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180) {
      setState(() {
        _addressPreview = null;
        _isLoadingAddress = false;
      });
      return;
    }
    setState(() {
      _isLoadingAddress = true;
      _addressPreview = null;
    });
    try {
      final address = await GeocodingService.getAddress(lat, lng);
      safeSetState(this, () {
        _addressPreview = address;
        _isLoadingAddress = false;
      });
    } catch (e) {
      safeSetState(this, () {
        _addressPreview = 'Failed to load address';
        _isLoadingAddress = false;
      });
    }
  }

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

  void _handleSave() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final lat = double.parse(_latitudeController.text.trim());
    final lng = double.parse(_longitudeController.text.trim());
    final place = Place(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      lat: lat,
      lng: lng,
      title: _titleController.text.trim(),
      note: _noteController.text,
      timestamp: DateTime.now().toUtc().toIso8601String(),
      address: 'Loading address...',
    );
    Navigator.pop(context, AddPlaceResult(place: place, encrypted: _encrypt));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.add_location_alt, color: Colors.green),
          const Gap(12),
          const Text('Add New Place'),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.wb_sunny_outlined),
            onPressed: () {
              final lat = double.tryParse(_latitudeController.text.trim());
              final lng = double.tryParse(_longitudeController.text.trim());
              if (lat != null && lng != null) {
                showWeatherDialog(
                  context: context,
                  latitude: lat,
                  longitude: lng,
                  address: _addressPreview,
                );
              } else {
                SnackBarHelper.showWarning(
                  context,
                  'Please enter valid coordinates to view weather',
                  duration: const Duration(seconds: 2),
                );
              }
            },
            tooltip: 'View Weather',
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title field.
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'Short name for this place',
                    prefixIcon: Icon(Icons.label_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Title is required'
                      : null,
                ),
                const Gap(16),

                // Coordinates.
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
                const Gap(16),
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

                // Address preview.
                if (_isLoadingAddress || _addressPreview != null) ...[
                  const Gap(16),
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
                        const Gap(8),
                        Expanded(
                          child: _isLoadingAddress
                              ? Row(
                                  children: [
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                    const Gap(8),
                                    const Text(
                                      'Loading address…',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ],
                                )
                              : Text(
                                  _addressPreview!,
                                  style: const TextStyle(fontSize: 13),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Notes field (EmacsTextField, markdown).
                const Gap(16),
                SizedBox(
                  height: 160,
                  child: EmacsTextField(
                    controller: _noteController,
                    expands: true,
                    decoration: const InputDecoration(
                      labelText: 'Notes (markdown)',
                      hintText: 'Describe this place…',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
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
