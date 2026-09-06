/// Widget for listing external places shared with the user.
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

import 'package:geopod/models/external_place.dart';
import 'package:geopod/widgets/sharing/view_external_place.dart';

/// A list view for places shared with the current user.

class ListExternalPlaces extends StatefulWidget {
  const ListExternalPlaces({
    super.key,
    required this.places,
    required this.onRefresh,
    this.listPage,
  });

  /// The list of shared places to display.
  final List<FoundExternalPlace> places;

  /// Callback to refresh data.
  final VoidCallback onRefresh;

  /// The parent page widget to return to.
  final Widget? listPage;

  @override
  State<ListExternalPlaces> createState() => _ListExternalPlacesState();
}

class _ListExternalPlacesState extends State<ListExternalPlaces> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _filter = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FoundExternalPlace> get _filteredPlaces {
    if (_filter.isEmpty) return widget.places;
    return widget.places.where((p) {
      final title = p.content?.displayTitle.toLowerCase() ?? '';
      final note = p.content?.note.toLowerCase() ?? '';
      final address = p.content?.address?.toLowerCase() ?? '';
      final granter = p.permissionGranter.toLowerCase();
      final owner = p.placeOwner.toLowerCase();
      final file = p.placeFileName.toLowerCase();
      return title.contains(_filter) ||
          note.contains(_filter) ||
          address.contains(_filter) ||
          granter.contains(_filter) ||
          owner.contains(_filter) ||
          file.contains(_filter);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredPlaces;

    return Column(
      children: [
        // ── Search bar ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search shared places...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _filter.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        // ── Places count & refresh ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${filtered.length} shared location${filtered.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh',
                onPressed: widget.onRefresh,
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // ── List of places ───────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    _filter.isEmpty
                        ? 'No shared places found.'
                        : 'No places match "$_filter".',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _SharedPlaceCard(
                      item: item,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ViewExternalPlace(
                            place: item,
                            listPage: widget.listPage,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Card representing a single shared place in the list.

class _SharedPlaceCard extends StatelessWidget {
  const _SharedPlaceCard({required this.item, required this.onTap});

  final FoundExternalPlace item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final content = item.content;
    final title = content?.displayTitle ?? item.placeFileName;
    final permissions = item.permissionList.split(',').map((s) => s.trim());

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.deepPurple.shade100,
                    child: Icon(
                      Icons.share_location,
                      color: Colors.deepPurple.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (content?.address != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            content!.address!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.person_pin,
                              size: 14,
                              color: Colors.blueGrey.shade400,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Shared by: ${item.permissionGranter}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blueGrey.shade700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: permissions.map((perm) {
                  return Chip(
                    label: Text(perm, style: const TextStyle(fontSize: 10)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
