/// The primary [MaterialApp] widget.
///
// Time-stamp: <Thursday 2025-12-18 13:51:11 +1100 Graham Williams>
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

import 'package:flutter/material.dart';
import 'package:solidpod/solidpod.dart' show registerLogoutCacheCallback;
import 'package:solidui/solidui.dart';

import 'app_scaffold.dart';
import 'constants/app.dart';
import 'services/map_settings_service.dart';
import 'services/places_service.dart';

/// The root application widget.
///
/// Uses SolidLogin from solidui for authentication UI.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    // Register global callback for clearing caches during logout
    // This is called once at app startup to ensure caches are cleared
    // BEFORE any blocking network operations during logout
    registerLogoutCacheCallback(() async {
      await PlacesService.clearCache();
      // Note: MapSettings are user preferences, not user data,
      // so we don't clear them during logout
    });

    // Wrap appScaffold to ensure preload happens on navigation
    final appWithPreload = _AppScaffoldWrapper(child: appScaffold);

    final loginWidget = SolidLogin(
      image: const AssetImage('assets/images/app_image.png'),
      logo: const AssetImage('assets/images/app_icon.png'),
      child: appWithPreload,
    );

    return SolidThemeApp(
      debugShowCheckedModeBanner: false,
      title: appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: _StartupPreloader(child: loginWidget),
    );
  }
}

/// Preloads data on app startup for instant map page access.
/// All platforms use this for initial data preloading.
class _StartupPreloader extends StatefulWidget {
  const _StartupPreloader({required this.child});

  final Widget child;

  @override
  State<_StartupPreloader> createState() => _StartupPreloaderState();
}

class _StartupPreloaderState extends State<_StartupPreloader> {
  @override
  void initState() {
    super.initState();

    // Preload all data on app startup (both guests and logged-in users)
    // This makes the map page feel instant when user navigates to it
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(preloadPlacesData());
      unawaited(preloadMapSettings());
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Wrapper that triggers preload when navigated to (for Continue button).
/// This ensures data is preloaded even when user navigates via Continue button
/// after the initial app startup preload.
class _AppScaffoldWrapper extends StatefulWidget {
  const _AppScaffoldWrapper({required this.child});

  final Widget child;

  @override
  State<_AppScaffoldWrapper> createState() => _AppScaffoldWrapperState();
}

class _AppScaffoldWrapperState extends State<_AppScaffoldWrapper> {
  @override
  void initState() {
    super.initState();

    // Trigger preload when this widget is mounted
    // preloadPlacesData will skip if cache already exists
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(preloadPlacesData());
      unawaited(preloadMapSettings());
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
