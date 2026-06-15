/// Dialog for editing a place's lat, lng, and note.
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

import 'package:emacs_text_field/emacs_text_field.dart';

import 'package:geopod/models/place.dart';
import 'package:geopod/services/geocoding_service.dart';

/// Dialog for editing a place's lat, lng, and note.

class EditPlaceDialog extends StatefulWidget {
  const EditPlaceDialog({super.key, required this.place});

  final Place place;

  @override
  State<EditPlaceDialog> createState() => _EditPlaceDialogState();
}

class _EditPlaceDialogState extends State<EditPlaceDialog> {
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _noteController;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _previewAddress;

  // Snapshot of the initial field values for change detection. The Save button
  // is enabled only once the user has actually modified something.
  late final String _initLat;
  late final String _initLng;
  late final String _initNote;
  String? _initAddress;

  @override
  void initState() {
    super.initState();
    _latController = TextEditingController(
      text: widget.place.lat.toStringAsFixed(6),
    );
    _lngController = TextEditingController(
      text: widget.place.lng.toStringAsFixed(6),
    );
    _noteController = TextEditingController(text: widget.place.note);
    _previewAddress = widget.place.address;

    // Record the initial state, then rebuild on any text edit so the Save
    // button updates live. The address-preview action calls setState itself.
    _initLat = _latController.text;
    _initLng = _lngController.text;
    _initNote = _noteController.text;
    _initAddress = _previewAddress;
    for (final c in [_latController, _lngController, _noteController]) {
      c.addListener(_onChanged);
    }
  }

  void _onChanged() => setState(() {});

  /// Whether any editable field differs from its initial value.
  bool get _hasChanges =>
      _latController.text != _initLat ||
      _lngController.text != _initLng ||
      _noteController.text != _initNote ||
      _previewAddress != _initAddress;

  @override
  void dispose() {
    for (final c in [_latController, _lngController, _noteController]) {
      c.removeListener(_onChanged);
    }
    _latController.dispose();
    _lngController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Previews the address for current coordinates.

  Future<void> _previewAddressForCoordinates() async {
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);

    if (lat == null || lng == null) return;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return;

    setState(() => _isLoading = true);

    final address = await GeocodingService.getAddress(lat, lng);

    if (mounted) {
      setState(() {
        _previewAddress = address;
        _isLoading = false;
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);

    if (lat == null || lng == null) return;

    final updatedPlace = Place(
      id: widget.place.id,
      lat: lat,
      lng: lng,
      note: _noteController.text.trim(),
      timestamp: DateTime.now()
          .toIso8601String(), // Update timestamp when editing
      address: widget
          .place
          .address, // Address will be updated by service if coords changed.
      isLocal: false,
      isEncrypted: widget.place.isEncrypted, // Preserve encryption status.
    );

    Navigator.pop(context, updatedPlace);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.edit, color: Colors.blue),
          SizedBox(width: 8),
          Expanded(child: Text('Edit Place')),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Note is the primary field, so give it plenty of room. A
                // fixed-height box with expands:true makes the editor large and
                // stable (EmacsTextField has no maxLines parameter).
                SizedBox(
                  height: 260,
                  child: EmacsTextField(
                    controller: _noteController,
                    expands: true,
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      hintText: 'Enter a description',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Coordinates: compact two-up row.
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latController,
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          hintText: '-90 to 90',
                          prefixIcon: Icon(Icons.north),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final lat = double.tryParse(value);
                          if (lat == null || lat < -90 || lat > 90) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lngController,
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          hintText: '-180 to 180',
                          prefixIcon: Icon(Icons.east),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final lng = double.tryParse(value);
                          if (lng == null || lng < -180 || lng > 180) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Preview address as a compact icon button beside coords.
                    IconButton.outlined(
                      onPressed: _isLoading
                          ? null
                          : _previewAddressForCoordinates,
                      tooltip: 'Preview address for these coordinates',
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.location_searching, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Address preview (compact single row).
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.home_outlined,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _previewAddress ?? 'Address not available',
                        style: TextStyle(
                          fontSize: 13,
                          color: _previewAddress != null
                              ? Colors.black87
                              : Colors.grey.shade500,
                          fontStyle: _previewAddress != null
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'The address is updated automatically on save if the '
                  'coordinates change.',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade600,
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
          onPressed: (_isLoading || !_hasChanges) ? null : _save,
          icon: const Icon(Icons.save, size: 18),
          label: const Text('Save'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
