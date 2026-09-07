/// Dialog for uploading a photo to the user's Solid Pod for a location.
///
// Time-stamp: <2026-09-07 Amogh>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
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
/// Authors: Amogh

// ignore_for_file: use_build_context_synchronously

library;

import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';

import 'package:geopod/models/media_item.dart';
import 'package:geopod/services/media/media_pod_service.dart';
import 'package:geopod/services/media/place_media_service.dart';

/// Opens a modal dialog that lets the user pick an image file, preview it,
/// set a caption, and upload it encrypted to the Pod, linked to [placeId].
///
/// Returns the uploaded [MediaItem] on success, `null` on cancellation or error.
Future<MediaItem?> showUploadPhotoDialog(
  BuildContext context, {
  required String placeId,
  String? placeTitle,
}) async {
  return showDialog<MediaItem>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) =>
        _UploadPhotoDialog(placeId: placeId, placeTitle: placeTitle),
  );
}

class _UploadPhotoDialog extends StatefulWidget {
  final String placeId;
  final String? placeTitle;

  const _UploadPhotoDialog({required this.placeId, this.placeTitle});

  @override
  State<_UploadPhotoDialog> createState() => _UploadPhotoDialogState();
}

class _UploadPhotoDialogState extends State<_UploadPhotoDialog> {
  String? _pickedFilename;
  Uint8List? _pickedBytes;

  final _captionController = TextEditingController();
  bool _uploading = false;
  String? _errorText;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    if (file.bytes == null) {
      setState(() => _errorText = 'Could not read image bytes.');
      return;
    }

    setState(() {
      _pickedFilename = file.name;
      _pickedBytes = file.bytes;
      _errorText = null;
      if (_captionController.text.isEmpty) {
        final dot = file.name.lastIndexOf('.');
        _captionController.text = dot > 0
            ? file.name.substring(0, dot)
            : file.name;
      }
    });
  }

  Future<void> _upload() async {
    if (_pickedBytes == null || _pickedFilename == null) return;

    final caption = _captionController.text.trim();
    if (caption.isEmpty) {
      setState(() => _errorText = 'Please enter a photo caption or title.');
      return;
    }

    setState(() {
      _uploading = true;
      _errorText = null;
    });

    try {
      final item = await MediaPodService.uploadItem(
        name: caption,
        filename: _pickedFilename!,
        bytes: _pickedBytes!,
        type: MediaType.photo,
        encrypt: true,
      );

      if (!mounted) return;

      if (item == null) {
        setState(() {
          _uploading = false;
          _errorText = 'Upload failed. Check your Pod connection.';
        });
        return;
      }

      // Automatically link to this place.
      final linked = await PlaceMediaService.linkToPlace(item, widget.placeId);
      final finalItem = linked
          ? item.copyWith(locationIds: [...item.locationIds, widget.placeId])
          : item;

      if (!mounted) return;
      Navigator.of(context).pop(finalItem);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _errorText = 'Upload error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          Icon(Icons.add_a_photo, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.placeTitle != null
                  ? 'Add Photo: ${widget.placeTitle}'
                  : 'Add Location Photo',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Photo Picker / Live Preview ──────────────────────────────
            if (_pickedBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 180,
                  color: Colors.black12,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.memory(
                        _pickedBytes!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 180,
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            icon: const Icon(
                              Icons.refresh,
                              size: 16,
                              color: Colors.white,
                            ),
                            tooltip: 'Pick another image',
                            onPressed: _uploading ? null : _pickPhoto,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _pickedFilename!,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis,
              ),
            ] else ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.image_outlined),
                label: const Text('Select image from device…'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _uploading ? null : _pickPhoto,
              ),
            ],

            const SizedBox(height: 16),

            // ── Caption / Title ──────────────────────────────────────────
            TextField(
              controller: _captionController,
              enabled: !_uploading,
              decoration: const InputDecoration(
                labelText: 'Photo caption / title',
                hintText: 'e.g. Front view, sunset, scenic overlook',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),

            const SizedBox(height: 12),

            // ── Encryption indicator ─────────────────────────────────────
            Row(
              children: [
                Icon(Icons.lock, size: 18, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stored securely & encrypted in your Pod',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const Text(
                        'Associated with this location in your personal Pod storage.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Error text ───────────────────────────────────────────────
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _uploading ? null : () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          icon: _uploading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.cloud_upload_outlined),
          label: const Text('Upload Photo'),
          onPressed: (_uploading || _pickedBytes == null) ? null : _upload,
        ),
      ],
    );
  }
}
