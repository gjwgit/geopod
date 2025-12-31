/// Data model for POD file items.
///
// Time-stamp: <2026-01-01 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

/// Represents a file or directory item in the POD.
class PodFileItem {
  /// The name of the file or directory.
  final String name;

  /// The full path relative to the base directory.
  final String path;

  /// Whether this item is a directory.
  final bool isDirectory;

  /// File size in bytes (null for directories).
  final int? size;

  /// Content type (MIME type, null for directories).
  final String? contentType;

  /// Last modified date (if available).
  final DateTime? lastModified;

  const PodFileItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size,
    this.contentType,
    this.lastModified,
  });

  /// Creates a directory item.
  factory PodFileItem.directory({required String name, required String path}) {
    return PodFileItem(name: name, path: path, isDirectory: true);
  }

  /// Creates a file item.
  factory PodFileItem.file({
    required String name,
    required String path,
    int? size,
    String? contentType,
    DateTime? lastModified,
  }) {
    return PodFileItem(
      name: name,
      path: path,
      isDirectory: false,
      size: size,
      contentType: contentType,
      lastModified: lastModified,
    );
  }

  /// Get file extension (lowercase, without dot).
  String? get extension {
    if (isDirectory) return null;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return null;
    return name.substring(dot + 1).toLowerCase();
  }

  /// Check if this is a text file based on extension.
  bool get isTextFile {
    const textExtensions = {
      'txt',
      'json',
      'md',
      'xml',
      'html',
      'css',
      'js',
      'dart',
      'yaml',
      'yml',
      'csv',
      'log',
      'ini',
      'conf',
      'cfg',
      'ttl',
      'rdf',
      'n3',
      'jsonld',
      'acl',
    };
    return textExtensions.contains(extension);
  }

  /// Check if this is an image file based on extension.
  bool get isImageFile {
    const imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'ico'};
    return imageExtensions.contains(extension);
  }

  /// Check if this is a media file based on extension.
  bool get isMediaFile {
    const mediaExtensions = {'mp3', 'wav', 'ogg', 'mp4', 'webm', 'avi'};
    return mediaExtensions.contains(extension);
  }

  @override
  String toString() =>
      'PodFileItem(name: $name, path: $path, isDir: $isDirectory)';
}
