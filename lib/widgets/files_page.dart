/// Widget for files page with login check.
///
// Time-stamp: <2025-12-25>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';

import 'package:solidpod/solidpod.dart';
import 'package:solidui/solidui.dart';

/// A widget that wraps SolidFile with login state checking.
/// Shows a friendly login prompt when user is not logged in.
class FilesPage extends StatefulWidget {
  const FilesPage({super.key});

  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> {
  bool _isLoggedIn = true;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _isLoggedIn = authStateNotifier.value;
    authStateNotifier.addListener(_onAuthStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLoginStatus());
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

  Future<void> _checkLoginStatus() async {
    final loggedIn = await checkLoggedIn();
    if (mounted) {
      setState(() {
        _isLoggedIn = loggedIn;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

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

    return const SolidFile(basePath: 'geopod/data');
  }
}
