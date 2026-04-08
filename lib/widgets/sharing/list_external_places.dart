/// Widget that lists external places shared with the current user.
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
import 'package:geopod/widgets/sharing/view_external_place.dart';

/// A stateful list widget for external places shared with the user.
///
/// Supports searching by file name, owner, granter, or permission list.

class ListExternalPlaces extends StatefulWidget {
  const ListExternalPlaces({
    super.key,
    required this.places,
    required this.listPage,
  });

  /// List of successfully loaded external places.
  final List<ExternalPlace> places;

  /// The list screen widget (passed through for Back navigation).
  final Widget listPage;

  @override
  State<ListExternalPlaces> createState() => _ListExternalPlacesState();
}

class _ListExternalPlacesState extends State<ListExternalPlaces> {
  late List<FoundExternalPlace> _foundPlaces;
  final TextEditingController _searchController = TextEditingController();
  bool _sortNameAscending = true;
  bool _sortOwnerAscending = true;

  @override
  void initState() {
    super.initState();
    _foundPlaces = widget.places.toListFoundExternalPlace();
    _sortByName(true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _sortByName(bool ascending) {
    setState(() {
      _sortNameAscending = ascending;
      _foundPlaces.sort((a, b) {
        final aName = a.content?.displayTitle ?? a.placeFileName;
        final bName = b.content?.displayTitle ?? b.placeFileName;
        return ascending
            ? aName.toLowerCase().compareTo(bName.toLowerCase())
            : bName.toLowerCase().compareTo(aName.toLowerCase());
      });
    });
  }

  void _sortByOwner(bool ascending) {
    setState(() {
      _sortOwnerAscending = ascending;
      _foundPlaces.sort((a, b) => ascending
          ? a.placeOwner.toLowerCase().compareTo(b.placeOwner.toLowerCase())
          : b.placeOwner.toLowerCase().compareTo(a.placeOwner.toLowerCase()));
    });
  }

  void _searchPlaces(String keyword) {
    final all = widget.places.toListFoundExternalPlace();
    setState(() {
      if (keyword.isEmpty) {
        _foundPlaces = all;
      } else {
        final kw = keyword.toLowerCase();
        _foundPlaces = all.where((p) {
          final name = (p.content?.displayTitle ?? p.placeFileName).toLowerCase();
          return name.contains(kw) ||
              p.placeOwner.toLowerCase().contains(kw) ||
              p.permissionGranter.toLowerCase().contains(kw) ||
              p.permissionList.toLowerCase().contains(kw);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.share, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'Places Shared With Me (${_foundPlaces.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // ── Search bar ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _searchController,
            onChanged: _searchPlaces,
            decoration: InputDecoration(
              hintText: 'Search by name, owner, or permissions…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _searchPlaces('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              isDense: true,
            ),
          ),
        ),

        // ── Sort row ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            children: [
              const Text('Sort:', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                ),
                icon: Icon(
                  _sortNameAscending
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  size: 14,
                ),
                label: const Text('Name', style: TextStyle(fontSize: 12)),
                onPressed: () => _sortByName(!_sortNameAscending),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                ),
                icon: Icon(
                  _sortOwnerAscending
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  size: 14,
                ),
                label: const Text('Owner', style: TextStyle(fontSize: 12)),
                onPressed: () => _sortByOwner(!_sortOwnerAscending),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // ── Place list ────────────────────────────────────────────────────
        Expanded(
          child: _foundPlaces.isEmpty
              ? const Center(
                  child: Text(
                    'No matching places found.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _foundPlaces.length,
                  itemBuilder: (context, index) {
                    final place = _foundPlaces[index];
                    return _ExternalPlaceCard(
                      place: place,
                      listPage: widget.listPage,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// A card tile for a single external place.

class _ExternalPlaceCard extends StatelessWidget {
  const _ExternalPlaceCard({
    required this.place,
    required this.listPage,
  });

  final FoundExternalPlace place;
  final Widget listPage;

  @override
  Widget build(BuildContext context) {
    final content = place.content;
    final accessModes = place.permissionList
        .split(',')
        .map((s) => s.trim())
        .toList();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.teal.shade400,
          child: const Icon(Icons.place, color: Colors.white),
        ),
        title: Text(
          content?.displayTitle ?? place.placeFileName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (content?.address != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.home_outlined, size: 13, color: Colors.blue.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      content!.shortAddress,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.person_outline, size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    place.placeOwner,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Wrap(
              spacing: 4,
              children: accessModes
                  .where((m) => m.isNotEmpty)
                  .map(
                    (m) => Chip(
                      label: Text(m, style: const TextStyle(fontSize: 10)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      backgroundColor: _modeColor(m),
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
        isThreeLine: true,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ViewExternalPlace(
              place: place,
              listPage: listPage,
            ),
          ),
        ),
      ),
    );
  }

  Color _modeColor(String mode) {
    switch (mode.toLowerCase()) {
      case 'read':
        return Colors.blue.shade400;
      case 'write':
        return Colors.orange.shade400;
      case 'append':
        return Colors.green.shade400;
      case 'control':
        return Colors.purple.shade400;
      default:
        return Colors.grey.shade400;
    }
  }
}
