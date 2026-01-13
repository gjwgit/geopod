/// POD file list widget for displaying files and directories.
///
// Time-stamp: <2026-01-01 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';

import 'package:geopod/models/pod_file_item.dart';

/// Widget for displaying a list of POD files and directories.
class PodFileList extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 80,
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.5),
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

    // Separate directories and files
    final directories = items.where((i) => i.isDirectory).toList();
    final files = items.where((i) => !i.isDirectory).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Directories section
        if (directories.isNotEmpty) ...[
          _SectionHeader(
            title: 'Folders',
            count: directories.length,
            icon: Icons.folder,
          ),
          ...directories.map(
            (item) => _FileListTile(
              item: item,
              isSelected: selectedFilePath == item.path,
              onTap: () => onDirectoryTap?.call(item),
              onDelete: showDelete && (canDelete?.call(item) ?? true)
                  ? () => _confirmDelete(context, item)
                  : null,
              onDownload: null,
            ),
          ),
        ],

        // Files section
        if (files.isNotEmpty) ...[
          if (directories.isNotEmpty) const SizedBox(height: 8),
          _SectionHeader(
            title: 'Files',
            count: files.length,
            icon: Icons.insert_drive_file,
          ),
          ...files.map(
            (item) => _FileListTile(
              item: item,
              isSelected: selectedFilePath == item.path,
              onTap: () => onFileTap?.call(item),
              onDelete: showDelete && (canDelete?.call(item) ?? true)
                  ? () => _confirmDelete(context, item)
                  : null,
              onDownload: onDownload != null
                  ? () => onDownload?.call(item)
                  : null,
            ),
          ),
        ],
      ],
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
          'Are you sure you want to delete "${item.name}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete?.call(item);
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
}

/// Section header widget.
class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single file/directory list tile.
class _FileListTile extends StatelessWidget {
  final PodFileItem item;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onDownload;

  const _FileListTile({
    required this.item,
    this.isSelected = false,
    this.onTap,
    this.onDelete,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getIconBackgroundColor(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getIcon(),
                    color: _getIconColor(context),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // File info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getTypeDescription(),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),

                // Actions
                if (item.isDirectory)
                  Icon(Icons.chevron_right, color: colorScheme.outline)
                else ...[
                  if (onDownload != null)
                    IconButton(
                      icon: Icon(Icons.download, color: colorScheme.primary),
                      onPressed: onDownload,
                      tooltip: 'Download',
                      iconSize: 20,
                    ),
                  if (onDelete != null)
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: colorScheme.error,
                      ),
                      onPressed: onDelete,
                      tooltip: 'Delete',
                      iconSize: 20,
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIcon() {
    if (item.isDirectory) return Icons.folder_rounded;

    switch (item.extension) {
      case 'json':
        return Icons.data_object;
      case 'txt':
        return Icons.article;
      case 'md':
        return Icons.description;
      case 'csv':
        return Icons.table_chart;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image;
      case 'mp3':
      case 'wav':
      case 'ogg':
        return Icons.audio_file;
      case 'mp4':
      case 'webm':
      case 'avi':
        return Icons.video_file;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'ttl':
      case 'rdf':
      case 'n3':
        return Icons.schema;
      case 'acl':
        return Icons.security;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getIconColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (item.isDirectory) return colorScheme.primary;
    if (item.isImageFile) return Colors.purple;
    if (item.isMediaFile) return Colors.orange;
    if (item.extension == 'json') return Colors.amber.shade700;
    if (item.isTextFile) return Colors.blue;

    return colorScheme.outline;
  }

  Color _getIconBackgroundColor(BuildContext context) {
    return _getIconColor(context).withValues(alpha: 0.1);
  }

  String _getTypeDescription() {
    if (item.isDirectory) return 'Folder';

    final ext = item.extension;
    if (ext == null) return 'File';

    switch (ext) {
      case 'json':
        return 'JSON Document';
      case 'txt':
        return 'Text File';
      case 'md':
        return 'Markdown';
      case 'csv':
        return 'Spreadsheet';
      case 'ttl':
        return 'Turtle (RDF)';
      case 'jpg':
      case 'jpeg':
        return 'JPEG Image';
      case 'png':
        return 'PNG Image';
      case 'pdf':
        return 'PDF Document';
      default:
        return '${ext.toUpperCase()} File';
    }
  }
}
