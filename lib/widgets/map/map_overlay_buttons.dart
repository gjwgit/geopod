/// Map overlay buttons widget.
///
// Time-stamp: <2025-12-08 Graham Williams>
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
/// Authors: Graham Williams, Miduo

library;

import 'package:flutter/material.dart';

/// Overlay button for adding places.
class AddPlaceOverlayButton extends StatelessWidget {
  final bool isLoading;
  final bool isLoggedIn;
  final VoidCallback? onTap;

  const AddPlaceOverlayButton({
    super.key,
    required this.isLoading,
    required this.isLoggedIn,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      left: 16,
      child: GestureDetector(
        onTap: isLoading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isLoggedIn
                ? Colors.green.withValues(alpha: 0.85)
                : Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: isLoggedIn
                ? Border.all(color: Colors.green.shade300, width: 1.5)
                : !isLoading
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isLoading
                    ? Icons.hourglass_empty
                    : isLoggedIn
                    ? Icons.add_location
                    : Icons.login,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                isLoading
                    ? 'Loading places...'
                    : isLoggedIn
                    ? 'Tap to Add Place'
                    : 'Login to add places',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: isLoggedIn ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Overlay button for toggling news markers.
class NewsOverlayButton extends StatelessWidget {
  final bool isLoadingNews;
  final bool showNewsMarkers;
  final int visibleNewsCount;
  final VoidCallback? onTap;

  const NewsOverlayButton({
    super.key,
    required this.isLoadingNews,
    required this.showNewsMarkers,
    required this.visibleNewsCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 68,
      left: 16,
      child: GestureDetector(
        onTap: isLoadingNews ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: showNewsMarkers
                ? Colors.blue.withValues(alpha: 0.85)
                : Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: showNewsMarkers
                ? Border.all(color: Colors.blue.shade300, width: 1.5)
                : Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoadingNews)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Icon(
                  showNewsMarkers ? Icons.article : Icons.article_outlined,
                  color: Colors.white,
                  size: 16,
                ),
              const SizedBox(width: 6),
              Text(
                isLoadingNews
                    ? 'Loading news...'
                    : showNewsMarkers
                    ? 'News: $visibleNewsCount'
                    : 'Show News',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: showNewsMarkers
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
