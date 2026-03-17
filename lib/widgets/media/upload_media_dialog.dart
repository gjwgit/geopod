/// Dialog for uploading an audio or video file to the user's Solid Pod.
///
// Time-stamp: <2026-02-28 Miduo>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

// ignore_for_file: use_build_context_synchronously

library;

import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';

import 'package:geopod/models/media_item.dart';
import 'package:geopod/services/media/media_pod_service.dart';

/// Opens a modal dialog that lets the user pick a file, set a display name,
/// choose whether to encrypt it, and upload it to the Pod.
///
/// Returns the uploaded [MediaItem] on success, `null` on cancellation or error.
Future<MediaItem?> showUploadMediaDialog(
  BuildContext context,
  MediaType type,
) async {
  return showDialog<MediaItem>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _UploadMediaDialog(type: type),
  );
}

// ── Private dialog widget ────────────────────────────────────────────────────

class _UploadMediaDialog extends StatefulWidget {
  final MediaType type;
  const _UploadMediaDialog({required this.type});

  @override
  State<_UploadMediaDialog> createState() => _UploadMediaDialogState();
}

class _UploadMediaDialogState extends State<_UploadMediaDialog> {
  // Picked file state.
  String? _pickedFilename;
  Uint8List? _pickedBytes;

  // Form state.
  final _nameController = TextEditingController();
  bool _encrypt = false;
  bool _uploading = false;
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ── File picker ────────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    final isAudio = widget.type == MediaType.audio;

    // Allowed extensions by type.
    final allowedExtensions = isAudio
        ? ['mp3', 'm4a', 'aac', 'ogg', 'wav', 'webm']
        : ['mp4', 'mov', 'mkv', 'avi', 'webm'];

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      withData: true, // We need bytes for upload.
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    // `bytes` is non-null when withData = true.
    if (file.bytes == null) {
      setState(() => _errorText = 'Could not read file bytes.');
      return;
    }

    setState(() {
      _pickedFilename = file.name;
      _pickedBytes = file.bytes;
      _errorText = null;
      // Pre-fill display name from filename (without extension).
      if (_nameController.text.isEmpty) {
        final dot = file.name.lastIndexOf('.');
        _nameController.text = dot > 0
            ? file.name.substring(0, dot)
            : file.name;
      }
    });
  }

  // ── Upload ─────────────────────────────────────────────────────────────────

  Future<void> _upload() async {
    if (_pickedBytes == null || _pickedFilename == null) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Please enter a display name.');
      return;
    }

    setState(() {
      _uploading = true;
      _errorText = null;
    });

    try {
      final item = await MediaPodService.uploadItem(
        name: name,
        filename: _pickedFilename!,
        bytes: _pickedBytes!,
        type: widget.type,
        encrypt: _encrypt,
      );

      if (!mounted) return;

      if (item == null) {
        setState(() {
          _uploading = false;
          _errorText = 'Upload failed. Check your Pod connection.';
        });
      } else {
        Navigator.of(context).pop(item);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _errorText = 'Upload error: $e';
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isAudio = widget.type == MediaType.audio;
    final typeLabel = isAudio ? 'Audio' : 'Video';
    final typeIcon = isAudio ? Icons.audio_file : Icons.video_file;
    final accent = Theme.of(context).colorScheme.primary;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          Icon(typeIcon, color: accent),
          const SizedBox(width: 8),
          Text('Upload $typeLabel'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── File picker button ─────────────────────────────────────────
            OutlinedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: Text(
                _pickedFilename ?? 'Select file…',
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: _uploading ? null : _pickFile,
            ),
            if (_pickedFilename != null) ...[
              const SizedBox(height: 4),
              Text(
                _pickedFilename!,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 16),

            // ── Display name field ─────────────────────────────────────────
            TextField(
              controller: _nameController,
              enabled: !_uploading,
              decoration: const InputDecoration(
                labelText: 'Display name',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),

            const SizedBox(height: 12),

            // ── Encrypt toggle ─────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.lock_outline, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Encrypt file',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Requires your security key to play back.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _encrypt,
                  onChanged: _uploading
                      ? null
                      : (v) => setState(() => _encrypt = v),
                ),
              ],
            ),

            // ── Error text ─────────────────────────────────────────────────
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
          label: const Text('Upload'),
          onPressed: (_uploading || _pickedBytes == null) ? null : _upload,
        ),
      ],
    );
  }
}
