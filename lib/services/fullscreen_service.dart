/// Service for managing fullscreen mode state.
///
// Time-stamp: <Tuesday 2026-01-07 09:00:00 +1100>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/foundation.dart';

/// Global notifier for fullscreen mode state.
/// When true, sidebars and navigation elements should be hidden.
final ValueNotifier<bool> fullscreenModeNotifier = ValueNotifier<bool>(false);

/// Toggles the fullscreen mode on/off.
void toggleFullscreenMode() {
  fullscreenModeNotifier.value = !fullscreenModeNotifier.value;
}

/// Sets the fullscreen mode to a specific value.
void setFullscreenMode(bool value) {
  fullscreenModeNotifier.value = value;
}

/// Returns whether fullscreen mode is currently enabled.
bool get isFullscreenMode => fullscreenModeNotifier.value;
