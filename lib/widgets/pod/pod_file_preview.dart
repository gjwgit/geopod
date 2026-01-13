/// POD file preview widget for viewing file contents.
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
import 'package:flutter/services.dart';

import 'package:geopod/models/pod_file_item.dart';
import 'package:geopod/services/pod/pod.dart';

/// Widget for previewing file contents from the POD.
class PodFilePreview extends StatefulWidget {
  /// The file item to preview.
  final PodFileItem file;

  /// Callback when close is requested.
  final VoidCallback? onClose;

  /// Whether to show the header (filename, actions).
  /// Set to false on mobile when header is shown externally.
  final bool showHeader;

  const PodFilePreview({
    super.key,
    required this.file,
    this.onClose,
    this.showHeader = true,
  });

  @override
  State<PodFilePreview> createState() => _PodFilePreviewState();
}

class _PodFilePreviewState extends State<PodFilePreview> {
  bool _isLoading = true;
  String? _content;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContent();
    // Listen for file changes to auto-refresh
    podFilesChangeNotifier.addListener(_onFilesChanged);
  }

  @override
  void dispose() {
    podFilesChangeNotifier.removeListener(_onFilesChanged);
    super.dispose();
  }

  void _onFilesChanged() {
    // Reload content when files change
    if (mounted) {
      _loadContent();
    }
  }

  @override
  void didUpdateWidget(PodFilePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _loadContent();
    }
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final content = await PodFileSystem.readFile(widget.file.path);
      if (mounted) {
        setState(() {
          _content = content;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeader) ...[
          _buildHeader(context),
          const Divider(height: 1),
        ],
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Icon(_getFileIcon(), color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.file.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  widget.file.path,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          if (_content != null) ...[
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: _copyContent,
              tooltip: 'Copy content',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadContent,
              tooltip: 'Refresh',
            ),
          ],
          if (widget.onClose != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: widget.onClose,
              tooltip: 'Close',
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
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
            Text(
              'Failed to load file',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadContent, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_content == null) {
      return const Center(child: Text('No content available'));
    }

    // Check if it's JSON and format it nicely
    if (widget.file.extension == 'json') {
      return _buildJsonPreview();
    }

    // Default text preview
    return _buildTextPreview();
  }

  Widget _buildTextPreview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        _content!,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
    );
  }

  Widget _buildJsonPreview() {
    try {
      // Try to format JSON nicely
      final formatted = _formatJson(_content!);
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          formatted,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        ),
      );
    } catch (_) {
      return _buildTextPreview();
    }
  }

  String _formatJson(String json) {
    // Simple JSON formatting
    var indent = 0;
    final result = StringBuffer();
    var inString = false;

    for (var i = 0; i < json.length; i++) {
      final char = json[i];

      if (char == '"' && (i == 0 || json[i - 1] != '\\')) {
        inString = !inString;
        result.write(char);
      } else if (!inString) {
        switch (char) {
          case '{':
          case '[':
            result.write(char);
            indent += 2;
            result.write('\n');
            result.write(' ' * indent);
          case '}':
          case ']':
            indent -= 2;
            result.write('\n');
            result.write(' ' * indent);
            result.write(char);
          case ',':
            result.write(char);
            result.write('\n');
            result.write(' ' * indent);
          case ':':
            result.write(': ');
          case ' ':
          case '\n':
          case '\r':
          case '\t':
            // Skip whitespace
            break;
          default:
            result.write(char);
        }
      } else {
        result.write(char);
      }
    }

    return result.toString();
  }

  IconData _getFileIcon() {
    if (widget.file.isDirectory) return Icons.folder;

    switch (widget.file.extension) {
      case 'json':
        return Icons.data_object;
      case 'txt':
      case 'md':
        return Icons.description;
      case 'csv':
        return Icons.table_chart;
      default:
        return Icons.insert_drive_file;
    }
  }

  void _copyContent() {
    if (_content != null) {
      Clipboard.setData(ClipboardData(text: _content!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Content copied to clipboard')),
      );
    }
  }
}
