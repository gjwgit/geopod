/// Widget for re-sharing an externally owned place.
///
// Time-stamp: <2026-04-08 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';

import 'package:solidui/solidui.dart';

import 'package:geopod/models/external_place.dart';

/// Wraps [GrantPermissionUi] so the current user can re-share an external
/// place (i.e. a place owned by someone else that was shared with them and
/// for which they hold `control` permission).

class ShareExternalPlace extends StatelessWidget {
  const ShareExternalPlace({
    super.key,
    required this.place,
    required this.backPage,
  });

  /// The external place to re-share.
  final FoundExternalPlace place;

  /// The widget to return to when the user presses Back.
  final Widget backPage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Re-Share Place',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Re-sharing: ${place.content?.displayTitle ?? place.placeFileName}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Owner: ${place.placeOwner}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              // For external resources, resourceName must be the full URL
              // and isExternalRes must be true.
              child: GrantPermissionUi(
                showAppBar: false,
                resourceName: place.placeUrl,
                isExternalRes: true,
                ownerWebId: place.placeOwner,
                granterWebId: place.permissionGranter,
                child: ShareExternalPlace(
                  place: place,
                  backPage: backPage,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
