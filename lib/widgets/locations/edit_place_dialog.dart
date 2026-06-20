/// Dialog for editing a place's title, note, and coordinates.
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

import 'package:flutter/material.dart';

import 'package:emacs_text_field/emacs_text_field.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:gap/gap.dart';

import 'package:geopod/models/place.dart';
import 'package:geopod/services/geocoding_service.dart';

/// Dialog for editing a place's title, note, and coordinates.

class EditPlaceDialog extends StatefulWidget {
  const EditPlaceDialog({super.key, required this.place});

  final Place place;

  @override
  State<EditPlaceDialog> createState() => _EditPlaceDialogState();
}

class _EditPlaceDialogState extends State<EditPlaceDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _noteController;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _showPreview = false;
  String? _previewAddress;

  late final String _initTitle;
  late final String _initLat;
  late final String _initLng;
  late final String _initNote;
  String? _initAddress;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.place.title);
    _latController = TextEditingController(
      text: widget.place.lat.toStringAsFixed(6),
    );
    _lngController = TextEditingController(
      text: widget.place.lng.toStringAsFixed(6),
    );
    _noteController = TextEditingController(text: widget.place.note);
    _previewAddress = widget.place.address;
    _initTitle = _titleController.text;
    _initLat = _latController.text;
    _initLng = _lngController.text;
    _initNote = _noteController.text;
    _initAddress = _previewAddress;
    for (final c in [
      _titleController,
      _latController,
      _lngController,
      _noteController,
    ]) {
      c.addListener(_onChanged);
    }
  }

  void _onChanged() => setState(() {});

  bool get _hasChanges =>
      _titleController.text != _initTitle ||
      _latController.text != _initLat ||
      _lngController.text != _initLng ||
      _noteController.text != _initNote ||
      _previewAddress != _initAddress;

  @override
  void dispose() {
    for (final c in [
      _titleController,
      _latController,
      _lngController,
      _noteController,
    ]) {
      c.removeListener(_onChanged);
      c.dispose();
    }
    super.dispose();
  }

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
    Navigator.pop(
      context,
      widget.place.copyWith(
        title: _titleController.text.trim(),
        lat: lat,
        lng: lng,
        note: _noteController.text,
        timestamp: DateTime.now().toIso8601String(),
        address: widget.place.address,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.edit, color: Colors.blue),
          Gap(8),
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
                // Title.
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

                // Note — editor / preview toggle.
                Row(
                  children: [
                    Text(
                      'Notes',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _showPreview = !_showPreview),
                      icon: Icon(
                        _showPreview ? Icons.edit : Icons.preview,
                        size: 16,
                      ),
                      label: Text(_showPreview ? 'Edit' : 'Preview'),
                    ),
                  ],
                ),
                const Gap(4),
                _showPreview
                    ? Container(
                        height: 200,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: _noteController.text.isEmpty
                            ? Text(
                                'No notes yet.',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontStyle: FontStyle.italic,
                                ),
                              )
                            : Markdown(
                                data: _noteController.text,
                                shrinkWrap: true,
                              ),
                      )
                    : SizedBox(
                        height: 200,
                        child: EmacsTextField(
                          controller: _noteController,
                          expands: true,
                          decoration: const InputDecoration(
                            hintText: 'Markdown notes about this place…',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                const Gap(16),

                // Coordinates.
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
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          final lat = double.tryParse(v);
                          if (lat == null || lat < -90 || lat > 90) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const Gap(12),
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
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          final lng = double.tryParse(v);
                          if (lng == null || lng < -180 || lng > 180) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const Gap(12),
                    IconButton.outlined(
                      onPressed: _isLoading
                          ? null
                          : _previewAddressForCoordinates,
                      tooltip: 'Preview address',
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
                const Gap(12),

                // Address preview.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.home_outlined,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const Gap(8),
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
                const Gap(8),
                Text(
                  'Address updates automatically when coordinates change.',
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
