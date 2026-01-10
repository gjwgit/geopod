/// Dialog for displaying a list of news in the current map view.
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

/// Shows a dialog with the list of all news in current view.
Future<void> showNewsListDialog({
  required BuildContext context,
  required List<NewsMarker> visibleNewsMarkers,
  required VoidCallback onCloseNews,
  required void Function(NewsMarker newsMarker) onNewsMarkerTap,
}) async {
  await showDialog(
    context: context,
    builder: (dialogContext) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        height: 600,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.article, color: Colors.blue.shade700, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'News in Current View',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    // Only close dialog, keep news markers visible
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            ),
            const Divider(height: 20),
            Text(
              '${visibleNewsMarkers.length} news items in current view',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            // News list
            Expanded(
              child: visibleNewsMarkers.isEmpty
                  ? Center(
                      child: Text(
                        'No news found in this area',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.builder(
                      itemCount: visibleNewsMarkers.length,
                      itemBuilder: (context, index) {
                        final news = visibleNewsMarkers[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.shade700,
                              child: const Icon(
                                Icons.article,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              news.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                if (news.source != null)
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.public,
                                        size: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          news.source!,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${news.location.latitude.toStringAsFixed(2)}, ${news.location.longitude.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: news.url != null
                                ? IconButton(
                                    icon: const Icon(Icons.open_in_new),
                                    onPressed: () => _launchUrl(news.url!),
                                    tooltip: 'Read Article',
                                  )
                                : null,
                            onTap: () {
                              Navigator.of(dialogContext).pop();
                              onNewsMarkerTap(news);
                            },
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  onCloseNews();
                },
                icon: const Icon(Icons.close),
                label: const Text('Close News'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Launch URL in browser.
Future<void> _launchUrl(String url) async {
  try {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (_) {
    // Ignore errors
  }
}
