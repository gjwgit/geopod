/// Widget for files page with login check.
///
// Time-stamp: <Tuesday 2026-01-14 +1100>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';

import 'package:solidui/solidui.dart' show SolidAuthHandler;

import 'package:geopod/services/pod/pod.dart';
import 'package:geopod/utils/widget_utils.dart';
import 'package:geopod/widgets/pod/pod_file_browser.dart';

/// A widget that wraps PodFileBrowser with login state checking.
/// Shows a friendly login prompt when user is not logged in.

class FilesPage extends StatefulWidget {
  const FilesPage({super.key});

  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> with AuthStateManagement {
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    initAuthStateListener();
    addPostFrameCallback(this, _checkLoginStatus);
  }

  @override
  void dispose() {
    disposeAuthStateListener();
    super.dispose();
  }

  @override
  void onAuthStateChanged(bool isLoggedIn) {
    // State is already updated by mixin.
  }

  Future<void> _checkLoginStatus() async {
    await PodAuth.isLoggedIn(); // Verify login state
    safeSetState(this, () => _isChecking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!isLoggedIn) {
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

    // Use the new PodFileBrowser instead of SolidFile.
    return const PodFileBrowser(basePath: '', title: 'Files');
  }
}
