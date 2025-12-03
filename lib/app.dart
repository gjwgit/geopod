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

/// The root application widget.
class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  /// Flag to prevent multiple simultaneous auth attempts.
  bool _isProcessingAuth = false;

  @override
  void initState() {
    super.initState();
    // Schedule the auth check after the first frame to ensure context is ready.
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAuthFromUrl();
      });
    }
  }

  /// Check for OAuth callback code in URL and complete authentication.
  ///
  /// This method handles the OAuth redirect flow:
  /// 1. Checks if the URL contains a 'code' query parameter
  /// 2. Uses a lock flag to prevent concurrent auth attempts
  /// 3. Calls solidAuthenticate to complete the auth flow
  /// 4. Clears the URL query parameters to prevent re-authentication on refresh
  Future<void> _checkAuthFromUrl() async {
    final uri = Uri.base;
    final hasCode = uri.queryParameters.containsKey('code');

    // Only proceed if we have an auth code and aren't already processing.
    if (!hasCode || _isProcessingAuth) return;

    // Set lock to prevent multiple simultaneous calls.
    _isProcessingAuth = true;

    try {
      // Exchange the code for a token.
      // ignore: use_build_context_synchronously
      await solidAuthenticate(solidIssuer, context);

      // Clear the query parameters from the browser URL
      // to prevent re-authentication attempts on page refresh.
      _clearUrlQueryParams();
    } catch (e) {
      // Clear URL on error to prevent infinite loop with expired code.
      _clearUrlQueryParams();
    } finally {
      _isProcessingAuth = false;
    }
  }

  /// Clears the query parameters from the browser URL without triggering
  /// a page reload. This prevents the OAuth code from being reused.
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
    return SolidThemeApp(
      debugShowCheckedModeBanner: false,
      title: appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: SolidLogin(
        image: const AssetImage('assets/images/app_image.png'),
        logo: const AssetImage('assets/images/app_icon.png'),
        child: appScaffold,
      ),
    );
  }
}
