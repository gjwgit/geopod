/// POD file browser widget for browsing files in the POD.
///
/// A complete file browser that doesn't depend on solidui's
/// security key encryption system.
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
import 'package:flutter/scheduler.dart';

import 'package:geopod/models/media_item.dart';
import 'package:geopod/models/pod_file_item.dart';
import 'package:geopod/services/media/media_pod_service.dart';
import 'package:geopod/services/places_service.dart';
import 'package:geopod/services/pod/pod.dart';
import 'package:geopod/widgets/pod/pod_browser_layouts.dart';
import 'package:geopod/widgets/pod/pod_dialogs.dart';

/// A file browser widget for browsing POD files.
///
/// This is a standalone implementation that doesn't depend on
/// solidui's complex security key system.

class PodFileBrowser extends StatefulWidget {
  /// Base path in the POD data directory (e.g., '' for root).
  final String basePath;

  /// Title to display in the app bar.
  final String title;

  const PodFileBrowser({super.key, this.basePath = '', this.title = 'Files'});

  @override
  State<PodFileBrowser> createState() => _PodFileBrowserState();
}

class _PodFileBrowserState extends State<PodFileBrowser> {
  /// Current directory path (relative to basePath).
  String _currentPath = '';

  /// List of items in current directory.

  List<PodFileItem> _items = [];

  /// Whether we're loading.

  bool _isLoading = true;

  /// Error message if any.

  String? _error;

  /// Currently selected file for preview.

  PodFileItem? _selectedFile;

  /// Path history for navigation.
  final List<String> _pathHistory = [''];

  /// Flag to skip podFilesChangeNotifier during our own delete operations.

  bool _skipFilesChangeNotification = false;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.basePath;
    _loadDirectory();

    // Listen for file system changes from other parts of the app.

