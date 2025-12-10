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
import 'services/places_service.dart';
import 'utils/web_utils_stub.dart'
    if (dart.library.html) 'utils/web_utils_web.dart'
    as web_utils;

/// The Solid server issuer URL for authentication.
const String solidIssuer = 'https://solidcommunity.au';

/// Timeout duration for authentication operations.
const Duration _authTimeout = Duration(seconds: 30);

/// The root application widget.
///
/// Uses SolidLogin from solidui for authentication UI, with additional
/// session verification to prevent false-positive login states.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final loginWidget = SolidLogin(
      image: const AssetImage('assets/images/app_image.png'),
      logo: const AssetImage('assets/images/app_icon.png'),
      child: appScaffold,
    );

    // Session status banner disabled - deemed redundant.
    // final loginWithStatus = _SessionStatusBanner(child: loginWidget);

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

// _SessionVerifier removed - no longer needed with guest mode and web reload on logout

/// Handles OAuth redirect callbacks on web platform.
class _WebAuthHandler extends StatefulWidget {
  const _WebAuthHandler({required this.child});

  final Widget child;

  @override
  State<_WebAuthHandler> createState() => _WebAuthHandlerState();
}

/// Authentication status for clear state management.
enum _AuthStatus { idle, processing, completed, failed }

class _WebAuthHandlerState extends State<_WebAuthHandler> {
  _AuthStatus _status = _AuthStatus.idle;
  int _rebuildKey = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processOAuthCallback();
    });
  }

  /// Processes OAuth callback from URL.
  Future<void> _processOAuthCallback() async {
    final uri = Uri.base;
    final hasCode = uri.queryParameters.containsKey('code');
    final hasError = uri.queryParameters.containsKey('error');

    if (hasError) {
      _clearUrl();
      unawaited(_resetSessionSilent());
      return;
    }

    if (!hasCode) {
      return;
    }

    if (_status == _AuthStatus.processing || _status == _AuthStatus.completed) {
      return;
    }

    setState(() => _status = _AuthStatus.processing);
    _clearUrl();

    try {
      final existingWebId = await getWebId();
      if (existingWebId != null && existingWebId.isNotEmpty) {
        setState(() => _status = _AuthStatus.completed);
        return;
      }

      // ignore: use_build_context_synchronously
      final result = await solidAuthenticate(solidIssuer, context).timeout(
        _authTimeout,
        onTimeout: () => throw TimeoutException('Timeout'),
      );

      if (result == null) {
        unawaited(_resetSessionSilent());
        return;
      }

      final webId = await getWebId();
      if (webId == null || webId.isEmpty) {
        unawaited(_resetSessionSilent());
        return;
      }

      debugPrint('_WebAuthHandler: Login successful, webId=$webId');

      // Preload places data in background to warm up cache
      // This makes the map page feel instant when user lands on it
      unawaited(preloadPlacesData());

      setState(() => _status = _AuthStatus.completed);
    } on TimeoutException {
      unawaited(_resetSessionSilent());
    } catch (_) {
      unawaited(_resetSessionSilent());
    }
  }

  /// Clears session silently and forces UI rebuild.
  Future<void> _resetSessionSilent() async {
    try {
      await deleteLogIn();
      // Clear all cached places when session reset fails
      await PlacesService.clearCache();
    } catch (_) {
      // Ignore errors.
    }

    if (mounted) {
      setState(() {
        _status = _AuthStatus.failed;
        _rebuildKey++;
      });
    }
  }

  /// Clears query parameters from browser URL.
  void _clearUrl() {
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
    if (_status == _AuthStatus.processing) {
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
                  SizedBox(height: 16),
                  Text('Completing login...'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return KeyedSubtree(key: ValueKey<int>(_rebuildKey), child: widget.child);
  }
}
