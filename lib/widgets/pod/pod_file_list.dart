/// POD file list widget for displaying files and directories.
///
// Time-stamp: <2026-01-07 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:geopod/models/pod_file_item.dart';
import 'package:geopod/widgets/pod/file_list_tile.dart';

/// Widget for displaying a list of POD files and directories with animations.

class PodFileList extends StatefulWidget {
  /// List of file items to display.
  final List<PodFileItem> items;

  /// Callback when a directory is tapped.
  final void Function(PodFileItem item)? onDirectoryTap;

  /// Callback when a file is tapped.
  final void Function(PodFileItem item)? onFileTap;

  /// Callback when delete is requested.
  final void Function(PodFileItem item)? onDelete;

  /// Callback when download is requested.
  final void Function(PodFileItem item)? onDownload;

  /// Whether to show delete buttons.
  final bool showDelete;

  /// Function to check if an item can be deleted.
  /// If null, all items can be deleted (when showDelete is true).
  final bool Function(PodFileItem item)? canDelete;

  /// Currently selected file path.
  final String? selectedFilePath;

  const PodFileList({
    super.key,
    required this.items,
    this.onDirectoryTap,
    this.onFileTap,
    this.onDelete,
    this.onDownload,
    this.showDelete = true,
    this.canDelete,
    this.selectedFilePath,
  });

  @override
  State<PodFileList> createState() => _PodFileListState();
}

class _PodFileListState extends State<PodFileList> {
  /// Set of item paths currently being deleted (for animation).
  final Set<String> _deletingItems = {};

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return _buildEmptyState(context);
    }

    // Separate directories and files.
    final directories = widget.items.where((i) => i.isDirectory).toList();
    final files = widget.items.where((i) => !i.isDirectory).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Directories section.
        if (directories.isNotEmpty)
          ...[
              const SectionHeader(
                title: 'Folders',
                count: 0, // Will be set below
                icon: Icons.folder,
              ),
              ...directories.map((item) => _buildDirectoryTile(item)),
            ]
            ..[0] = SectionHeader(
              title: 'Folders',
              count: directories.length,
              icon: Icons.folder,
            ),

        // Files section.
        if (files.isNotEmpty) ...[
          if (directories.isNotEmpty) const SizedBox(height: 8),
          SectionHeader(
            title: 'Files',
            count: files.length,
            icon: Icons.insert_drive_file,
          ),
          ...files.map((item) => _buildFileTile(item)),
        ],
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 80,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'This directory is empty',
            style: TextStyle(
              color: Theme.of(context).colorScheme.outline,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No files or folders found',
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectoryTile(PodFileItem item) {
    return AnimatedFileListTile(
      key: ValueKey('dir_${item.path}'),
      item: item,
      isSelected: widget.selectedFilePath == item.path,
      isDeleting: _deletingItems.contains(item.path),
      onTap: () => widget.onDirectoryTap?.call(item),
      onDelete: widget.showDelete && (widget.canDelete?.call(item) ?? true)
          ? () => _confirmDelete(context, item)
          : null,
      onDownload: null,
    );
  }

  Widget _buildFileTile(PodFileItem item) {
    return AnimatedFileListTile(
      key: ValueKey('file_${item.path}'),
      item: item,
      isSelected: widget.selectedFilePath == item.path,
      isDeleting: _deletingItems.contains(item.path),
      onTap: () => widget.onFileTap?.call(item),
      onDelete: widget.showDelete && (widget.canDelete?.call(item) ?? true)
          ? () => _confirmDelete(context, item)
          : null,
      onDownload: widget.onDownload != null
          ? () => widget.onDownload?.call(item)
          : null,
    );
  }

  void _confirmDelete(BuildContext context, PodFileItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(ctx).colorScheme.error,
            ),
            const SizedBox(width: 8),
            const Text('Delete'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${item.name}"?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performDelete(item);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Performs delete with animation.

  void _performDelete(PodFileItem item) {
    // Start delete animation.
    setState(() => _deletingItems.add(item.path));

    // Schedule cleanup and delete after animation frame.

    SchedulerBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() => _deletingItems.remove(item.path));
        }

        // Fire and forget - don't block on the async delete.
        final onDelete = widget.onDelete;
        if (onDelete != null) {
          unawaited(Future(() => onDelete(item)));
        }
      });
    });
  }
}
