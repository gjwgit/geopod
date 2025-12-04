/// The primary [MaterialApp] widget.
///
// Time-stamp: <2025-12-04 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program.  If not, see <https://opensource.org/license/gpl-3-0>.
///
/// Authors: Graham Williams, Miduo

library;

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:solidpod/solidpod.dart';
import 'package:solidui/solidui.dart';

import 'app_scaffold.dart';
import 'constants/app.dart';

// Conditionally import for web platform only.
import 'utils/web_utils_stub.dart'
    if (dart.library.html) 'utils/web_utils_web.dart'
    as web_utils;

/// The Solid server issuer URL for authentication.
const String solidIssuer = 'https://solidcommunity.au';

/// Timeout duration for authentication operations.
const Duration _authTimeout = Duration(seconds: 30);

/// The root application widget.
///
/// On web, this widget handles OAuth redirect callbacks by checking for
/// authorization codes in the URL and completing the authentication flow.
/// On desktop platforms, authentication is handled entirely by solidui.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    // On web, wrap with WebAuthHandler to process OAuth callbacks.
    // On desktop, use the standard SolidLogin flow directly.
    final loginWidget = SolidLogin(
      image: const AssetImage('assets/images/app_image.png'),
      logo: const AssetImage('assets/images/app_icon.png'),
      child: appScaffold,
    );

    return SolidThemeApp(
      debugShowCheckedModeBanner: false,
      title: appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: kIsWeb ? _WebAuthHandler(child: loginWidget) : loginWidget,
    );
  }
}

/// Handles OAuth redirect callbacks on web platform.
///
/// This widget checks for authorization codes in the URL query parameters
/// and completes the authentication flow by exchanging the code for tokens.
/// After successful authentication, it clears the URL to prevent re-auth
/// on page refresh.
///
/// Features:
/// - Robust error handling with try-catch-finally
/// - Timeout protection to avoid hanging
/// - Proper state reset on cancellation or failure
/// - Clear session data on error to allow fresh retry
class _WebAuthHandler extends StatefulWidget {
  const _WebAuthHandler({required this.child});

  final Widget child;

  @override
  State<_WebAuthHandler> createState() => _WebAuthHandlerState();
}

class _WebAuthHandlerState extends State<_WebAuthHandler> {
  /// Lock flag to prevent concurrent authentication attempts.
  /// CRITICAL: Must be reset in finally block to avoid permanent lock.
  bool _isProcessingAuth = false;

  /// Flag to track if authentication has been completed this session.
  bool _authCompleted = false;

  /// Flag to show loading indicator during auth processing.
  bool _showLoading = false;

  @override
  void initState() {
    super.initState();
    // Schedule the auth check after the first frame to ensure context is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthFromUrl();
    });
  }

  /// Displays a snackbar message to the user.
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.blue.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
  }

  /// Clears partial session data to allow fresh retry.
  ///
  /// This is crucial when authentication fails mid-way, leaving
  /// the session in an inconsistent state.
  Future<void> _clearPartialSession() async {
    try {
      // Use deleteLogIn to clear auth data without full logout.
      // This resets the auth state so user can try again.
      await deleteLogIn();
    } catch (e) {
      // Silently ignore errors during cleanup.
      debugPrint('Warning: Failed to clear partial session: $e');
    }
  }

  /// Check for OAuth callback code in URL and complete authentication.
  ///
  /// This method handles the OAuth redirect flow with robust error handling:
  /// 1. Checks if the URL contains a 'code' query parameter
  /// 2. Uses a lock flag to prevent concurrent auth attempts
  /// 3. Applies timeout to avoid hanging on slow responses
  /// 4. Handles null returns (user cancellation)
  /// 5. Clears URL query parameters to prevent re-authentication
  /// 6. Resets state in finally block regardless of outcome
  Future<void> _checkAuthFromUrl() async {
    final uri = Uri.base;
    final hasCode = uri.queryParameters.containsKey('code');

    // Only proceed if we have an auth code and aren't already processing.
    if (!hasCode || _isProcessingAuth || _authCompleted) {
      return;
    }

    // Set lock to prevent multiple simultaneous calls.
    // This will be reset in the finally block.
    setState(() {
      _isProcessingAuth = true;
      _showLoading = true;
    });

    try {
      // First, clear the URL immediately to prevent re-processing
      // on any rebuild or hot reload.
      _clearUrlQueryParams();

      // Check if already logged in (token might still be valid).
      final alreadyLoggedIn = await checkLoggedIn();
      if (alreadyLoggedIn) {
        _authCompleted = true;
        return;
      }

      // Attempt authentication with timeout protection.
      // ignore: use_build_context_synchronously
      final authResult = await solidAuthenticate(solidIssuer, context).timeout(
        _authTimeout,
        onTimeout: () {
          throw TimeoutException(
            'Authentication timed out after ${_authTimeout.inSeconds} seconds',
          );
        },
      );

      // Handle null result (user cancelled or error occurred).
      if (authResult == null) {
        // Show cancellation message.
        _showSnackBar(
          'Login was cancelled or failed. Please try again.',
          isError: true,
        );

        // Clear any partial session data to allow fresh retry.
        await _clearPartialSession();

        return;
      }

      // Success - mark as completed.
      _authCompleted = true;
    } on TimeoutException catch (e) {
      // Handle timeout specifically.
      debugPrint('Auth timeout: $e');
      _showSnackBar(
        'Login timed out. Please check your network and try again.',
        isError: true,
      );

      // Clear partial session on timeout.
      await _clearPartialSession();
    } catch (e) {
      // Handle all other errors.
      debugPrint('Auth error: $e');
      _showSnackBar(
        'Login failed: ${e.toString().replaceAll('Exception:', '').trim()}',
        isError: true,
      );

      // Clear partial session on error.
      await _clearPartialSession();
    } finally {
      // CRITICAL: Always reset the lock flag regardless of outcome.
      // This ensures the user can retry if something went wrong.
      if (mounted) {
        setState(() {
          _isProcessingAuth = false;
          _showLoading = false;
        });
      }
    }
  }

  /// Clears the query parameters from the browser URL.
  ///
  /// This prevents the OAuth code from being reused on page refresh,
  /// which would cause an error since codes are single-use.
  void _clearUrlQueryParams() {
    final uri = Uri.base;
    final cleanUrl = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.port,
      path: uri.path,
    ).toString();

    web_utils.replaceUrlState(cleanUrl);
  }

  @override
  Widget build(BuildContext context) {
    // Show loading overlay while processing authentication.
    if (_showLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Container(
            color: Colors.white,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 24),
                  Text(
                    'Completing login...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please wait while we verify your credentials.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
