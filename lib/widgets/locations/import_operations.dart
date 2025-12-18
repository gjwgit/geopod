/// Import operations and dialogs for LocationsPage.
///
// Time-stamp: <2025-12-18 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';
import 'package:geopod/services/places_service.dart';
import 'package:geopod/widgets/locations/import_format_dialog.dart';
import 'package:geopod/widgets/locations/import_preview_dialog.dart';
import 'package:geopod/widgets/locations_page.dart';

/// Shows import failed dialog with errors.
Future<void> showImportFailedDialog(
  BuildContext context,
  List<String> errors,
) async {
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red),
          SizedBox(width: 8),
          Text('Import Failed'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('No valid places found in the file.'),
            const SizedBox(height: 12),
            const Text(
              'Errors:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...errors
                .take(10)
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $e',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ),
            if (errors.length > 10)
              Text(
                '... and ${errors.length - 10} more errors',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Shows importing progress dialog.
void showImportingProgressDialog(
  BuildContext context,
  ValueNotifier<String> progress,
) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: ValueListenableBuilder<String>(
          valueListenable: progress,
          builder: (_, msg, _) => Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(child: Text(msg)),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Shows import success snackbar.
void showImportSuccessSnackbar(BuildContext context, int count) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 12),
          Text('Imported $count places successfully'),
        ],
      ),
      backgroundColor: Colors.green,
    ),
  );
}

/// Shows import failure snackbar.
void showImportFailureSnackbar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Failed to save imported places'),
      backgroundColor: Colors.red,
    ),
  );
}

/// Shows no places to export snackbar.
void showNoPlacesToExportSnackbar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('No places to export'),
      backgroundColor: Colors.orange,
    ),
  );
}

/// Shows no places found snackbar.
void showNoPlacesFoundSnackbar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('No places found in the file'),
      backgroundColor: Colors.orange,
    ),
  );
}

/// Performs the full import flow.
Future<bool> performImportFlow(
  BuildContext context,
  Future<void> Function() onSuccess,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => const ImportFormatDialog(),
  );
  if (confirmed != true) return false;

  final result = await PlacesService.importPlaces();
  if (result.cancelled) return false;

  if (!context.mounted) return false;

  if (!result.hasPlaces && result.hasErrors) {
    await showImportFailedDialog(context, result.errors);
    return false;
  }

  if (!result.hasPlaces) {
    showNoPlacesFoundSnackbar(context);
    return false;
  }

  if (!context.mounted) return false;

  final edited = await showDialog<List<Place>>(
    context: context,
    builder: (_) => ImportPreviewDialog(
      places: result.places,
      errors: result.errors,
      skippedCount: result.skippedCount,
    ),
  );
  if (edited == null || edited.isEmpty) return false;

  if (!context.mounted) return false;

  final progress = ValueNotifier<String>(
    'Importing ${edited.length} places...\nFetching addresses (0/${edited.length})...',
  );
  showImportingProgressDialog(context, progress);

  final success = await PlacesService.mergeImportedPlaces(
    edited,
    context,
    const LocationsPage(),
    onProgress: (c, t) => progress.value =
        'Importing ${edited.length} places...\nFetching addresses ($c/$t)...',
  );

  if (!context.mounted) return success;

  Navigator.of(context).pop();

  if (success) {
    showImportSuccessSnackbar(context, edited.length);
    await onSuccess();
  } else {
    showImportFailureSnackbar(context);
  }
  return success;
}
