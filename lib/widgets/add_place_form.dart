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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:geopod/services/places_service.dart';

/// A form widget that allows users to add a new place with coordinates and
/// a note, then save it to their Solid Pod.
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

  bool _isLoading = false;

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
  }

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    _noteController.dispose();
    super.dispose();
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

  /// Saves the place data to the user's Solid Pod.
  Future<void> _saveToPod() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create the place object.
      final timestamp = DateTime.now().toUtc().toIso8601String();
      final place = Place(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        lat: double.parse(_latitudeController.text.trim()),
        lng: double.parse(_longitudeController.text.trim()),
        note: _noteController.text.trim(),
        timestamp: timestamp,
      );

      // Add the place using PlacesService (handles read-append-write).
      // ignore: use_build_context_synchronously
      final success = await PlacesService.addPlace(
        place,
        context,
        widget.returnWidget,
      );

      if (success) {
        // Success - close the dialog and show success message.
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(child: Text('Place saved successfully!')),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } else {
        throw Exception('Failed to save place');
      }
    } catch (e) {
      // Error - show error message.
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to save: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
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
                  enabled: !_isLoading,
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
                  enabled: !_isLoading,
                ),
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
                  enabled: !_isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _saveToPod,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_upload),
          label: Text(_isLoading ? 'Saving...' : 'Save to Pod'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
