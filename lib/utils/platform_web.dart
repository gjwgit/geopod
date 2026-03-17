/// Platform utilities stub for WEB builds.
///
// Time-stamp: <2026-02-19 Miduo>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
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
/// Authors: Miduo

library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Creates a browser Blob URL from [bytes] with the given [mimeType].
/// The returned URL can be used directly in `<audio>`/`<video>` elements
/// and by [VideoPlayerController.networkUrl] on web.
/// [filename] is unused on web.
Future<String> bytesToPlaybackUrl(
  Uint8List bytes,
  String mimeType,
  String filename,
) async {
  // Use package:web Blob API.
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  return web.URL.createObjectURL(blob);
}

/// Revokes a Blob URL previously created by [bytesToPlaybackUrl].
Future<void> revokePlaybackUrl(String url) async {
  if (url.startsWith('blob:')) {
    web.URL.revokeObjectURL(url);
  }
}
