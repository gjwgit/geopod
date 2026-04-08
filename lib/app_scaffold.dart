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
import 'services/fullscreen_service.dart';
import 'services/navigation_service.dart';
import 'widgets/audio_page.dart';
import 'widgets/files_page.dart';
import 'widgets/geomap.dart';
import 'widgets/locations_page.dart';
import 'widgets/sharing/list_external_places_screen.dart';
import 'widgets/video_page.dart';

/// App scaffold widget that responds to fullscreen mode changes.

class AppScaffoldWidget extends StatelessWidget {
  const AppScaffoldWidget({super.key});

  /// Global key to access the GeoMap state for settings dialog.

  static final GlobalKey<GeoMapWidgetState> geoMapKey =
      GlobalKey<GeoMapWidgetState>();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: fullscreenModeNotifier,
      builder: (context, isFullscreen, child) {
        if (isFullscreen) {
          // Fullscreen mode: show only the Home content without navigation.
          return Home(title: appTitle, geoMapKey: geoMapKey);
        }

        // Normal mode: show full scaffold with navigation.
        return _buildFullScaffold();
      },
    );
  }

  Widget _buildFullScaffold() {
    return ValueListenableBuilder<int>(
      valueListenable: currentPageNotifier,
      builder: (context, pageIndex, _) => SolidScaffold(
        selectedIndex: pageIndex,
        onMenuSelected: (index) => currentPageNotifier.value = index,
        // MENU.
        menu: [
          SolidMenuItem(
            icon: Icons.home,
            title: 'Home',
            tooltip: '''

            **Home:** Tap here to return to the main map page for the app.

            ''',
            child: Home(title: appTitle, geoMapKey: geoMapKey),
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
            icon: Icons.share,
            title: 'Shared',
            tooltip: '''

            **Shared:** Tap here to see places that other Pod users have shared
              with you. You can view the place details, coordinates, and your
              permission level. If you have control access, you can re-share
              the place with others.

            ''',
            child: ListExternalPlacesScreen(),
          ),
          const SolidMenuItem(
            icon: Icons.headphones,
            title: 'Audio',
            tooltip: '''

            **Audio:** Tap here to listen to and review audio commentary for
            specific locations of interest.

            ''',
            child: AudioPage(),
          ),
          const SolidMenuItem(
            icon: Icons.video_library,
            title: 'Video',
            tooltip: '''

            **Video:** Tap here to view and review videos for specific locations
              of interest.

            ''',
            child: VideoPage(),
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

        // APP BAR.
        appBar: SolidAppBarConfig(
          title: appTitle.split('-')[0],

          // VERSION.
          versionConfig: const SolidVersionConfig(
            changelogUrl:
                'https://raw.githubusercontent.com/gjwgit/geopod/dev/'
                'CHANGELOG.md',
            showDate: true,
          ),

          actions: [
            SolidAppBarAction(
              icon: Icons.settings,
              onPressed: () {
                // Call the GeoMap's settings dialog.
                AppScaffoldWidget.geoMapKey.currentState?.showSettingsDialog();
              },
              tooltip: 'Settings',
            ),
          ],
          overflowItems: [],
        ),

        // STATUS BAR.
        statusBar: const SolidStatusBarConfig(
          serverInfo: SolidServerInfo(
            serverUri: 'https://pods.solidcommunity.au',
          ),
          loginStatus: SolidLoginStatus(),
          securityKeyStatus: SolidSecurityKeyStatus(),
          showOnNarrowScreens: true, // Show status bar on Android/mobile
        ),

        // ABOUT.
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

        // THEME DARK/LIGHT Mode.
        themeToggle: const SolidThemeToggleConfig(
          enabled: true,
          showInAppBarActions: true,
        ),

        child: const Home(title: appTitle),
      ),
    );
  }
}

/// Convenience variable for backward compatibility.

final appScaffold = const AppScaffoldWidget();
