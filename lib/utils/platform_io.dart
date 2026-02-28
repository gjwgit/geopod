/// Platform IO utilities for NATIVE (non-web) platforms.
///
// Time-stamp: <2026-02-19 GitHub Copilot>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Writes [bytes] to a platform temporary file named [filename] and
/// returns the absolute path to the written file.
Future<String> writeBytesToTempFile(String filename, Uint8List bytes) async {
  final tempDir = await getTemporaryDirectory();
  final nameOnly = filename.split('/').last;
  final tempFile = File('${tempDir.path}/$nameOnly');
  await tempFile.writeAsBytes(bytes);
  return tempFile.path;
}

/// Writes [bytes] to a platform temp file and returns a `file://` URI string
/// suitable for [VideoPlayerController.networkUrl] or [AudioPlayer].
/// [mimeType] is ignored on native – the file extension determines the codec.
Future<String> bytesToPlaybackUrl(
  Uint8List bytes,
  String mimeType,
  String filename,
) async {
  final path = await writeBytesToTempFile(filename, bytes);
  // Return a file:// URL; VideoPlayerController.networkUrl handles it on native.
  return Uri.file(path).toString();
}

/// Deletes the temp file previously created by [bytesToPlaybackUrl].
/// Safe to call even if the file no longer exists.
Future<void> revokePlaybackUrl(String url) async {
  try {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.isScheme('file')) {
      final file = File.fromUri(uri);
      if (await file.exists()) await file.delete();
    }
  } catch (_) {}
}
