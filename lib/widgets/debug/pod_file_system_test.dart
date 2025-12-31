/// POD file system test widget.
///
/// A simple debug widget to test the new POD file system.
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

import 'package:geopod/services/pod/pod.dart';

/// Debug widget to test POD file system operations.
class PodFileSystemTest extends StatefulWidget {
  const PodFileSystemTest({super.key});

  @override
  State<PodFileSystemTest> createState() => _PodFileSystemTestState();
}

class _PodFileSystemTestState extends State<PodFileSystemTest> {
  final _log = <String>[];
  bool _isRunning = false;

  void _addLog(String message) {
    setState(() {
      _log.add(
        '[${DateTime.now().toIso8601String().substring(11, 19)}] $message',
      );
    });
  }

  Future<void> _runTests() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _log.clear();
    });

    try {
      // Test 1: Check authentication
      _addLog('=== Test 1: Authentication ===');
      final isLoggedIn = await PodAuth.isLoggedIn();
      _addLog('Logged in: $isLoggedIn');

      if (!isLoggedIn) {
        _addLog('❌ Please log in first');
        return;
      }

      final webId = await PodAuth.getWebId();
      _addLog('WebID: $webId');

      final baseUrl = await PodAuth.getPodBaseUrl();
      _addLog('POD Base URL: $baseUrl');

      // Test 2: Path utilities
      _addLog('\n=== Test 2: Path Utilities ===');
      _addLog('Data dir path: ${PodPath.getDataDirPath()}');
      _addLog('File path (test.json): ${PodPath.getFilePath('test.json')}');

      final testFileUrl = await PodPath.getFileUrl('test/test.json');
      _addLog('File URL: $testFileUrl');

      // Test 3: Write file
      _addLog('\n=== Test 3: Write File ===');
      final testContent =
          '{"test": "Hello from GeoPod!", "timestamp": "${DateTime.now()}"}';
      final writeSuccess = await PodFileSystem.writeFile(
        'test/test.json',
        testContent,
      );
      _addLog('Write result: ${writeSuccess ? "✅ Success" : "❌ Failed"}');

      // Test 4: Check file exists
      _addLog('\n=== Test 4: File Exists ===');
      final exists = await PodFileSystem.fileExists('test/test.json');
      _addLog('File exists: ${exists ? "✅ Yes" : "❌ No"}');

      // Test 5: Read file
      _addLog('\n=== Test 5: Read File ===');
      final content = await PodFileSystem.readFile('test/test.json');
      if (content != null) {
        _addLog('✅ Read success');
        _addLog('Content: $content');
      } else {
        _addLog('❌ Read failed');
      }

      // Test 6: Delete file
      _addLog('\n=== Test 6: Delete File ===');
      final deleteSuccess = await PodFileSystem.deleteFile('test/test.json');
      _addLog('Delete result: ${deleteSuccess ? "✅ Success" : "❌ Failed"}');

      // Verify deletion
      final existsAfterDelete = await PodFileSystem.fileExists(
        'test/test.json',
      );
      _addLog(
        'File exists after delete: ${existsAfterDelete ? "❌ Still exists" : "✅ Deleted"}',
      );

      _addLog('\n=== All Tests Complete ===');
    } catch (e, st) {
      _addLog('❌ Error: $e');
      _addLog('Stack trace: $st');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POD File System Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(() => _log.clear()),
            tooltip: 'Clear log',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _isRunning ? null : _runTests,
              icon: _isRunning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_isRunning ? 'Running...' : 'Run Tests'),
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _log.length,
              itemBuilder: (context, index) {
                final line = _log[index];
                Color? color;
                if (line.contains('✅')) {
                  color = Colors.green;
                } else if (line.contains('❌')) {
                  color = Colors.red;
                } else if (line.startsWith('[')) {
                  color = Colors.grey;
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    line,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: color,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
