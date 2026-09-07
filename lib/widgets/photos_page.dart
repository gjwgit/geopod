/// Photos library page – lists photo files and displays thumbnails.
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

library;

import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:solidpod/solidpod.dart' show authStateNotifier;

import 'package:geopod/models/media_item.dart';
import 'package:geopod/services/media/media_pod_service.dart';
import 'package:geopod/services/pod/pod_auth.dart';
import 'package:geopod/widgets/map/login_required_dialog.dart';
import 'package:geopod/widgets/media/photo_viewer_dialog.dart';
import 'package:geopod/widgets/media/place_link_picker_dialog.dart';

/// Page displaying photos stored on the user's Pod.
class PhotosPage extends StatefulWidget {
  const PhotosPage({super.key});

  @override
  State<PhotosPage> createState() => _PhotosPageState();
}

class _PhotosPageState extends State<PhotosPage> {
  List<MediaItem> _podItems = [];
  bool _isLoadingPod = false;

  @override
  void initState() {
    super.initState();
    _loadPodItems();
    authStateNotifier.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    authStateNotifier.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() => _loadPodItems();

  Future<void> _loadPodItems() async {
    if (!PodAuth.isLoggedInSync()) {
      if (mounted) setState(() => _podItems = []);
      return;
    }
    if (mounted) setState(() => _isLoadingPod = true);
    try {
      final items = await MediaPodService.listItems(MediaType.photo);
      if (mounted) setState(() => _podItems = items);
    } finally {
      if (mounted) setState(() => _isLoadingPod = false);
    }
  }

  Future<void> _uploadNewPhoto() async {
    if (!PodAuth.isLoggedInSync()) {
      await showLoginRequiredDialog(context);
      return;
    }

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    if (!mounted) return;
    final nameController = TextEditingController(
      text: file.name.contains('.')
          ? file.name.substring(0, file.name.lastIndexOf('.'))
          : file.name,
    );

    final confirmedName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Upload Photo'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Display name / caption',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('Upload'),
          ),
        ],
      ),
    );

    if (confirmedName == null || confirmedName.isEmpty) return;

    final uploaded = await MediaPodService.uploadItem(
      name: confirmedName,
      filename: file.name,
      bytes: file.bytes!,
      type: MediaType.photo,
      encrypt: true,
    );

    if (uploaded != null) {
      await _loadPodItems();
    }
  }

  Future<void> _deletePhoto(MediaItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Photo?'),
        content: Text('Are you sure you want to delete "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await MediaPodService.deleteItem(item);
      await _loadPodItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh photos',
            onPressed: _loadPodItems,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadNewPhoto,
        tooltip: 'Upload photo',
        child: const Icon(Icons.add_a_photo),
      ),
      body: _isLoadingPod
          ? const Center(child: CircularProgressIndicator())
          : _podItems.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    PodAuth.isLoggedInSync()
                        ? 'No photos uploaded yet.'
                        : 'Log in to your Solid Pod to view and upload photos.',
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  if (PodAuth.isLoggedInSync())
                    ElevatedButton.icon(
                      onPressed: _uploadNewPhoto,
                      icon: const Icon(Icons.add_a_photo),
                      label: const Text('Upload your first photo'),
                    ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                childAspectRatio: 0.85,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _podItems.length,
              itemBuilder: (context, index) {
                final item = _podItems[index];
                return _PhotoCard(
                  item: item,
                  onTap: () => showPhotoViewerDialog(
                    context,
                    item: item,
                    onDelete: () => _deletePhoto(item),
                  ),
                  onManageLinks: () async {
                    await showPlaceLinkPickerDialog(context, item);
                    _loadPodItems();
                  },
                  onDelete: () => _deletePhoto(item),
                );
              },
            ),
    );
  }
}

class _PhotoCard extends StatefulWidget {
  const _PhotoCard({
    required this.item,
    required this.onTap,
    required this.onManageLinks,
    required this.onDelete,
  });

  final MediaItem item;
  final VoidCallback onTap;
  final VoidCallback onManageLinks;
  final VoidCallback onDelete;

  @override
  State<_PhotoCard> createState() => _PhotoCardState();
}

class _PhotoCardState extends State<_PhotoCard> {
  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await MediaPodService.loadMediaBytes(widget.item);
    if (mounted) {
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final linkedCount = widget.item.locationIds.length;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Thumbnail ────────────────────────────────────────────────
            Expanded(
              child: Container(
                color: Colors.grey.shade100,
                child: _loading
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _bytes != null
                    ? Image.memory(_bytes!, fit: BoxFit.cover)
                    : const Center(
                        child: Icon(
                          Icons.image,
                          size: 40,
                          color: Colors.black26,
                        ),
                      ),
              ),
            ),

            // ── Info & Actions Footer ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.place,
                        size: 13,
                        color: linkedCount > 0 ? Colors.blue : Colors.grey,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          linkedCount == 0
                              ? 'Unlinked'
                              : '$linkedCount ${linkedCount == 1 ? "place" : "places"}',
                          style: TextStyle(
                            fontSize: 11,
                            color: linkedCount > 0
                                ? Colors.blue.shade700
                                : Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.link, size: 16),
                        tooltip: 'Link to places',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: widget.onManageLinks,
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: Colors.red,
                        ),
                        tooltip: 'Delete',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: widget.onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
