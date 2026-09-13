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
import 'package:solidui/solidui.dart';

import 'package:geopod/constants/place_tags.dart';
import 'package:geopod/services/geocoding_service.dart';
import 'package:geopod/services/places_service.dart';
import 'package:geopod/utils/ui_utils.dart';
import 'package:geopod/utils/widget_utils.dart';
import 'package:geopod/widgets/locations/place_date_field.dart';
import 'package:geopod/widgets/locations/place_tags_field.dart';
import 'package:geopod/widgets/weather_dialog.dart';

/// Result returned from AddPlaceForm containing the place data.

class AddPlaceResult {
  final Place place;
  final bool encrypted;

  // Required rather than defaulting: geopod encrypts everything, so a caller
  // must not be able to fall back to the plain track by omission.

  AddPlaceResult({required this.place, required this.encrypted});
}

/// Form for adding a new place. Returns immediately (optimistic) with a Place
/// that has a placeholder address; the caller geocodes in the background.

class AddPlaceForm extends StatefulWidget {
  const AddPlaceForm({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    required this.returnWidget,
    this.knownTags = const {},
    this.onSave,
  });

  final double? initialLatitude;
  final double? initialLongitude;
  final Widget returnWidget;

  /// Tags already used across saved places, merged with the built-in defaults
  /// to populate the tag selector.
  final Set<String> knownTags;

  /// Persists the new place.  The caller owns the optimistic list update, the
  /// Pod write, and the success/failure feedback.
  ///
  /// Returns a future that completes when the Pod write is done.  It MUST be
  /// awaited by the caller's implementation: closing the app window waits on
  /// this before quitting, so a fire-and-forget write would be killed
  /// mid-flight and the new place silently lost.
  final Future<void> Function(AddPlaceResult)? onSave;

  @override
  State<AddPlaceForm> createState() => _AddPlaceFormState();
}

class _AddPlaceFormState extends State<AddPlaceForm>
    with SafeSetState, UnsavedChangesMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _noteController = TextEditingController();

  String? _addressPreview;
  bool _isLoadingAddress = false;
  Timer? _debounceTimer;

  // Optional user-chosen date of interest, and selected tags.
  DateTime? _dateOfInterest;
  final Set<String> _tags = {};

  // All places are stored encrypted; there is no opt-out.
  static const bool _encrypt = true;

  /// True while a save is in flight, so a second Save cannot start one.
  bool _saving = false;

  // Snapshot of the last-saved state — used to compute _hasChanges. The
  // initial snapshot covers the coordinates pre-filled from the map tap, so
  // simply opening and closing the form counts as no change.
  late String _savedTitle;
  late String _savedLat;
  late String _savedLng;
  late String _savedNote;
  String? _savedDate;
  late Set<String> _savedTags;

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
    _snapshotSavedState();
  }

  /// Snapshot the current field values as the last-saved baseline.

  void _snapshotSavedState() {
    _savedTitle = _titleController.text;
    _savedLat = _latitudeController.text;
    _savedLng = _longitudeController.text;
    _savedNote = _noteController.text;
    _savedDate = _dateOfInterest?.toIso8601String();
    _savedTags = {..._tags};
  }

  /// True when the user has typed something that is not yet on the Pod.

  bool get _hasChanges =>
      _titleController.text != _savedTitle ||
      _latitudeController.text != _savedLat ||
      _longitudeController.text != _savedLng ||
      _noteController.text != _savedNote ||
      _dateOfInterest?.toIso8601String() != _savedDate ||
      _savedTags.length != _tags.length ||
      !_savedTags.containsAll(_tags);

  // The window-close prompt comes from UnsavedChangesMixin, which needs to
  // know what counts as unsaved and how to save it.

  @override
  bool get hasUnsavedChanges => _hasChanges;

  @override
  bool get canSaveUnsavedChanges =>
      _titleController.text.trim().isNotEmpty &&
      _validateLatitude(_latitudeController.text) == null &&
      _validateLongitude(_longitudeController.text) == null;

  @override
  Future<bool> saveUnsavedChanges() => _save();

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
      safeSetState(() {
        _addressPreview = address;
        _isLoadingAddress = false;
      });
    } catch (e) {
      safeSetState(() {
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

  /// Persists the new place through [AddPlaceForm.onSave].  Never pops: the
  /// window-close path keeps the form in place while the window goes away.
  ///
  /// Returns whether the place actually reached the Pod.

  Future<bool> _save() async {
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
      dateOfInterest: _dateOfInterest?.toIso8601String(),
      tags: _tags.toList()..sort(),
    );
    setState(() => _saving = true);
    try {
      // Awaited so a window close can wait for the Pod write to complete.
      await widget.onSave?.call(
        AddPlaceResult(place: place, encrypted: _encrypt),
      );
      // Snapshot only once the write has actually landed. Marking the place
      // saved on a failed write would stop the window-close prompt firing,
      // losing the place the user asked to keep.
      if (mounted) setState(_snapshotSavedState);

      return true;
    } catch (e) {
      SolidWriteFailures.report('Failed saving the place.\n\n$e');

      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Save from the Add Place button, then close the form.

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate() || _saving) {
      return;
    }
    // Close only once the write has landed. A failed write leaves the form
    // open with everything the user typed still in it.
    final saved = await _save();
    if (mounted && saved) Navigator.pop(context);
  }

  Future<void> _addCustomTag() async {
    final tag = await promptForCustomTag(context);
    if (tag != null) setState(() => _tags.add(tag));
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

                // Date of interest (optional, clearable).
                const Gap(16),
                PlaceDateField(
                  value: _dateOfInterest,
                  onChanged: (d) => setState(() => _dateOfInterest = d),
                ),

                // Tags (papertrail-style chips).
                const Gap(16),
                PlaceTagsField(
                  options: {...defaultPlaceTags, ...widget.knownTags, ..._tags},
                  selected: _tags,
                  onToggle: (tag, sel) => setState(() {
                    sel ? _tags.add(tag) : _tags.remove(tag);
                  }),
                  onAddCustom: _addCustomTag,
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
