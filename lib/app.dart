/// The primary [MaterialApp] widget.
///
// Time-stamp: <Friday 2025-11-21 08:41:55 +1100 Graham Williams>
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
/// Authors: Graham Williams

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

// This widget is the root of the application.

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  /// Flag to prevent multiple simultaneous auth attempts.
  bool _isProcessingAuth = false;

  /// Flag to track authentication status.
  // ignore: unused_field
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    // Schedule the auth check after the first frame to ensure context is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthFromUrl();
    });
  }

  /// Check for OAuth callback code in URL and complete authentication.
  ///
  /// This method handles the OAuth redirect flow:
  /// 1. Checks if the URL contains a 'code' query parameter
  /// 2. Uses a lock flag to prevent concurrent auth attempts
  /// 3. Calls solidAuthenticate to complete the auth flow (exchanges code for token)
  /// 4. Clears the URL query parameters to prevent re-authentication on refresh
  /// 5. Updates the authenticated state on success
  Future<void> _checkAuthFromUrl() async {
    // Only process on web platform.
    if (!kIsWeb) return;

    // Get the current URL parameters.
    final uri = Uri.base;
    final hasCode = uri.queryParameters.containsKey('code');

    debugPrint('GeoPod: Checking URL for auth code...');
    debugPrint('GeoPod: Current URL: ${uri.toString()}');
    debugPrint('GeoPod: Has code: $hasCode');

    // Only proceed if we have an auth code and aren't already processing.
    if (!hasCode || _isProcessingAuth) {
      debugPrint(
        'GeoPod: Skipping auth - hasCode: $hasCode, isProcessing: $_isProcessingAuth',
      );
      return;
    }

    // Set lock to prevent multiple simultaneous calls.
    setState(() {
      _isProcessingAuth = true;
    });

    try {
      debugPrint('GeoPod: 检测到登录票据 (Code)，正在同步状态...');

      // 【核心对接点】调用 solidAuthenticate
      // 这个函数会做三件事：
      // a. 拿着 code 去 Solid 服务器换 Token
      // b. 把 Token 存入浏览器的 Secure Storage
      // c. 更新 SolidLoginStatus 所监听的内部状态
      // ignore: use_build_context_synchronously
      final authData = await solidAuthenticate(solidIssuer, context);

      debugPrint('GeoPod: solidAuthenticate returned: $authData');

      if (authData != null) {
        debugPrint('GeoPod: 认证成功！SolidLoginStatus 应该变绿了。');

        // CRITICAL: Clear the query parameters from the browser URL
        // to prevent re-authentication attempts on page refresh.
        _clearUrlQueryParams();

        // Update authenticated state and force UI refresh.
        if (mounted) {
          setState(() {
            _isAuthenticated = true;
          });
        }
      } else {
        debugPrint(
          'GeoPod: Authentication returned null - code may have expired.',
        );
        // Clear URL even if auth returned null to prevent infinite loop.
        _clearUrlQueryParams();
      }
    } catch (e, stackTrace) {
      debugPrint('GeoPod: 认证失败: $e');
      debugPrint('GeoPod: Stack trace: $stackTrace');
      // Clear URL even on error to prevent infinite loop with expired code.
      _clearUrlQueryParams();
    } finally {
      // Release the lock.
      if (mounted) {
        setState(() {
          _isProcessingAuth = false;
        });
      }
    }
  }

  /// Clears the query parameters from the browser URL without triggering
  /// a page reload. This prevents the OAuth code from being reused.
  void _clearUrlQueryParams() {
    if (!kIsWeb) return;

    final uri = Uri.base;
    // Build new URL without query parameters.
    final cleanUrl = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.port,
      path: uri.path,
      // Remove query and fragment to get clean URL.
    ).toString();

    // Use history.replaceState to update URL without reload.
    web_utils.replaceUrlState(cleanUrl);
    debugPrint('GeoPod: 已清除 URL 查询参数。');
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while processing auth.
    if (_isProcessingAuth) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  '正在完成登录...',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SolidThemeApp(
      // Turn off debug banner for now.
      debugShowCheckedModeBanner: false,
      title: appTitle,

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),

      // This is the usual Scaffold() that we then "seemlessly" replace with
      // SolidScaffold().
      home: SolidLogin(
        image: const AssetImage('assets/images/app_image.png'),
        logo: const AssetImage('assets/images/app_icon.png'),
        child: appScaffold,
      ),
    );
  }
}
