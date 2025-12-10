/// Define the main entry point for the app.
///
// Time-stamp: <Friday 2025-11-21 09:08:56 +1100 Graham Williams>
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

import 'package:flutter/material.dart';

import 'package:solidpod/solidpod.dart' show KeyManager;
import 'package:solidui/solidui.dart';
import 'package:window_manager/window_manager.dart';

import 'package:geopod/app.dart';
import 'package:geopod/app_scaffold.dart';
import 'package:geopod/constants/app.dart';
import 'package:geopod/utils/is_desktop.dart';

/// Main entry point for the application.

void main() async {
  // We require [async] because we asynchronously [await] the window manager
  // below. Often, `main()` will include just the call [runApp].

  // Optionally we can globally remove [debugPrint] messages.
  //
  // debugPrint = (String? message, {int? wrapWidth}) {
  //   null;
  // };

  // Ensure Flutter bindings are initialized for async operations, in particular
  // to set the Linux desktop window [title].

  WidgetsFlutterBinding.ensureInitialized();
  
  // Configure SolidAuthHandler with app-specific settings
  // This ensures proper login page navigation when guest users want to authenticate
  SolidAuthHandler.instance.configure(
    SolidAuthConfig(
      appTitle: appTitle,
      appDirectory: 'geopod',
      defaultServerUrl: 'https://solidcommunity.au',
      appImage: const AssetImage('assets/images/app_image.png'),
      appLogo: const AssetImage('assets/images/app_icon.png'),
      loginSuccessWidget: appScaffold,
      // Clear security key on logout to ensure clean state
      onSecurityKeyReset: () async {
        await KeyManager.clear();
        debugPrint('GeoPod: Security key cleared on logout');
      },
    ),
  );
  
  if (isDesktop) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(title: appTitle);
    await windowManager.waitUntilReadyToShow(windowOptions, () async {});
  }

  // The runApp() function takes the given Widget and makes it the root of the
  // widget tree.

  runApp(const App());
}
