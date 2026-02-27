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

/// Returns `true` if a file exists at [path].
Future<bool> fileExists(String path) async => File(path).exists();

/// Writes [bytes] to a platform temporary file named [filename] and
/// returns the absolute path to the written file.
Future<String> writeBytesToTempFile(String filename, Uint8List bytes) async {
  final tempDir = await getTemporaryDirectory();
  final nameOnly = filename.split('/').last;
  final tempFile = File('${tempDir.path}/$nameOnly');
  await tempFile.writeAsBytes(bytes);
  return tempFile.path;
}
