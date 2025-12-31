/// POD path utilities for GeoPod.
///
/// Manages file and directory paths within the POD structure.
///
// Time-stamp: <2026-01-01 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:geopod/services/pod/pod_auth.dart';

/// Application directory name in the POD.
const String appDirName = 'geopod';

/// Data subdirectory name.
const String dataDir = 'data';

/// Provides path utilities for POD resources.
class PodPath {
  PodPath._();

  /// Get the data directory path.
  /// Returns: `geopod/data`
  static String getDataDirPath() => '$appDirName/$dataDir';

  /// Get full file path within the data directory.
  ///
  /// [relativePath] - Path relative to the data directory.
  /// Example: `places/places.json` → `geopod/data/places/places.json`
  static String getFilePath(String relativePath) {
    // Remove leading slash if present
    final cleanPath = relativePath.startsWith('/')
        ? relativePath.substring(1)
        : relativePath;

    // If path already includes app dir, return as-is
    if (cleanPath.startsWith('$appDirName/')) {
      return cleanPath;
    }

    // If path already includes data dir prefix, prepend app dir only
    if (cleanPath.startsWith('$dataDir/')) {
      return '$appDirName/$cleanPath';
    }

    return '${getDataDirPath()}/$cleanPath';
  }

  /// Get full URL for a file in the POD.
  ///
  /// [filePath] - Relative path to the file.
  /// Returns full URL like: `https://pod.server/geopod/data/places/places.json`
  static Future<String> getFileUrl(String filePath) async {
    final fullPath = getFilePath(filePath);
    return await PodAuth.getResourceUrl(fullPath, isContainer: false);
  }

  /// Get full URL for a directory in the POD.
  ///
  /// [dirPath] - Relative path to the directory.
  /// Returns full URL with trailing slash.
  static Future<String> getDirUrl(String dirPath) async {
    final fullPath = getFilePath(dirPath);
    return await PodAuth.getResourceUrl(fullPath, isContainer: true);
  }

  /// Extract relative path from a full POD URL.
  ///
  /// [url] - Full POD URL.
  /// Returns path relative to POD root.
  static String? extractPath(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
    } catch (_) {
      return null;
    }
  }

  /// Get parent directory path.
  ///
  /// [path] - File or directory path.
  /// Example: `geopod/data/places/places.json` → `geopod/data/places/`
  static String getParentPath(String path) {
    final cleanPath = path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    final lastSlash = cleanPath.lastIndexOf('/');
    if (lastSlash <= 0) return '/';
    return '${cleanPath.substring(0, lastSlash)}/';
  }
}
