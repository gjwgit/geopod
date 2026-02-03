/// Helper functions for file type detection, icons, and descriptions.
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

/// Returns the appropriate icon for a file item based on its type and extension.

IconData getFileIcon(PodFileItem item) {
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

/// Returns the icon color for a file item based on its type.

Color getFileIconColor(BuildContext context, PodFileItem item) {
  final colorScheme = Theme.of(context).colorScheme;

  if (item.isDirectory) return colorScheme.primary;
  if (item.isImageFile) return Colors.purple;
  if (item.isMediaFile) return Colors.orange;
  if (item.extension == 'json') return Colors.amber.shade700;
  if (item.isTextFile) return Colors.blue;

  return colorScheme.outline;
}

/// Returns the background color for the file icon.

Color getFileIconBackgroundColor(BuildContext context, PodFileItem item) {
  return getFileIconColor(context, item).withValues(alpha: 0.1);
}

/// Returns a human-readable type description for a file item.

String getFileTypeDescription(PodFileItem item) {
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
