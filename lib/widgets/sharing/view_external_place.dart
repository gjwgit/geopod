/// Widget for viewing the details of an external place.
///
// Time-stamp: <2026-04-08 Copilot>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';

import 'package:geopod/models/external_place.dart';
import 'package:geopod/widgets/sharing/share_external_place.dart';

/// A widget that shows the full details of an external place and provides
/// action buttons (re-share if control, back).

class ViewExternalPlace extends StatelessWidget {
  const ViewExternalPlace({
    super.key,
    required this.place,
    required this.listPage,
  });

  /// The external place to display.
  final FoundExternalPlace place;

  /// The page to return to (usually [ListExternalPlacesScreen]).
  final Widget listPage;

  @override
  Widget build(BuildContext context) {
    final accessModes = place.permissionList
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .toList();

    final content = place.content;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          content?.displayTitle ?? place.placeFileName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Place data ──────────────────────────────────────────────
              if (content != null) ...[
                const _SectionHeader(label: 'Place Details'),
                _DetailRow(
                  icon: Icons.label_outline,
                  label: 'Title',
                  value: content.displayTitle,
                ),
                _DetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'Coordinates',
                  value: content.coordinates,
                ),
                if (content.address != null)
                  _DetailRow(
                    icon: Icons.home_outlined,
                    label: 'Address',
                    value: content.address!,
                  ),
                _DetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Saved on',
                  value: content.formattedDate,
                ),
                if (content.note.isNotEmpty &&
                    content.note != content.displayTitle)
                  _DetailRow(
                    icon: Icons.notes_outlined,
                    label: 'Note',
                    value: content.note,
                  ),
                const SizedBox(height: 16),
              ] else ...[
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_outlined, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Place content could not be loaded.',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Sharing metadata ─────────────────────────────────────────
              const _SectionHeader(label: 'Sharing Details'),
              _DetailRow(
                icon: Icons.person_outline,
                label: 'Owner',
                value: place.placeOwner,
              ),
              _DetailRow(
                icon: Icons.share_outlined,
                label: 'Shared by',
                value: place.permissionGranter,
              ),
              _DetailRow(
                icon: Icons.access_time_outlined,
                label: 'Shared at',
                value: place.sharedTime,
              ),
              _DetailRow(
                icon: Icons.security_outlined,
                label: 'Permissions',
                value: place.permissionList,
              ),

              const SizedBox(height: 24),

              // ── Action buttons ────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Re-share button (only if current user has control)
                  if (accessModes.contains('control')) ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.share),
                      label: const Text('Re-Share'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ShareExternalPlace(
                            place: place,
                            backPage: ViewExternalPlace(
                              place: place,
                              listPage: listPage,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Back button
                  OutlinedButton.icon(
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple section heading.

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey.shade700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// A single label + value row used inside [ViewExternalPlace].

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.blueGrey.shade400),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
