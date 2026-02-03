/// Platform-specific PDF download implementation for web.
///
// Time-stamp: <Tuesday 2026-01-16 10:00:00 +1100>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Download PDF file on web platform.

void downloadPdfWeb(List<int> bytes, String filename) {
  // Convert Uint8List to JSUint8Array.
  final jsBytes = (bytes as Uint8List).toJS;
  final blob = web.Blob(
    [jsBytes].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename;
  anchor.click();
  web.URL.revokeObjectURL(url);
}