    podFilesChangeNotifier.addListener(_onFilesChanged);
  }

  @override
  void dispose() {
    podFilesChangeNotifier.removeListener(_onFilesChanged);
    super.dispose();
  }

  /// Called when files change elsewhere in the app.

  void _onFilesChanged() {
    // Skip if we triggered this ourselves (during delete operations)
    if (_skipFilesChangeNotification) return;

    // Force refresh the current directory.

    _refreshDirectory();
  }

  Future<void> _loadDirectory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items = await PodDirectoryService.listDirectory(_currentPath);
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToDirectory(PodFileItem item) {
    if (!item.isDirectory) return;
    _pathHistory.add(_currentPath);
    setState(() {
      _currentPath = item.path;
      _selectedFile = null;
    });
    _loadDirectory();
  }

  void _navigateBack() {
    if (_pathHistory.isNotEmpty) {
      setState(() {
        _currentPath = _pathHistory.removeLast();
        _selectedFile = null;
      });
      _loadDirectory();
    }
  }

  void _navigateToRoot() {
    _pathHistory.clear();
    _pathHistory.add('');
    setState(() {
      _currentPath = widget.basePath;
      _selectedFile = null;
    });
    _loadDirectory();
  }

  void _selectFile(PodFileItem item) {
    if (item.isDirectory) return;
    if (item.isTextFile) {
      setState(() => _selectedFile = item);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cannot preview ${item.name}')));
    }
  }

  Future<void> _deleteFile(PodFileItem item) async {
    // Set flag to skip file change notifications during our delete operation.
    _skipFilesChangeNotification = true;

    try {
      if (PlacesService.isMainPlacesFile(item.path)) {
        if (!await showDeletePlacesConfirmation(context)) return;

        // Use addPostFrameCallback to avoid blocking animation.

        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _items.removeWhere((i) => i.path == item.path);
              _items.removeWhere(
                (i) => PlacesService.isIndividualPlaceFile(i.path),
              );
              if (_selectedFile?.path == item.path ||
                  PlacesService.isIndividualPlaceFile(
                    _selectedFile?.path ?? '',
                  )) {
                _selectedFile = null;
              }
            });
          }
        });
        if (!mounted) return;
        final success = await PlacesService.clearAllPlaces(context, widget);
        if (mounted) {
          showFileOperationSnackBar(
            context,
            message: success ? 'All places cleared' : 'Failed to clear places',
            success: success,
          );
          if (!success) _loadDirectory();
        }
        return;
      }

      if (PlacesService.isIndividualPlaceFile(item.path)) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _items.removeWhere((i) => i.path == item.path);
              if (_selectedFile?.path == item.path) _selectedFile = null;
            });
          }
        });
        final success = await PlacesService.deletePlaceByFilePath(
          item.path,
          context,
          widget,
        );
        if (mounted) {
          showFileOperationSnackBar(
            context,
            message: success
                ? 'Deleted ${item.name}'
                : 'Failed to delete ${item.name}',
            success: success,
          );
          if (!success) _loadDirectory();
        }
        return;
      }

      // ── Encrypted place file: enc_place_<id>.ttl ────────────────────────────
      // Route through EncryptedPlacesService so the aggregate is also updated.

      if (_isEncryptedPlaceFile(item.path)) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _items.removeWhere((i) => i.path == item.path);
              if (_selectedFile?.path == item.path) _selectedFile = null;
            });
          }
        });
        if (!mounted) return;
        final success =
            await EncryptedPlacesService.deleteEncryptedPlaceByFilePath(
              item.path,
              context,
              widget,
            );
        if (mounted) {
          showFileOperationSnackBar(
            context,
            message: success
                ? 'Deleted ${item.name}'
                : 'Failed to delete ${item.name}',
            success: success,
          );
          if (!success) _loadDirectory();
        }
        return;
      }

      // ── Audio / Video media file ─────────────────────────────────────────
      // Route through MediaPodService.deleteItem so the index AND the
      // in-memory cache are kept in sync (fixes the stale-link bug).

      if (_isAudioMediaFile(item.path) || _isVideoMediaFile(item.path)) {
        final mediaItem = await _findMediaItemByPath(item.path);
        if (mediaItem != null) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _items.removeWhere((i) => i.path == item.path);
                if (_selectedFile?.path == item.path) _selectedFile = null;
              });
            }
            if (mounted) showDeletingSnackBar(context, item.name);
          });
          final success = await MediaPodService.deleteItem(mediaItem);
          if (mounted) {
            showFileOperationSnackBar(
              context,
              message: success
                  ? 'Deleted ${item.name}'
                  : 'Failed to delete ${item.name}',
              success: success,
            );
            if (!success) _loadDirectory();
          }
          return;
        }
        // Not in index – fall through to generic delete below.
      }

      // ── Media index files (audio_index.json / video_index.json) ─────────────
      // These are NOT routed through MediaPodService.deleteItem() (they are
      // not MediaItems themselves), but deleting them must still invalidate
      // the in-memory cache so that subsequent listItems() calls re-fetch
      // rather than returning stale data.

      if (_isMediaIndexFile(item.path)) {
        final type = item.path.startsWith('data/audio/')
            ? MediaType.audio
            : MediaType.video;
        MediaPodService.clearCacheForType(type);
      }

      // Regular file deletion.

      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _items.removeWhere((i) => i.path == item.path);
            if (_selectedFile?.path == item.path) _selectedFile = null;
          });
        }
        if (mounted) showDeletingSnackBar(context, item.name);
      });

      final success = await PodDirectoryService.delete(item.path);
      if (mounted) {
        showFileOperationSnackBar(
          context,
          message: success
              ? 'Deleted ${item.name}'
              : 'Failed to delete ${item.name}',
          success: success,
        );
        if (!success) _loadDirectory();
      }
    } finally {
      // Always reset the flag.
      _skipFilesChangeNotification = false;
    }
  }

  // ── File-type detection helpers ────────────────────────────────────────

  /// Returns `true` for the audio or video index file itself.
  bool _isMediaIndexFile(String path) {
    return path == 'data/audio/audio_index.json' ||
        path == 'data/video/video_index.json';
  }

  /// Returns `true` for audio files (excluding the index file).
  bool _isAudioMediaFile(String path) {
    if (!path.startsWith('data/audio/')) return false;
    final n = path.split('/').last;
    return n != 'audio_index.json';
  }

  /// Returns `true` for video files (excluding the index file).
  bool _isVideoMediaFile(String path) {
    if (!path.startsWith('data/video/')) return false;
    final n = path.split('/').last;
    return n != 'video_index.json';
  }

  /// Returns `true` for individual encrypted place files (`enc_place_*.ttl`).
  bool _isEncryptedPlaceFile(String path) {
    final n = path.split('/').last;
    return n.startsWith('enc_place_') && n.endsWith('.ttl');
  }

  /// Looks up the [MediaItem] whose [MediaItem.podRelativePath] matches [path]
  /// in the in-memory index cache.  Returns `null` if not found.
  Future<MediaItem?> _findMediaItemByPath(String path) async {
    final type = _isAudioMediaFile(path) ? MediaType.audio : MediaType.video;
    final items = await MediaPodService.listItems(type);
    final idx = items.indexWhere((i) => i.podRelativePath == path);
    return idx >= 0 ? items[idx] : null;
  }

  Future<void> _refreshDirectory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await PodDirectoryService.listDirectory(
        _currentPath,
        forceRefresh: true,
      );
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 800;
    final isMediumScreen = screenWidth > 600;

    return Column(
      children: [
        BrowserToolbar(
          canGoBack: _canGoBack,
          canGoHome: _currentPath != widget.basePath,
          onBack: _navigateBack,
          onHome: _navigateToRoot,
          onRefresh: _refreshDirectory,
          breadcrumb: BrowserBreadcrumb(
            currentPath: _currentPath,
            onNavigateToRoot: _navigateToRoot,
            onNavigateToPath: _navigateToPath,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: isWideScreen
              ? WideLayoutView(
                  items: _items,
                  selectedFile: _selectedFile,
                  isLoading: _isLoading,
                  error: _error,
                  onDirectoryTap: _navigateToDirectory,
                  onFileTap: _selectFile,
                  onDelete: _deleteFile,
                  canDelete: _canDeleteItem,
                  onClearSelection: () => setState(() => _selectedFile = null),
                  onRetry: _loadDirectory,
                )
              : isMediumScreen
              ? MediumLayoutView(
                  items: _items,
                  selectedFile: _selectedFile,
                  isLoading: _isLoading,
                  error: _error,
                  onDirectoryTap: _navigateToDirectory,
                  onFileTap: _selectFile,
                  onDelete: _deleteFile,
                  canDelete: _canDeleteItem,
                  onClearSelection: () => setState(() => _selectedFile = null),
                  onRetry: _loadDirectory,
                )
              : _selectedFile != null
              ? MobilePreviewView(
                  selectedFile: _selectedFile!,
                  onBack: () => setState(() => _selectedFile = null),
                )
              : ListContentView(
                  items: _items,
                  isLoading: _isLoading,
                  error: _error,
                  onDirectoryTap: _navigateToDirectory,
                  onFileTap: _selectFile,
                  onDelete: _deleteFile,
                  canDelete: _canDeleteItem,
                  onRetry: _loadDirectory,
                ),
        ),
      ],
    );
  }

  /// Navigate to a specific path from breadcrumb.

  void _navigateToPath(String targetPath) {
    _pathHistory.add(_currentPath);
    setState(() {
      _currentPath = targetPath;
      _selectedFile = null;
    });
    _loadDirectory();
  }

  bool get _canGoBack => _pathHistory.isNotEmpty;

  /// Check if an item can be deleted.
  /// Only items in the data directory can be deleted.

  bool _canDeleteItem(PodFileItem item) {
    return PodPath.isDataPath(item.path);
  }
}
