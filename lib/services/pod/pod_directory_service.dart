/// POD directory listing service for GeoPod.
///
/// Provides directory listing functionality without encryption.
/// Includes caching for better performance.
///
// Time-stamp: <2026-01-01 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/foundation.dart' show ValueNotifier, debugPrint;

import 'package:http/http.dart' as http;

import 'package:geopod/models/pod_file_item.dart';
import 'package:geopod/services/pod/pod.dart';

/// Cache expiry duration.

const Duration _cacheExpiry = Duration(minutes: 2);

/// Notifier for file system changes.
/// Increments when files are added, deleted, or modified.
/// UI components can listen to this to refresh their views.

final podFilesChangeNotifier = ValueNotifier<int>(0);

/// Service for listing and managing POD directories.

class PodDirectoryService {
  PodDirectoryService._();

  /// Directory cache: path -> (items, timestamp)

  static final Map<String, (List<PodFileItem>, DateTime)> _cache = {};

  /// Notify listeners that the file system has changed.
  /// This only notifies UI components to refresh their views.
  /// Use invalidateCache() to clear specific cache entries before calling this.

  static void notifyChange() {
    podFilesChangeNotifier.value++;
  }

  /// Clear all cached data.

  static void clearCache() {
    _cache.clear();
  }

  /// Clear cache for a specific path and its parent.

  static void invalidateCache(String path) {
    _cache.remove(path);

    // Also invalidate parent directory.
    final parentPath = PodPath.getParentPath(path);
    if (parentPath != path) {
      _cache.remove(
        parentPath.endsWith('/')
            ? parentPath.substring(0, parentPath.length - 1)
            : parentPath,
      );
    }
  }

  /// Remove an item from the cache (used after deletion).

  static void removeFromCache(String itemPath) {
    // Find the parent directory in cache and remove the item.
    final parentPath = _getParentFromItemPath(itemPath);
    final cached = _cache[parentPath];
    if (cached != null) {
      final (items, timestamp) = cached;
      final updated = items.where((i) => i.path != itemPath).toList();
      _cache[parentPath] = (updated, timestamp);
    }
  }

  /// Get parent path from an item path.

  static String _getParentFromItemPath(String itemPath) {
    final lastSlash = itemPath.lastIndexOf('/');
    if (lastSlash <= 0) return '';
    return itemPath.substring(0, lastSlash);
  }

  /// List contents of a directory in the POD.
  ///
  /// [relativePath] - Path relative to the app directory (e.g., 'data/places').
  ///   Empty string means app root directory (geopod/).
  /// [forceRefresh] - If true, bypass cache and fetch fresh data.
  /// Returns a list of [PodFileItem] representing files and directories.

  static Future<List<PodFileItem>> listDirectory(
    String relativePath, {
    bool forceRefresh = false,
  }) async {
    // Check cache first (unless forcing refresh)
    if (!forceRefresh) {
      final cached = _cache[relativePath];
      if (cached != null) {
        final (items, timestamp) = cached;
        if (DateTime.now().difference(timestamp) < _cacheExpiry) {
          return List.from(items); // Return a copy
        }
      }
    }

    try {
      // Build the directory URL.
      String dirUrl = await PodPath.getDirUrl(relativePath);

      // Ensure URL ends with /

      if (!dirUrl.endsWith('/')) {
        dirUrl = '$dirUrl/';
      }

      // Get authentication tokens.
      final tokens = await PodAuth.getTokens(dirUrl, 'GET');

      // Make the request with proper headers (matching solidpod's implementation).
      // Cache-Control and Pragma headers instruct the browser (Flutter Web) and
      // any intermediate proxy NOT to serve a cached copy.  Without these, the
      // browser's HTTP cache will return a stale directory listing even when
      // forceRefresh is true, making the refresh button appear broken.
      final response = await http.get(
        Uri.parse(dirUrl),
        headers: <String, String>{
          'Accept': '*/*',
          'Authorization': 'DPoP ${tokens.accessToken}',
          'Connection': 'keep-alive',
          'DPoP': tokens.dPopToken,
          'Cache-Control': 'no-cache, no-store',
          'Pragma': 'no-cache',
        },
      );

      if (response.statusCode == 404) {
        // Directory doesn't exist.
        debugPrint('PodDirectoryService: Directory not found');
        return [];
      }

      if (response.statusCode == 403) {
        debugPrint('PodDirectoryService: Access forbidden');
        throw Exception('Access denied to this directory');
      }

      if (response.statusCode != 200) {
        debugPrint(
          'PodDirectoryService: Failed with status ${response.statusCode}',
        );
        throw Exception('Failed to list directory: ${response.statusCode}');
      }

      // Parse the Turtle/RDF response to extract file list.
      final items = _parseTurtleResponse(response.body, relativePath);

      // Update cache.

      _cache[relativePath] = (List.from(items), DateTime.now());

      return items;
    } catch (e) {
      debugPrint('PodDirectoryService.listDirectory() error: $e');
      rethrow;
    }
  }

  /// Parse Turtle/RDF response to extract file and directory items.
  /// Uses the same heuristic as solidpod's _parseGetContainerResponse.

