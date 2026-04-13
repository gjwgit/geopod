/// Widget for sharing a place owned by the current user.
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

import 'package:geopod/models/place.dart';

/// A widget that wraps [GrantPermissionUi] so the user can grant Pod-level
/// access to a specific place file.
///
/// The individual place file is stored at path
/// `places/place_<id>.json` inside the app's data directory; solidpod
/// resolves this to `geopod/data/places/place_<id>.json` and creates the
/// corresponding `.acl` file.

class SharePlace extends StatelessWidget {
  const SharePlace({
    super.key,
    required this.place,
    required this.backPage,
  });

  /// The place to share.
  final Place place;

  /// The widget to return to when the user presses Back.
  final Widget backPage;

  @override
  Widget build(BuildContext context) {
    // resourceName is relative to the app's data directory.
    // For plain places solidpod normalises it to
    //   geopod/data/places/place_<id>.json
    // For encrypted places it resolves to
    //   geopod/data/encrypted_data/enc_place_<id>.ttl
    // solidpod's grantPermission() detects whether the file is encrypted
    // and automatically shares the individual encryption key with the
    // recipient (encrypted with their public key).
    final resourceName = place.isEncrypted
        ? 'encrypted_data/enc_place_${place.id}.ttl'
        : 'places/place_${place.id}.json';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Share Place',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: BackButton(
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => backPage),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Sharing: ${place.displayTitle}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                place.displayAddress,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: GrantPermissionUi(
                showAppBar: false,
                resourceName: resourceName,
                child: SharePlace(
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
