/// The primary [MaterialApp] widget.
///
// Time-stamp: <Friday 2025-11-21 08:42:00 +1100 Graham Williams>
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

            **Home:** Tap here to return to the main page for the app.

            ''',
      child: Home(title: appTitle),
    ),
    const SolidMenuItem(
      icon: Icons.interpreter_mode,
      title: 'Interests',
      tooltip: '''

            **Interests:** Tap here to access your life interests. You Movie
            interests are managed by the MovieStar app but you get a summary
            here.

            ''',
      child: Center(
        child: Text('Profile Page', style: TextStyle(fontSize: 24)),
      ),
    ),
    const SolidMenuItem(
      icon: Icons.headphones,
      title: 'Music',
      tooltip: '''

            **Music:** Tap here to listen to and review music from your music
              library.

            ''',
      child: Center(
        child: Text('Music Library', style: TextStyle(fontSize: 24)),
      ),
    ),
    const SolidMenuItem(
      icon: Icons.video_library,
      title: 'Video',
      tooltip: '''

            **Video:** Tap here to view and review videos from your video
              library.

            ''',
      child: Center(
        child: Text('Video Library', style: TextStyle(fontSize: 24)),
      ),
    ),
    const SolidMenuItem(
      icon: Icons.folder,
      title: 'Files',
      tooltip: '''

            **Files:** Tap here to browse the files on your POD.

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
          'https://github.com/gjwgit/book_of_life/blob/dev/'
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

          Your book of life is written by you. This app provides support for you
          to do just that, while retaining all your data encrypted and secure on
          a Solid server of your choice.

          With this app you can store your **important numbers** so they are
          available whenever you need them. Your **health data** can be
          populated here and shared with your doctor. All data is stored
          encrypted as a Pod in your Data Vault on a Solid Server of your
          choice.

          [Source code.](https://github.com/gjwgit/book_of_life)

          ''',
  ),

  // THEME DARK/LIGHT Mode
  themeToggle: const SolidThemeToggleConfig(
    enabled: true,
    showInAppBarActions: true,
  ),

  child: const Home(title: appTitle),
);
