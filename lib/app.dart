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

import 'package:flutter/material.dart';

import 'package:solidui/solidui.dart';

import 'app_scaffold.dart';
import 'constants/app.dart';

// This widget is the root of the application.

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
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
