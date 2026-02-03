/// Dialog showing the expected JSON format for importing places.
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

/// Dialog showing the expected JSON format for importing places.

class ImportFormatDialog extends StatelessWidget {
  const ImportFormatDialog({super.key});

  static const String _exampleJson = '''[
  {
    "id": "place_001",
    "lat": -33.8568,
    "lng": 151.2153,
    "note": "Sydney Opera House",
    "timestamp": "2025-01-01T00:00:00.000Z",
    "address": "Bennelong Point, Sydney"
  }
]''';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue),
          SizedBox(width: 8),
          Expanded(child: Text('Import JSON Format')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your JSON file should contain an array of place objects.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Required Fields:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            _buildFieldInfo('lat', 'Latitude (-90 to 90)', isRequired: true),
            _buildFieldInfo('lng', 'Longitude (-180 to 180)', isRequired: true),
            const SizedBox(height: 12),
            const Text(
              'Optional Fields (auto-filled if missing):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            _buildFieldInfo('id', 'Unique ID (auto-generated UUID)'),
            _buildFieldInfo('note', 'Description (defaults to empty)'),
            _buildFieldInfo('timestamp', 'ISO date (defaults to now)'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Address field is ignored. Addresses will be auto-generated from coordinates using reverse geocoding.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Example:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                _exampleJson,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.folder_open, size: 18),
          label: const Text('Select File'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildFieldInfo(
    String field,
    String description, {
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isRequired ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: isRequired ? Colors.red.shade400 : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            field,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isRequired ? Colors.red.shade700 : Colors.blue.shade700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
