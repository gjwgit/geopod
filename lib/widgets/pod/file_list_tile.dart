/// File list tile widget with animation support.
///
// Time-stamp: <2026-01-07 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';

import 'package:geopod/models/pod_file_item.dart';
import 'package:geopod/widgets/pod/file_type_helpers.dart';

/// Animated file/directory list tile with delete animation.

class AnimatedFileListTile extends StatefulWidget {
  /// The file item to display.
  final PodFileItem item;

  /// Whether this item is currently selected.
  final bool isSelected;

  /// Whether this item is being deleted (triggers exit animation).
  final bool isDeleting;

  /// Callback when the tile is tapped.
  final VoidCallback? onTap;

  /// Callback when delete is requested.
  final VoidCallback? onDelete;

  /// Callback when download is requested.
  final VoidCallback? onDownload;

  const AnimatedFileListTile({
    super.key,
    required this.item,
    this.isSelected = false,
    this.isDeleting = false,
    this.onTap,
    this.onDelete,
    this.onDownload,
  });

  @override
  State<AnimatedFileListTile> createState() => _AnimatedFileListTileState();
}

class _AnimatedFileListTileState extends State<AnimatedFileListTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(AnimatedFileListTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDeleting && !oldWidget.isDeleting) {
      _controller.forward();
    } else if (!widget.isDeleting && oldWidget.isDeleting) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use single AnimatedBuilder for better performance.
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final value = 1.0 - _animation.value;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(-30 * _animation.value, 0),
            child: child,
          ),
        );
      },
      child: FileListTileContent(
        item: widget.item,
        isSelected: widget.isSelected,
        onTap: widget.onTap,
        onDelete: widget.onDelete,
        onDownload: widget.onDownload,
      ),
    );
  }
}

/// Single file/directory list tile content.

class FileListTileContent extends StatelessWidget {
  /// The file item to display.
  final PodFileItem item;

  /// Whether this item is currently selected.
  final bool isSelected;

  /// Callback when the tile is tapped.
  final VoidCallback? onTap;

  /// Callback when delete is requested.
  final VoidCallback? onDelete;

  /// Callback when download is requested.
  final VoidCallback? onDownload;

  const FileListTileContent({
    super.key,
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
                // Icon.
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: getFileIconBackgroundColor(context, item),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    getFileIcon(item),
                    color: getFileIconColor(context, item),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // File info.
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
                        getFileTypeDescription(item),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),

                // Actions.
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
}

/// Section header widget for grouping files/folders.

class SectionHeader extends StatelessWidget {
  /// The title of the section.
  final String title;

  /// Number of items in this section.
  final int count;

  /// Icon to display before the title.
  final IconData icon;

  const SectionHeader({
    super.key,
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