  static List<PodFileItem> _parseTurtleResponse(
    String responseBody,
    String basePath,
  ) {
    final items = <PodFileItem>[];
    final re = RegExp(
      '^<[^>]+>',
    ); // starts with <, ends with >, no > in between

    final lines = responseBody.split('\n');
    for (final line in lines) {
      if (line.startsWith('<') && !line.startsWith('<>')) {
        if (line.contains('ldp:Resource')) {
          final nameMatch = re.firstMatch(line)?.group(0);
          if (nameMatch == null) continue;

          final isDirectory = line.contains('ldp:Container');

          // Extract name: <NAME/> for dirs, <NAME> for files.

          String name;
          if (isDirectory) {
            // Remove < and />
            name = nameMatch.substring(1, nameMatch.length - 2);
          } else {
            // Remove < and >
            name = nameMatch.substring(1, nameMatch.length - 1);
          }

          // Skip ACL and meta files.

          if (name.endsWith('.acl') || name.endsWith('.meta')) {
            continue;
          }

          // Build relative path.
          final itemPath = basePath.isEmpty ? name : '$basePath/$name';

          items.add(
            PodFileItem(name: name, path: itemPath, isDirectory: isDirectory),
          );
        }
      }
    }

    // Sort: directories first, then files alphabetically.

    items.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return items;
  }

  /// Create a directory in the POD.
  ///
  /// [relativePath] - Path relative to the app data directory.

  static Future<bool> createDirectory(String relativePath) async {
    final success = await PodFileSystem.createDirectory(relativePath);
    if (success) {
      invalidateCache(relativePath);
      notifyChange(); // Notify listeners
    }
    return success;
  }

  /// Delete a file or directory from the POD.
  ///
  /// [relativePath] - Path relative to the app data directory.
  /// Also deletes the associated ACL file if it exists.

  static Future<bool> delete(String relativePath) async {
    final success = await PodFileSystem.deleteFile(relativePath);
    if (success) {
      // Remove from cache immediately.
      removeFromCache(relativePath);
      notifyChange(); // Notify listeners

      // Also try to delete the ACL file (ignore errors)

      try {
        await PodFileSystem.deleteFile('$relativePath.acl');
      } catch (_) {
        // ACL file may not exist, ignore.
      }
    }
    return success;
  }

  /// Recursively delete a directory and ALL its contents.
  ///
  /// Lists the container, deletes every file and recursively deletes every
  /// sub-container in parallel, then deletes the container itself.
  ///
  /// [relativePath] - Path relative to the app data directory
  ///   (e.g. `'data/audio'`).
  ///
  /// Returns `true` when the entire subtree has been removed (or was already
  /// absent).  Individual file-delete failures are logged but do not abort the
  /// overall operation.

  static Future<bool> deleteDirectoryRecursive(String relativePath) async {
    try {
      // Fetch fresh listing — the directory may not exist at all.
      List<PodFileItem> items;
      try {
        items = await listDirectory(relativePath, forceRefresh: true);
      } catch (_) {
        // 404 or unreachable — treat as already gone.
        return true;
      }

      // Delete all children in parallel.
      await Future.wait(
        items.map((child) async {
          if (child.isDirectory) {
            await deleteDirectoryRecursive(child.path);
          } else {
            final ok = await PodFileSystem.deleteFile(child.path);
            if (!ok) {
              debugPrint(
                'PodDirectoryService.deleteDirectoryRecursive: '
                'failed to delete file ${child.path}',
              );
            }
          }
        }),
      );

      // Delete the (now-empty) container itself via a DELETE on its URL.
      final dirUrl = await PodPath.getDirUrl(relativePath);
      final response = await PodHttp.delete(dirUrl);
      final containerGone = response.isSuccess || response.isNotFound;

      // Evict from local cache regardless of server response.
      _cache.remove(relativePath);
      invalidateCache(relativePath);

      if (!containerGone) {
        debugPrint(
          'PodDirectoryService.deleteDirectoryRecursive: '
          'container delete failed (${response.statusCode}) – $relativePath',
        );
      }
      return containerGone;
    } catch (e) {
      debugPrint('PodDirectoryService.deleteDirectoryRecursive error: $e');
      return false;
    }
  }

  /// Check if a path exists in the POD.
  ///
  /// [relativePath] - Path relative to the app data directory.

  static Future<bool> exists(String relativePath) async {
    return await PodFileSystem.fileExists(relativePath);
  }

  /// Read file content from the POD.
  ///
  /// [relativePath] - Path relative to the app data directory.

  static Future<String?> readFile(String relativePath) async {
    return await PodFileSystem.readFile(relativePath);
  }

  /// Preload common directories into cache.
  /// Call this after login to make file browser feel instant.

  static Future<void> preload() async {
    try {
      // Check if already cached.
      if (_cache.containsKey('') && _cache.containsKey('data')) {
        return;
      }

      // Preload root directory and data directory in parallel.
      await Future.wait([
        listDirectory(''), // geopod/
        listDirectory('data'), // geopod/data/
        listDirectory('data/places'), // geopod/data/places/
      ]);
    } catch (e) {
      debugPrint('PodDirectoryService.preload: error $e');
    }
  }
}
