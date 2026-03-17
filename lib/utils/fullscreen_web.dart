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
  // Reference [systemFullscreenChanges] so that dart_code_metrics does not
  // flag it as unused — the getter is used from
  // video_player_fullscreen_page.dart via a conditional import that the tool
  // cannot trace across.  assert() is compiled out in release mode.
  assert(systemFullscreenChanges.hashCode >= 0);
  if (web.document.fullscreenElement != null) {
    await web.document.exitFullscreen().toDart;
  }
}

/// Emits `true` when the browser enters fullscreen and `false` when it exits
/// (whether the user pressed ESC or code called [exitSystemFullscreen]).
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
