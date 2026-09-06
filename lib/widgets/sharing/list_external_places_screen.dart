/// Screen that asynchronously loads and displays external places.
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
import 'package:geopod/models/external_places_call_result.dart';
import 'package:geopod/services/sharing/sharing_service.dart';
import 'package:geopod/widgets/sharing/list_external_places.dart';

/// Screen for displaying places shared with the user.

class ListExternalPlacesScreen extends StatefulWidget {
  const ListExternalPlacesScreen({super.key});

  @override
  State<ListExternalPlacesScreen> createState() =>
      _ListExternalPlacesScreenState();
}

class _ListExternalPlacesScreenState extends State<ListExternalPlacesScreen> {
  late Future<ExternalPlacesCallResult> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = getExternalPlaceList();
  }

  void _reload() {
    invalidateExternalPlaceCache();
    setState(() {
      _dataFuture = getExternalPlaceList(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared Locations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _reload,
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<ExternalPlacesCallResult>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading shared locations...'),
                  ],
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load shared locations:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        onPressed: _reload,
                      ),
                    ],
                  ),
                ),
              );
            }

            final result = snapshot.data;
            final places = result?.places ?? [];

            if (places.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.share_location_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Shared Locations',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'When other Solid Pod users share location files '
                        'with your WebID, they will appear here and on '
                        'your map.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Check for Shares'),
                        onPressed: _reload,
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListExternalPlaces(
              places: places.toListFoundExternalPlace(),
              onRefresh: _reload,
              listPage: const ListExternalPlacesScreen(),
            );
          },
        ),
      ),
    );
  }
}
