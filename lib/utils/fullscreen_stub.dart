/// System fullscreen helpers — stub for NATIVE (non-web) platforms.
///
// Time-stamp: <2026-02-28 GitHub Copilot>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

/// Requests the OS/browser to enter true fullscreen.
/// On native platforms this is a no-op; fullscreen is handled via
/// [SystemChrome] in the caller.
Future<void> enterSystemFullscreen() async {}

/// Exits OS/browser fullscreen.
/// On native platforms this is a no-op.
Future<void> exitSystemFullscreen() async {}

/// A stream that emits [true] when fullscreen is entered and [false] when it
/// is exited (e.g. the user presses ESC).  On native platforms this stream
/// never emits; exit is detected via platform-specific key events instead.
Stream<bool> get systemFullscreenChanges => const Stream.empty();
