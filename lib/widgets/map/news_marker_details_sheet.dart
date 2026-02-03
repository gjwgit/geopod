/// Bottom sheet and dialog for displaying news marker details.
///
// Time-stamp: <Monday 2025-12-08 08:22:27 +1100 Graham Williams>
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

import 'package:url_launcher/url_launcher.dart';

import 'package:geopod/services/gdelt_news_service.dart';

/// Shows detailed information about a news marker in a bottom sheet.

void showNewsMarkerDetailsSheet(BuildContext context, NewsMarker newsMarker) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.all(18.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with news icon.
          Row(
            children: [
              Icon(
                Icons.article_outlined,
                color: Colors.blue.shade700,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'News Article',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // News title.
          Text(
            newsMarker.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          // Source and date.
          if (newsMarker.source != null || newsMarker.publishedAt != null)
            Row(
              children: [
                if (newsMarker.source != null) ...[
                  Icon(Icons.public, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    newsMarker.source!,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
                if (newsMarker.source != null && newsMarker.publishedAt != null)
                  Text(' • ', style: TextStyle(color: Colors.grey.shade600)),
                if (newsMarker.publishedAt != null) ...[
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateTime(newsMarker.publishedAt!),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ],
            ),

          // Tone indicator.
          if (newsMarker.tone != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  newsMarker.tone! > 0
                      ? Icons.sentiment_satisfied
                      : newsMarker.tone! < 0
                      ? Icons.sentiment_dissatisfied
                      : Icons.sentiment_neutral,
                  size: 16,
                  color: newsMarker.tone! > 0
                      ? Colors.green
                      : newsMarker.tone! < 0
                      ? Colors.red
                      : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  'Tone: ${newsMarker.tone!.toStringAsFixed(1)}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Location info.
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${newsMarker.location.latitude.toStringAsFixed(4)}, ${newsMarker.location.longitude.toStringAsFixed(4)}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Action buttons.
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Close'),
              ),
              if (newsMarker.url != null) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _launchUrl(context, newsMarker.url!);
                  },
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Read Article'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}

/// Format DateTime for display.

String _formatDateTime(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m ago';
  } else if (difference.inHours < 24) {
    return '${difference.inHours}h ago';
  } else if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  } else {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }
}

/// Launch URL in browser.

Future<void> _launchUrl(BuildContext context, String url) async {
  try {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch URL');
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open article: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }
}
