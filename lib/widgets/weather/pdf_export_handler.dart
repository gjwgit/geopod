/// Platform-specific PDF export handling.
///
// Time-stamp: <Friday 2026-04-24 21:01:30 +1000 Graham Williams>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import 'package:geopod/utils/ui_utils.dart';

import 'pdf_download_stub.dart' if (dart.library.html) 'pdf_download_web.dart';

/// Handle PDF export with platform-specific save dialog.

Future<void> handlePdfExport(BuildContext context, Uint8List pdfBytes) async {
  final filename =
      'weather_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';

  if (kIsWeb) {
    // For Web: Download PDF file directly.
    downloadPdfWeb(pdfBytes, '$filename.pdf');

    if (context.mounted) {
      SnackBarHelper.showSuccess(
        context,
        'PDF downloaded successfully',
        duration: const Duration(seconds: 2),
      );
    }
  } else {
    // For mobile/desktop: Let user choose save location.
    final outputPath = await FilePicker.saveFile(
      dialogTitle: 'Save PDF Report',
      fileName: '$filename.pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (outputPath != null) {
      // Save the file to the chosen location.
      final file = File(outputPath);
      await file.writeAsBytes(pdfBytes);

      if (context.mounted) {
        SnackBarHelper.showSuccess(
          context,
          'PDF saved to: $outputPath',
          duration: const Duration(seconds: 3),
        );
      }
    } else {
      // User cancelled the save dialog.
      if (context.mounted) {
        SnackBarHelper.showInfo(
          context,
          'PDF export cancelled',
          duration: const Duration(seconds: 2),
        );
      }
    }
  }
}
