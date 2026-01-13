/// POD file system operations for GeoPod.
///
/// High-level file system API for reading and writing files in the POD.
/// This implementation does NOT use encryption - files are stored as plain text.
///
// Time-stamp: <2026-01-01 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:geopod/services/pod/pod_auth.dart';
import 'package:geopod/services/pod/pod_http.dart';
import 'package:geopod/services/pod/pod_path.dart';

/// Result of a file operation.
class FileOperationResult {
  final bool success;
  final String? content;
  final String? error;

  const FileOperationResult({required this.success, this.content, this.error});

  factory FileOperationResult.ok([String? content]) =>
      FileOperationResult(success: true, content: content);

  factory FileOperationResult.fail(String error) =>
      FileOperationResult(success: false, error: error);
}

/// High-level POD file system operations.
///
/// Provides simple read/write operations without encryption.
class PodFileSystem {
  PodFileSystem._();

  /// Read a file from the POD.
  ///
  /// [relativePath] - Path relative to the data directory.
  /// Example: `places/places.json`
  ///
  /// Returns the file content as a string, or null if file doesn't exist.
  static Future<String?> readFile(String relativePath) async {
    if (!await PodAuth.isLoggedIn()) {
      debugPrint('PodFileSystem.readFile() - not logged in');
      return null;
    }

    try {
      final url = await PodPath.getFileUrl(relativePath);
      final response = await PodHttp.get(url, accept: PodContentType.any);

      if (response.isSuccess) {
        return response.body;
      } else if (response.isNotFound) {
        debugPrint('PodFileSystem.readFile() - file not found: $relativePath');
        return null;
      } else {
        debugPrint(
          'PodFileSystem.readFile() - error ${response.statusCode}: ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('PodFileSystem.readFile() - exception: $e');
      return null;
    }
  }

  /// Write a file to the POD.
  ///
  /// [relativePath] - Path relative to the data directory.
  /// [content] - Content to write.
  /// [contentType] - MIME type of the content.
  /// [createParentDirs] - Whether to create parent directories if missing.
  ///
  /// Returns true if write was successful.
  static Future<bool> writeFile(
    String relativePath,
    String content, {
    PodContentType contentType = PodContentType.json,
    bool createParentDirs = true,
  }) async {
    if (!await PodAuth.isLoggedIn()) {
      debugPrint('PodFileSystem.writeFile() - not logged in');
      return false;
    }

    try {
      final url = await PodPath.getFileUrl(relativePath);

      // Check if parent directory exists and create if needed
      if (createParentDirs) {
        final parentPath = PodPath.getParentPath(
          PodPath.getFilePath(relativePath),
        );
        await _ensureDirectoryExists(parentPath);
      }

      final response = await PodHttp.put(
        url,
        content,
        contentType: contentType,
      );

      if (response.isSuccess) {
        debugPrint('PodFileSystem.writeFile() - success: $relativePath');
        return true;
      } else {
        debugPrint(
          'PodFileSystem.writeFile() - error ${response.statusCode}: ${response.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('PodFileSystem.writeFile() - exception: $e');
      return false;
    }
  }

  /// Delete a file from the POD.
  ///
  /// [relativePath] - Path relative to the data directory.
  ///
  /// Returns true if deletion was successful.
  static Future<bool> deleteFile(String relativePath) async {
    if (!await PodAuth.isLoggedIn()) {
      debugPrint('PodFileSystem.deleteFile() - not logged in');
      return false;
    }

    try {
      final url = await PodPath.getFileUrl(relativePath);
      final response = await PodHttp.delete(url);

      if (response.isSuccess || response.isNotFound) {
        debugPrint('PodFileSystem.deleteFile() - success: $relativePath');
        return true;
      } else {
        debugPrint(
          'PodFileSystem.deleteFile() - error ${response.statusCode}: ${response.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('PodFileSystem.deleteFile() - exception: $e');
      return false;
    }
  }

  /// Check if a file exists in the POD.
  ///
  /// [relativePath] - Path relative to the data directory.
  static Future<bool> fileExists(String relativePath) async {
    if (!await PodAuth.isLoggedIn()) {
      return false;
    }

    try {
      final url = await PodPath.getFileUrl(relativePath);
      final status = await PodHttp.checkStatus(url);
      return status == ResourceStatus.exist;
    } catch (e) {
      debugPrint('PodFileSystem.fileExists() - exception: $e');
      return false;
    }
  }

  /// Check if a directory exists in the POD.
  ///
  /// [relativePath] - Path relative to the data directory.
  static Future<bool> directoryExists(String relativePath) async {
    if (!await PodAuth.isLoggedIn()) {
      return false;
    }

    try {
      final url = await PodPath.getDirUrl(relativePath);
      final status = await PodHttp.checkStatus(url);
      return status == ResourceStatus.exist;
    } catch (e) {
      debugPrint('PodFileSystem.directoryExists() - exception: $e');
      return false;
    }
  }

  /// Create a directory in the POD.
  ///
  /// [relativePath] - Path relative to the data directory.
  ///
  /// Returns true if creation was successful.
  static Future<bool> createDirectory(String relativePath) async {
    if (!await PodAuth.isLoggedIn()) {
      debugPrint('PodFileSystem.createDirectory() - not logged in');
      return false;
    }

    try {
      return await _ensureDirectoryExists(PodPath.getFilePath(relativePath));
    } catch (e) {
      debugPrint('PodFileSystem.createDirectory() - exception: $e');
      return false;
    }
  }

  /// Ensure a directory exists, creating it and any parent directories if needed.
  static Future<bool> _ensureDirectoryExists(String dirPath) async {
    // Split path into parts and create each level
    final parts = dirPath.split('/').where((p) => p.isNotEmpty).toList();

    var currentPath = '';
    for (var i = 0; i < parts.length; i++) {
      currentPath += '${parts[i]}/';

      final url = await _getAbsoluteUrl(currentPath);
      final status = await PodHttp.checkStatus(url);

      if (status == ResourceStatus.notExist) {
        // Get parent URL and create this directory
        final parentPath = i == 0 ? '' : '${parts.sublist(0, i).join('/')}/';
        final parentUrl = await _getAbsoluteUrl(
          parentPath.isEmpty ? '' : parentPath,
        );
        final actualParentUrl = parentPath.isEmpty
            ? (await PodAuth.getPodBaseUrl())!
            : parentUrl;

        final response = await PodHttp.post(
          actualParentUrl,
          parts[i],
          '',
          isDirectory: true,
        );

        if (!response.isSuccess) {
          debugPrint(
            'PodFileSystem._ensureDirectoryExists() - failed to create: $currentPath',
          );
          return false;
        }
        debugPrint(
          'PodFileSystem._ensureDirectoryExists() - created: $currentPath',
        );
      } else if (status == ResourceStatus.forbidden) {
        debugPrint(
          'PodFileSystem._ensureDirectoryExists() - forbidden: $currentPath',
        );
        return false;
      }
    }

    return true;
  }

  /// Get absolute URL for a path (without normalizing through getFilePath).
  static Future<String> _getAbsoluteUrl(String path) async {
    final baseUrl = await PodAuth.getPodBaseUrl();
    if (baseUrl == null) {
      throw Exception('Not authenticated');
    }
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$baseUrl$cleanPath';
  }
}
