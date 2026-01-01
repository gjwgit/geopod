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

import 'package:geopod/models/pod_file_item.dart';
import 'package:geopod/services/places_service.dart';
import 'package:geopod/services/pod/pod.dart';
import 'package:geopod/widgets/pod/pod_file_list.dart';
import 'package:geopod/widgets/pod/pod_file_preview.dart';

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

  @override
  void initState() {
    super.initState();
    _currentPath = widget.basePath;
    _loadDirectory();

    // Listen for file system changes from other parts of the app
    podFilesChangeNotifier.addListener(_onFilesChanged);
  }

  @override
  void dispose() {
    podFilesChangeNotifier.removeListener(_onFilesChanged);
    super.dispose();
  }

  /// Called when files change elsewhere in the app.
  void _onFilesChanged() {
    // Force refresh the current directory
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
      setState(() {
        _selectedFile = item;
      });
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cannot preview ${item.name}')));
    }
  }

  Future<void> _deleteFile(PodFileItem item) async {
    // Check if this is a special places file
    if (PlacesService.isMainPlacesFile(item.path)) {
      // Show confirmation dialog for deleting main places file
      final confirmed = await _showDeletePlacesConfirmation();
      if (!confirmed) return;

      // Clear all places (this will delete places.json and all individual files)
      if (mounted) {
        setState(() {
          _items.removeWhere((i) => i.path == item.path);
          // Also remove all individual place files from the list
          _items.removeWhere(
            (i) => PlacesService.isIndividualPlaceFile(i.path),
          );
          if (_selectedFile?.path == item.path ||
              PlacesService.isIndividualPlaceFile(_selectedFile?.path ?? '')) {
            _selectedFile = null;
          }
        });
      }

      if (!mounted) return;
      final success = await PlacesService.clearAllPlaces(context, widget);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'All places cleared' : 'Failed to clear places',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        if (!success) _loadDirectory();
      }
      return;
    }

    if (PlacesService.isIndividualPlaceFile(item.path)) {
      // Delete individual place file - this also removes from places.json
      setState(() {
        _items.removeWhere((i) => i.path == item.path);
        if (_selectedFile?.path == item.path) {
          _selectedFile = null;
        }
      });

      final success = await PlacesService.deletePlaceByFilePath(
        item.path,
        context,
        widget,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Deleted ${item.name}'
                  : 'Failed to delete ${item.name}',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        if (!success) _loadDirectory();
      }
      return;
    }

    // Regular file deletion
    // Immediately remove from local list for better UX
    setState(() {
      _items.removeWhere((i) => i.path == item.path);
      if (_selectedFile?.path == item.path) {
        _selectedFile = null;
      }
    });

    // Show optimistic success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleting ${item.name}...'),
          duration: const Duration(seconds: 1),
        ),
      );
    }

    // Perform the actual delete
    final success = await PodDirectoryService.delete(item.path);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted ${item.name}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Failed - reload to restore the item
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete ${item.name}'),
            backgroundColor: Colors.red,
          ),
        );
        _loadDirectory(); // Reload to restore original state
      }
    }
  }

  /// Show confirmation dialog for deleting the main places.json file.
  Future<bool> _showDeletePlacesConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete All Places?'),
            content: const Text(
              'This will delete all your saved places data, including the main '
              'places.json file and all individual place files.\n\n'
              'This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete All'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _refreshDirectory() async {
    // Force refresh bypassing cache
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
        _buildToolbar(),
        const Divider(height: 1),
        Expanded(
          child: isWideScreen
              ? _buildWideLayout(screenWidth)
              : isMediumScreen
              ? _buildMediumLayout()
              : _selectedFile != null
              ? _buildPreviewOnly()
              : _buildListOnly(),
        ),
      ],
    );
  }

  /// Medium layout: narrower file list, wider preview
  Widget _buildMediumLayout() {
    return Row(
      children: [
        // File list (narrower on medium screens)
        SizedBox(width: 280, child: _buildListContent()),
        const VerticalDivider(width: 1),
        // Preview
        Expanded(
          child: _selectedFile != null
              ? PodFilePreview(
                  file: _selectedFile!,
                  onClose: () => setState(() => _selectedFile = null),
                )
              : _buildEmptyPreview(),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _canGoBack ? _navigateBack : null,
            tooltip: 'Back',
          ),
          // Home button
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: _currentPath != widget.basePath ? _navigateToRoot : null,
            tooltip: 'Go to root',
          ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshDirectory,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
          // Breadcrumb
          Expanded(child: _buildBreadcrumb()),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb() {
    final parts = _currentPath.isEmpty
        ? <String>[]
        : _currentPath.split('/').where((p) => p.isNotEmpty).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          InkWell(
            onTap: _navigateToRoot,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.folder, size: 16),
                  SizedBox(width: 4),
                  Text('geopod/data'),
                ],
              ),
            ),
          ),
          for (var i = 0; i < parts.length; i++) ...[
            const Text(' / ', style: TextStyle(color: Colors.grey)),
            InkWell(
              onTap: () {
                final targetPath = parts.sublist(0, i + 1).join('/');
                if (targetPath != _currentPath) {
                  _pathHistory.add(_currentPath);
                  setState(() {
                    _currentPath = targetPath;
                    _selectedFile = null;
                  });
                  _loadDirectory();
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  parts[i],
                  style: TextStyle(
                    fontWeight: i == parts.length - 1
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool get _canGoBack => _pathHistory.isNotEmpty;

  Widget _buildWideLayout(double screenWidth) {
    return Row(
      children: [
        // File list (left panel)
        SizedBox(width: 350, child: _buildListContent()),
        const VerticalDivider(width: 1),
        // Preview (right panel)
        Expanded(
          child: _selectedFile != null
              ? PodFilePreview(
                  file: _selectedFile!,
                  onClose: () => setState(() => _selectedFile = null),
                )
              : _buildEmptyPreview(),
        ),
      ],
    );
  }

  Widget _buildEmptyPreview() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 72,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Select a file to preview',
            style: TextStyle(
              color: Theme.of(context).colorScheme.outline,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Click on any file in the list',
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

  Widget _buildListOnly() {
    return _buildListContent();
  }

  Widget _buildPreviewOnly() {
    return Column(
      children: [
        // Back to list button - more prominent on mobile
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: () => setState(() => _selectedFile = null),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedFile!.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: PodFilePreview(
            file: _selectedFile!,
            onClose: () => setState(() => _selectedFile = null),
            showHeader: false, // Hide header on mobile since we show it above
          ),
        ),
      ],
    );
  }

  Widget _buildListContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Failed to load directory'),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDirectory,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return PodFileList(
      items: _items,
      onDirectoryTap: _navigateToDirectory,
      onFileTap: _selectFile,
      onDelete: _deleteFile,
    );
  }
}
