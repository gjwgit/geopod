/// Screen that asynchronously loads and displays external places.
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

import 'package:geopod/models/external_places_call_result.dart';
import 'package:geopod/services/places/encrypted_places_service.dart';
import 'package:geopod/services/sharing/sharing_service.dart';
import 'package:geopod/widgets/encryption/security_key_dialog.dart';
import 'package:geopod/widgets/sharing/list_external_places.dart';

/// A [StatefulWidget] that fetches external-place data in a [FutureBuilder]
/// and hands off to [ListExternalPlaces] once the data is ready.

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
    setState(() {
      // Force-refresh bypasses the in-memory TTL cache so the user always
      // gets the latest data when they explicitly request a reload.
      _dataFuture = getExternalPlaceList(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<ExternalPlacesCallResult>(
          future: _dataFuture,
          builder: (context, snapshot) {
            switch (snapshot.connectionState) {
              case ConnectionState.waiting:
              case ConnectionState.active:
                return const _LoadingView();

              case ConnectionState.done:
                if (snapshot.hasError) {
                  debugPrint(
                    '[ListExternalPlacesScreen] Error: ${snapshot.error}',
                  );
                  return _ErrorView(
                    message: snapshot.error.toString(),
                    onRetry: _reload,
                  );
                }

                final result = snapshot.data;
                if (result == null) {
                  return _EmptyView(onRefresh: _reload);
                }

                final places = result.places ?? [];
                final nonExistent = result.nonExistentPlaces ?? [];
                final forbidden = result.forbiddenPlaces ?? [];
                final encryptionErrors = result.encryptionErrorPlaces ?? [];
                final unparseable = result.unparseablePlaces ?? [];

                // If encrypted places failed to load due to missing security
                // key, auto-prompt the user once and then reload.
                if (encryptionErrors.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    if (!mounted) return;
                    final hasKey =
                        await EncryptedPlacesService.isSecurityKeyAvailable();
                    if (!mounted || hasKey) return;
                    final got = await showSecurityKeyDialog(this.context);
                    if (got && mounted) {
                      _reload();
                    }
                  });
                }

                // Notify about places whose source files have been deleted.
                if (nonExistent.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${nonExistent.length} shared place(s) no longer '
                          'exist on the owner\'s Pod.',
                        ),
                        action: SnackBarAction(
                          label: 'Dismiss',
                          onPressed: () {},
                        ),
                      ),
                    );
                  });
                }

                // Notify about places the current user has no access to.
                // This usually means the owner's ACL was not properly set,
                // or the sharing step completed only partially.
                if (forbidden.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: const Duration(seconds: 8),
                        content: Text(
                          '${forbidden.length} shared place(s) could not be '
                          'loaded: access denied. Ask the owner to re-share '
                          'the place with you.',
                        ),
                        action: SnackBarAction(
                          label: 'Dismiss',
                          onPressed: () {},
                        ),
                      ),
                    );
                  });
                }

                // Notify about encrypted places whose decryption key is missing.
                if (encryptionErrors.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: const Duration(seconds: 10),
                        content: Text(
                          '${encryptionErrors.length} encrypted place(s) '
                          'could not be decrypted. Ensure your security key '
                          'is set and refresh, or ask the owner to re-share.',
                        ),
                        action: SnackBarAction(
                          label: 'Refresh',
                          onPressed: _reload,
                        ),
                      ),
                    );
                  });
                }

                // Notify about places that could not be parsed.
                if (unparseable.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${unparseable.length} shared place(s) could not '
                          'be read (network or format error).',
                        ),
                        action: SnackBarAction(
                          label: 'Dismiss',
                          onPressed: () {},
                        ),
                      ),
                    );
                  });
                }

                if (places.isEmpty) {
                  return _EmptyView(onRefresh: _reload);
                }

                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListExternalPlaces(
                    places: places,
                    listPage: const ListExternalPlacesScreen(),
                  ),
                );

              case ConnectionState.none:
                return _ErrorView(
                  message: 'Connection error.',
                  onRetry: _reload,
                );
            }
          },
        ),
      ),
    );
  }
}

/// Loading spinner.

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading shared places…'),
        ],
      ),
    );
  }
}

/// Shown when no shared places exist.

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.share_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No Shared Places',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Places shared with you from other Pods will appear here. '
              'Ask someone to share a place with you, or check your '
              "Pod's permission log.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              onPressed: onRefresh,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown on error.

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to Load Shared Places',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
