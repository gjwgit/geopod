/// Widget for sharing a place owned by the current user.
///
// Time-stamp: <2026-09-07 Amogh>
///
/// Copyright (C) 2025-2026, Software Innovation Institute, ANU.
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

class SharePlace extends StatelessWidget {
  const SharePlace({super.key, required this.place, this.backPage});

  /// The place to share.
  final Place place;

  /// The optional widget to return to when Back is pressed.
  final Widget? backPage;

  @override
  Widget build(BuildContext context) {
    final resourceName = place.isEncrypted
        ? 'encrypted_data/enc_place_${place.id}.ttl'
        : 'places/place_${place.id}.json';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Share ${place.displayTitle}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: BackButton(
          onPressed: () {
            if (backPage != null) {
              Navigator.of(
                context,
              ).pushReplacement(MaterialPageRoute(builder: (_) => backPage!));
            } else {
              Navigator.of(context).pop();
            }
          },
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
            if (place.address != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  place.address!,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: GrantPermissionUi(
                showAppBar: false,
                resourceNames: [resourceName],
                titleData: {resourceName: place.displayTitle},
                child: this,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
