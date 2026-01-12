/// The primary app scaffold with navigation menu.
///
// Time-stamp: <Thursday 2025-12-18 14:36:37 +1100 Graham Williams>
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

import 'package:solidui/solidui.dart';

import 'constants/app.dart';
import 'home.dart';
import 'widgets/files_page.dart';
import 'widgets/locations_page.dart';

var appScaffold = SolidScaffold(
  // MENU
  menu: [
    const SolidMenuItem(
      icon: Icons.home,
      title: 'Home',
      tooltip: '''

            **Home:** Tap here to return to the main map page for the app.

            ''',
      child: Home(title: appTitle),
    ),
    const SolidMenuItem(
      icon: Icons.location_on,
      title: 'Locations',
      tooltip: '''

            **Locations:** Tap here to access the list of locations of interest
              you have access to. Here you can add and remove locations and
              check those that are shared with you. You can also share your
              locations of interest with other users through their Pods.

            ''',
      child: LocationsPage(),
    ),
    const SolidMenuItem(
      icon: Icons.headphones,
      title: 'Audio',
      tooltip: '''

            **Audio:** Tap here to listen to and review audio commentary for
            specific locations of interest.

            ''',
      child: Center(
        child: Text(
          'List of Audio for specific Locations of Interest',
          style: TextStyle(fontSize: 24),
        ),
      ),
    ),
    const SolidMenuItem(
      icon: Icons.video_library,
      title: 'Video',
      tooltip: '''

            **Video:** Tap here to view and review videos for specific locations
              of interest.

            ''',
      child: Center(
        child: Text(
          'Video Library for Locations of Interest',
          style: TextStyle(fontSize: 24),
        ),
      ),
    ),
    const SolidMenuItem(
      icon: Icons.folder,
      title: 'Files',
      tooltip: '''

            **Files:** Tap here to browse the files for the app on your Pod.

            ''',
      child: FilesPage(),
    ),
  ],

  // APP BAR
  appBar: SolidAppBarConfig(
    title: appTitle.split('-')[0],

    // VERSION
    versionConfig: const SolidVersionConfig(
      changelogUrl:
          'https://github.com/gjwgit/geopod/blob/dev/'
          'CHANGELOG.md',
      showDate: true,
    ),

    actions: [
      SolidAppBarAction(
        icon: Icons.settings,
        onPressed: () {
          // Call the GeoMap's settings dialog
          geoMapKey.currentState?.showSettingsDialog();
        },
        tooltip: 'Settings',
      ),
    ],
    overflowItems: [],
  ),

  // STATUS BAR
  statusBar: const SolidStatusBarConfig(
    serverInfo: SolidServerInfo(serverUri: 'https://pods.solidcommunity.au'),
    loginStatus: SolidLoginStatus(),
    securityKeyStatus: SolidSecurityKeyStatus(),
    showOnNarrowScreens: true, // Show status bar on Android/mobile
  ),

  // ABOUT
  aboutConfig: SolidAboutConfig(
    applicationName: appTitle.split(' - ')[0],
    applicationIcon: Image.asset(
      'assets/images/app_icon.png',
      width: 64, // Adjust size as needed
      height: 64,
    ),
    applicationLegalese: '''Copyright © 2025 Togaware Pty Ltd''',
    text: '''

          GeoPod provides a graphic maps-based interface to locations of
          interest that you have recorded or that are shared with you by their
          custodians.

          [Source code.](https://github.com/gjwgit/geopod)

          ''',
  ),

  // THEME DARK/LIGHT Mode
  themeToggle: const SolidThemeToggleConfig(
    enabled: true,
    showInAppBarActions: true,
  ),

  child: const Home(title: appTitle),
);
