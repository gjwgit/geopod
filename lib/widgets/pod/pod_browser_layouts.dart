/// Layout widgets for POD file browser.
///
/// Contains reusable layout components for different screen sizes.
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
import 'package:geopod/widgets/pod/pod_file_list.dart';
import 'package:geopod/widgets/pod/pod_file_preview.dart';

/// Toolbar widget for POD file browser.

class BrowserToolbar extends StatelessWidget {
  final bool canGoBack;
  final bool canGoHome;
  final VoidCallback onBack;
  final VoidCallback onHome;
  final VoidCallback onRefresh;
  final Widget breadcrumb;

  const BrowserToolbar({
    super.key,
    required this.canGoBack,
    required this.canGoHome,
    required this.onBack,
    required this.onHome,
    required this.onRefresh,
    required this.breadcrumb,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: canGoBack ? onBack : null,
            tooltip: 'Back',
          ),
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: canGoHome ? onHome : null,
            tooltip: 'Go to root',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: onRefresh,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
          Expanded(child: breadcrumb),
        ],
      ),
    );
  }
}

/// Breadcrumb navigation widget for POD file browser.

class BrowserBreadcrumb extends StatelessWidget {
  final String currentPath;
  final VoidCallback onNavigateToRoot;
  final void Function(String path) onNavigateToPath;

  const BrowserBreadcrumb({
    super.key,
    required this.currentPath,
    required this.onNavigateToRoot,
    required this.onNavigateToPath,
  });

  @override
  Widget build(BuildContext context) {
    final parts = currentPath.isEmpty
        ? <String>[]
        : currentPath.split('/').where((p) => p.isNotEmpty).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          InkWell(
            onTap: onNavigateToRoot,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.folder, size: 16),
                  SizedBox(width: 4),
                  Text('geopod'),
                ],
              ),
            ),
          ),
          for (var i = 0; i < parts.length; i++) ...[
            const Text(' / ', style: TextStyle(color: Colors.grey)),
            InkWell(
              onTap: () {
                final targetPath = parts.sublist(0, i + 1).join('/');
                if (targetPath != currentPath) {
                  onNavigateToPath(targetPath);
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
}

/// A widget showing the file list and preview in wide layout (side by side).

class WideLayoutView extends StatelessWidget {
  final List<PodFileItem> items;
  final PodFileItem? selectedFile;
  final bool isLoading;
  final String? error;
  final void Function(PodFileItem) onDirectoryTap;
  final void Function(PodFileItem) onFileTap;
  final void Function(PodFileItem) onDelete;
  final bool Function(PodFileItem) canDelete;
  final VoidCallback onClearSelection;
  final VoidCallback onRetry;

  const WideLayoutView({
    super.key,
    required this.items,
    required this.selectedFile,
    required this.isLoading,
    required this.error,
    required this.onDirectoryTap,
    required this.onFileTap,
    required this.onDelete,
    required this.canDelete,
    required this.onClearSelection,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // File list (left panel)
        SizedBox(
          width: 350,
          child: ListContentView(
            items: items,
            isLoading: isLoading,
            error: error,
            onDirectoryTap: onDirectoryTap,
            onFileTap: onFileTap,
            onDelete: onDelete,
            canDelete: canDelete,
            onRetry: onRetry,
          ),
        ),
        const VerticalDivider(width: 1),

        // Preview (right panel)

        Expanded(
          child: selectedFile != null
              ? PodFilePreview(file: selectedFile!, onClose: onClearSelection)
              : const EmptyPreviewView(),
        ),
      ],
    );
  }
}

/// A widget showing the file list and preview in medium layout.

class MediumLayoutView extends StatelessWidget {
  final List<PodFileItem> items;
  final PodFileItem? selectedFile;
  final bool isLoading;
  final String? error;
  final void Function(PodFileItem) onDirectoryTap;
  final void Function(PodFileItem) onFileTap;
  final void Function(PodFileItem) onDelete;
  final bool Function(PodFileItem) canDelete;
  final VoidCallback onClearSelection;
  final VoidCallback onRetry;

  const MediumLayoutView({
    super.key,
    required this.items,
    required this.selectedFile,
    required this.isLoading,
    required this.error,
    required this.onDirectoryTap,
    required this.onFileTap,
    required this.onDelete,
    required this.canDelete,
    required this.onClearSelection,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // File list (narrower on medium screens)
        SizedBox(
          width: 280,
          child: ListContentView(
            items: items,
            isLoading: isLoading,
            error: error,
            onDirectoryTap: onDirectoryTap,
            onFileTap: onFileTap,
            onDelete: onDelete,
            canDelete: canDelete,
            onRetry: onRetry,
          ),
        ),
        const VerticalDivider(width: 1),

        // Preview.

        Expanded(
          child: selectedFile != null
              ? PodFilePreview(file: selectedFile!, onClose: onClearSelection)
              : const EmptyPreviewView(),
        ),
      ],
    );
  }
}

/// Mobile preview view with back button.

class MobilePreviewView extends StatelessWidget {
  final PodFileItem selectedFile;
  final VoidCallback onBack;

  const MobilePreviewView({
    super.key,
    required this.selectedFile,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Back to list button - more prominent on mobile.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  selectedFile.name,
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
            file: selectedFile,
            onClose: onBack,
            showHeader: false, // Hide header on mobile since we show it above
          ),
        ),
      ],
    );
  }
}

/// Empty preview placeholder.

class EmptyPreviewView extends StatelessWidget {
  const EmptyPreviewView({super.key});

  @override
  Widget build(BuildContext context) {
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
}

/// List content view with loading, error, and file list states.

class ListContentView extends StatelessWidget {
  final List<PodFileItem> items;
  final bool isLoading;
  final String? error;
  final void Function(PodFileItem) onDirectoryTap;
  final void Function(PodFileItem) onFileTap;
  final void Function(PodFileItem) onDelete;
  final bool Function(PodFileItem) canDelete;
  final VoidCallback onRetry;

  const ListContentView({
    super.key,
    required this.items,
    required this.isLoading,
    required this.error,
    required this.onDirectoryTap,
    required this.onFileTap,
    required this.onDelete,
    required this.canDelete,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Failed to load directory'),
            const SizedBox(height: 8),
            Text(
              error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }

    return PodFileList(
      items: items,
      onDirectoryTap: onDirectoryTap,
      onFileTap: onFileTap,
      onDelete: onDelete,
      canDelete: canDelete,
    );
  }
}
