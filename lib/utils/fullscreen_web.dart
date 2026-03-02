/// System fullscreen helpers — WEB implementation via HTML5 Fullscreen API.
///
// Time-stamp: <2026-02-28 Miduo>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Calls `document.documentElement.requestFullscreen()`.
/// The browser will show its own "Press ESC to exit" toast and handle ESC
/// natively — no Flutter-side key listener is needed on web.
Future<void> enterSystemFullscreen() async {
  final el = web.document.documentElement;
  if (el != null) await el.requestFullscreen().toDart;
}

/// Calls `document.exitFullscreen()`.
Future<void> exitSystemFullscreen() async {
  if (web.document.fullscreenElement != null) {
    await web.document.exitFullscreen().toDart;
  }
}

/// Emits `true` when the browser enters fullscreen and `false` when it exits
/// (whether the user pressed ESC or code called [exitSystemFullscreen]).
/// Used from video_player_fullscreen_page.dart (a `part` file of the
/// video_player_widget library).  The Dart analyser does not trace symbol
/// usage through `part` files when resolving conditional imports, so the
/// reference is invisible to the linter even though it is real.
// ignore: unused_element
Stream<bool> get systemFullscreenChanges {
  late StreamController<bool> controller;
  JSFunction? jsListener;

  controller = StreamController<bool>.broadcast(
    onListen: () {
      jsListener = ((web.Event _) {
        controller.add(web.document.fullscreenElement != null);
      }).toJS;
      web.document.addEventListener('fullscreenchange', jsListener);
    },
    onCancel: () {
      web.document.removeEventListener('fullscreenchange', jsListener);
      jsListener = null;
    },
  );
  return controller.stream;
}
