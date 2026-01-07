/// Fullscreen toggle button overlay widget.
///
// Time-stamp: <Tuesday 2026-01-07 09:00:00 +1100>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';

import 'package:geopod/services/fullscreen_service.dart';

/// A semi-transparent fullscreen toggle button that appears in the corner.
/// When pressed, it toggles fullscreen mode and becomes opaque.
class FullscreenToggleButton extends StatelessWidget {
  const FullscreenToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: fullscreenModeNotifier,
      builder: (context, isFullscreen, child) {
        return Positioned(
          top: 16,
          right: 16,
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: toggleFullscreenMode,
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isFullscreen
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isFullscreen ? 0.3 : 0.15),
                        blurRadius: isFullscreen ? 8 : 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: isFullscreen
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.withValues(alpha: 0.3),
                      width: isFullscreen ? 2 : 1,
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                      key: ValueKey(isFullscreen),
                      size: 18,
                      color: isFullscreen
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
