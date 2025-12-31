/// Widget for files page with login check.
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

import 'package:solidpod/solidpod.dart' show authStateNotifier;
import 'package:solidui/solidui.dart' show SolidAuthHandler;

import 'package:geopod/services/pod/pod.dart';
import 'package:geopod/widgets/pod/pod_file_browser.dart';

/// A widget that wraps PodFileBrowser with login state checking.
/// Shows a friendly login prompt when user is not logged in.
class FilesPage extends StatefulWidget {
  const FilesPage({super.key});

  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> {
  bool _isLoggedIn = true;

  @override
  void initState() {
    super.initState();
    // 优先使用同步检查，避免初始化时的异步阻塞
    _isLoggedIn = PodAuth.isLoggedInSync();

    // 监听登录状态变化
    authStateNotifier.addListener(_onAuthStateChanged);
  }

  @override
  void dispose() {
    authStateNotifier.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  void _onAuthStateChanged() {
    final loggedIn = authStateNotifier.value;
    if (loggedIn != _isLoggedIn && mounted) {
      setState(() => _isLoggedIn = loggedIn);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoggedIn) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Please log in to browse your files',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => SolidAuthHandler.instance.handleLogin(context),
              icon: const Icon(Icons.login),
              label: const Text('Login to View'),
            ),
          ],
        ),
      );
    }

    // Use the new PodFileBrowser instead of SolidFile
    return const PodFileBrowser(basePath: '', title: 'Files');
  }
}
