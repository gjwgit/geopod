/// Reusable widget for visualizing and uploading photos linked to a place.
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

import 'package:geopod/models/media_item.dart';
import 'package:geopod/services/media/media_pod_service.dart';
import 'package:geopod/services/media/place_media_service.dart';
import 'package:geopod/services/pod/pod_auth.dart';
import 'package:geopod/widgets/map/login_required_dialog.dart';
import 'package:geopod/widgets/media/photo_viewer_dialog.dart';
import 'package:geopod/widgets/media/upload_photo_dialog.dart';

/// Displays a horizontal photo gallery for [placeId] and provides an
/// "Add Photo" action to upload photos directly to this location.
class PlacePhotoSection extends StatefulWidget {
  const PlacePhotoSection({
    super.key,
    required this.placeId,
    this.placeTitle,
    this.onPhotosChanged,
  });

  final String placeId;
  final String? placeTitle;
  final VoidCallback? onPhotosChanged;

  @override
  State<PlacePhotoSection> createState() => _PlacePhotoSectionState();
}

class _PlacePhotoSectionState extends State<PlacePhotoSection> {
  List<MediaItem>? _photos;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  @override
  void didUpdateWidget(PlacePhotoSection old) {
    super.didUpdateWidget(old);
    if (old.placeId != widget.placeId) _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() => _loading = true);
    try {
      final photos = await PlaceMediaService.getPhotosForPlace(widget.placeId);
      if (mounted) {
        setState(() {
          _photos = photos;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleAddPhoto() async {
    if (!PodAuth.isLoggedInSync()) {
      await showLoginRequiredDialog(context);
      return;
    }
    final newItem = await showUploadPhotoDialog(
      context,
      placeId: widget.placeId,
      placeTitle: widget.placeTitle,
    );
    if (newItem != null) {
      await _loadPhotos();
      widget.onPhotosChanged?.call();
    }
  }

  Future<void> _handleDeletePhoto(MediaItem item) async {
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
      await _loadPhotos();
      widget.onPhotosChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final photos = _photos ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.photo_library, size: 16, color: Colors.grey.shade700),
              const SizedBox(width: 6),
              Text(
                photos.isEmpty ? 'Photos' : 'Photos (${photos.length})',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: _handleAddPhoto,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 14,
                        color: Colors.teal.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Add Photo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.teal.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (photos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: OutlinedButton.icon(
              onPressed: _handleAddPhoto,
              icon: const Icon(Icons.add_a_photo_outlined, size: 16),
              label: const Text('Add photo to this location'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.teal.shade700,
                side: BorderSide(color: Colors.teal.shade300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                textStyle: const TextStyle(fontSize: 13),
                visualDensity: VisualDensity.compact,
              ),
            ),
          )
        else
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final photo = photos[index];
                return _PhotoThumbnailCard(
                  item: photo,
                  placeTitle: widget.placeTitle,
                  onTap: () => showPhotoViewerDialog(
                    context,
                    item: photo,
                    placeTitle: widget.placeTitle,
                    onDelete: () => _handleDeletePhoto(photo),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _PhotoThumbnailCard extends StatefulWidget {
  const _PhotoThumbnailCard({
    required this.item,
    required this.onTap,
    this.placeTitle,
  });

  final MediaItem item;
  final VoidCallback onTap;
  final String? placeTitle;

  @override
  State<_PhotoThumbnailCard> createState() => _PhotoThumbnailCardState();
}

class _PhotoThumbnailCardState extends State<_PhotoThumbnailCard> {
  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = await MediaPodService.loadMediaBytes(widget.item);
    if (mounted) {
      setState(() {
        _bytes = b;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey.shade100,
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_loading)
              const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_bytes != null)
              Image.memory(_bytes!, fit: BoxFit.cover)
            else
              const Center(
                child: Icon(Icons.image, size: 32, color: Colors.black26),
              ),

            // Title caption gradient banner.
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black87, Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
                child: Text(
                  widget.item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
