/// Dialog showing a preview of places to be imported with edit/delete capabilities.
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

import 'package:geopod/models/place.dart';
import 'package:geopod/widgets/locations/edit_import_place_dialog.dart';

/// Result of import preview dialog containing places and encryption flag.

class ImportPreviewResult {
  final List<Place> places;
  final bool encrypted;

  ImportPreviewResult({required this.places, this.encrypted = false});
}

/// Dialog showing a preview of places to be imported with edit/delete capabilities.

class ImportPreviewDialog extends StatefulWidget {
  const ImportPreviewDialog({
    super.key,
    required this.places,
    required this.errors,
    required this.skippedCount,
  });

  final List<Place> places;
  final List<String> errors;
  final int skippedCount;

  @override
  State<ImportPreviewDialog> createState() => _ImportPreviewDialogState();
}

class _ImportPreviewDialogState extends State<ImportPreviewDialog> {
  late List<Place> _editablePlaces;

  /// Whether to encrypt imported places.
  /// Defaults to true for consistency with add place form.

  bool _encrypt = true;

  @override
  void initState() {
    super.initState();

    // Create a mutable copy of the places list.

    _editablePlaces = List<Place>.from(widget.places);
  }

  /// Opens the edit dialog for a place in the preview list.

  Future<void> _editPreviewPlace(int index) async {
    final place = _editablePlaces[index];
    final result = await showDialog<Place>(
      context: context,
      builder: (context) => EditImportPlaceDialog(place: place, index: index),
    );

    if (result != null && mounted) {
      setState(() {
        _editablePlaces[index] = result;
      });
    }
  }

  /// Removes a place from the preview list.

  void _removePreviewPlace(int index) {
    setState(() {
      _editablePlaces.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.preview, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Import Preview (${_editablePlaces.length} places)'),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.skippedCount > 0) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        color: Colors.orange.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${widget.skippedCount} items skipped due to validation errors',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Info box about editing.
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tap the edit icon to modify a place before importing, or the delete icon to remove it.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Encryption option.
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _encrypt ? Colors.green.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _encrypt
                        ? Colors.green.shade300
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _encrypt,
                      onChanged: (value) {
                        setState(() {
                          _encrypt = value ?? false;
                        });
                      },
                      activeColor: Colors.green,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _encrypt ? Icons.lock : Icons.lock_open,
                                size: 18,
                                color: _encrypt ? Colors.green : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Encrypt imported places',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _encrypt
                                      ? Colors.green.shade700
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _encrypt
                                ? 'Places will be stored securely with encryption'
                                : 'Enable to store imported places with encryption',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Places to import:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const Spacer(),
                  if (_editablePlaces.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _editablePlaces.clear();
                        });
                      },
                      icon: Icon(
                        Icons.delete_sweep,
                        size: 16,
                        color: Colors.red.shade600,
                      ),
                      label: Text(
                        'Remove All',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_editablePlaces.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No places to import',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _editablePlaces.length,
                    itemBuilder: (context, index) {
                      final place = _editablePlaces[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            radius: 16,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                          title: Text(
                            place.note.isEmpty
                                ? '(No note)'
                                : place.displayTitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: place.note.isEmpty
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                          subtitle: Text(
                            place.coordinates,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: Colors.blue.shade600,
                                ),
                                onPressed: () => _editPreviewPlace(index),
                                tooltip: 'Edit',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Colors.red,
                                ),
                                onPressed: () => _removePreviewPlace(index),
                                tooltip: 'Remove',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _editablePlaces.isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  ImportPreviewResult(
                    places: _editablePlaces,
                    encrypted: _encrypt,
                  ),
                ),
          icon: Icon(_encrypt ? Icons.lock : Icons.download, size: 18),
          label: Text(
            _encrypt
                ? 'Import ${_editablePlaces.length} (Encrypted)'
                : 'Import ${_editablePlaces.length} Places',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _encrypt ? Colors.green.shade700 : Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
