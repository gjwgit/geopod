/// Generic media list widget for audio and video items.
///
// Time-stamp: <2026-02-19 GitHub Copilot>
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
/// Authors: GitHub Copilot

library;

import 'package:flutter/material.dart';

/// A generic, reusable list widget for playable / deletable media items.
///
/// [T] is the item data type. Callers supply projection functions so the widget
/// remains decoupled from any concrete model.
///
/// Parameters
/// ----------
/// * [title]         – Section / page heading shown above the list.
/// * [items]         – The items to display.
/// * [isLoading]     – When `true` a loading indicator is shown instead.
/// * [emptyMessage]  – Text shown when [items] is empty and not loading.
/// * [titleOf]       – Returns a display title for an item.
/// * [subtitleOf]    – Returns an optional subtitle line.
/// * [iconOf]        – Returns the leading [IconData] for an item.
/// * [playerBuilder] – Returns the inline player widget for an item.
/// * [onDelete]      – Called after the user confirms deletion.

class MediaListWidget<T> extends StatefulWidget {
  const MediaListWidget({
    super.key,
    required this.title,
    required this.items,
    required this.isLoading,
    required this.titleOf,
    required this.iconOf,
    required this.playerBuilder,
    this.subtitleOf,
    this.onDelete,
    this.onManageLinks,
    this.emptyMessage = 'No items found.',
    this.accentColor,
  });

  final String title;
  final List<T> items;
  final bool isLoading;
  final String Function(T item) titleOf;
  final String? Function(T item)? subtitleOf;
  final IconData Function(T item) iconOf;

  /// Builds the inline player. Receives [BuildContext] and the [item].
  final Widget Function(BuildContext context, T item) playerBuilder;

  final Future<void> Function(T item)? onDelete;
  final String emptyMessage;

  /// Optional callback invoked when the user taps "Manage links" for [item].
  /// Callers (e.g. [AudioPage], [VideoPage]) open a place-picker dialog here.
  final Future<void> Function(T item)? onManageLinks;

  /// Optional accent colour for avatar background and play icon.
  final Color? accentColor;

  @override
  State<MediaListWidget<T>> createState() => _MediaListWidgetState<T>();
}

class _MediaListWidgetState<T> extends State<MediaListWidget<T>> {
  /// Index of the row whose inline player is currently visible; `null` = none.
  int? _expandedIndex;

  void _togglePlayer(int index) {
    setState(() {
      _expandedIndex = (_expandedIndex == index) ? null : index;
    });
  }

  Future<void> _confirmAndDelete(BuildContext context, T item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text(
          'Delete "${widget.titleOf(item)}"?\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.onDelete != null) {
      await widget.onDelete!(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Section heading ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            widget.title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),

        // ── Body ──────────────────────────────────────────────────────────
        Expanded(child: _buildBody(accent)),
      ],
    );
  }

  Widget _buildBody(Color accent) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.items.isEmpty) {
      return Center(
        child: Text(
          widget.emptyMessage,
          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: widget.items.length,
      itemBuilder: (context, index) => _buildTile(context, index, accent),
    );
  }

  Widget _buildTile(BuildContext context, int index, Color accent) {
    final item = widget.items[index];
    final isExpanded = _expandedIndex == index;
    final subtitle = widget.subtitleOf?.call(item);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: accent,
              child: Icon(widget.iconOf(item), color: Colors.white, size: 20),
            ),
            title: Text(
              widget.titleOf(item),
              style: const TextStyle(fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: subtitle != null
                ? Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Play / collapse toggle.
                IconButton(
                  tooltip: isExpanded ? 'Close player' : 'Play',
                  icon: Icon(
                    isExpanded
                        ? Icons.stop_circle_outlined
                        : Icons.play_circle_fill,
                    color: isExpanded ? Colors.red : accent,
                    size: 28,
                  ),
                  onPressed: () => _togglePlayer(index),
                ),
                // Link to locations – shown when handler is provided.
                if (widget.onManageLinks != null)
                  IconButton(
                    tooltip: 'Link to locations',
                    icon: Icon(
                      Icons.add_location_alt_outlined,
                      color: Colors.teal.shade600,
                    ),
                    onPressed: () => widget.onManageLinks!(item),
                  ),
                // Delete – shown only when a handler is provided.
                if (widget.onDelete != null)
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline, color: Colors.grey),
                    onPressed: () => _confirmAndDelete(context, item),
                  ),
              ],
            ),
          ),

          // Inline player – rendered only for the expanded row.
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: widget.playerBuilder(context, item),
            ),
        ],
      ),
    );
  }
}
