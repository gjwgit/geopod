/// Action buttons for map settings dialog.
///
// Time-stamp: <2026-01-07 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';

import 'package:solidpod/solidpod.dart';
import 'package:solidui/solidui.dart';

import 'package:geopod/widgets/settings/encryption_key_operations.dart';

/// Builds the reset to defaults button.

Widget buildResetButton({required VoidCallback onReset}) {
  return Center(
    child: TextButton.icon(
      onPressed: onReset,
      icon: const Icon(Icons.restore, size: 18),
      label: const Text('Reset to Defaults'),
      style: TextButton.styleFrom(foregroundColor: Colors.grey),
    ),
  );
}

/// Builds the logout and debug buttons section.
/// Only visible when user is logged in.

Widget buildUserActionsSection(BuildContext context) {
  return FutureBuilder<String?>(
    future: getWebId(),
    builder: (context, snapshot) {
      final isLoggedIn = snapshot.data != null && snapshot.data!.isNotEmpty;
      if (!isLoggedIn) return const SizedBox.shrink();

      return Column(
        children: [
          Center(
            child: TextButton.icon(
              onPressed: () async {
                // Close settings dialog first.
                Navigator.pop(context);

                // Then handle logout.
                await SolidAuthHandler.instance.handleLogout(context);
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Logout'),
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
            ),
          ),
          const SizedBox(height: 8),

          // DEBUG: Delete encryption keys from server.
          Center(
            child: TextButton.icon(
              onPressed: () => deleteEncryptionKeys(context),
              icon: const Icon(Icons.delete_forever, size: 18),
              label: const Text('Delete Encryption Keys (DEBUG)'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange.shade700,
              ),
            ),
          ),
        ],
      );
    },
  );
}
