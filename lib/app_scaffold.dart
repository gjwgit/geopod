/// The primary [MaterialApp] widget.
///
// Time-stamp: <Friday 2025-11-21 09:25:41 +1100 Graham Williams>
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
      icon: Icons.interpreter_mode,
      title: 'Interests',
      tooltip: '''

            **Interests:** Tap here to access the list of points of interest you
              have access to. Here you can add and remove points and check those
              that are shared with you. You can also share your points of
              interest with other users through their Pods.

            ''',
      child: Center(
        child: Text(
          'RSN List of Points of Interest',
          style: TextStyle(fontSize: 24),
        ),
      ),
    ),
    const SolidMenuItem(
      icon: Icons.headphones,
      title: 'Audio',
      tooltip: '''

            **Audio:** Tap here to listen to and review audio commentary for the
              points of interest.

            ''',
      child: Center(
        child: Text(
          'RSN Library of Audio for Locations of Interest',
          style: TextStyle(fontSize: 24),
        ),
      ),
    ),
    const SolidMenuItem(
      icon: Icons.video_library,
      title: 'Video',
      tooltip: '''

            **Video:** Tap here to view and review videos for your points of
              interest.

            ''',
      child: Center(
        child: Text(
          'RSN Video Library for Locations of Interest',
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
      child: SolidFile(basePath: ''),
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
        icon: Icons.search,
        onPressed: () => debugPrint('Search'),
        tooltip: 'Search',
      ),
      SolidAppBarAction(
        icon: Icons.notifications,
        onPressed: () => debugPrint('Notifications'),
        tooltip: 'Notifications',
      ),
    ],
    overflowItems: [
      SolidOverflowMenuItem(
        id: 'help',
        icon: Icons.help,
        label: 'Help',
        onSelected: () => debugPrint('Help'),
      ),
    ],
  ),

  // STATUS BAR
  statusBar: const SolidStatusBarConfig(
    serverInfo: SolidServerInfo(serverUri: 'https://pods.solidcommunity.au'),
    loginStatus: SolidLoginStatus(),
    securityKeyStatus: SolidSecurityKeyStatus(),
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
