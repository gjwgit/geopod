/// Platform utilities stub for WEB builds.
///
// Time-stamp: <2026-02-19 GitHub Copilot>
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
/// Authors: GitHub Copilot

library;

import 'dart:typed_data';

/// On web, files are not accessible via the local file-system.
/// Always returns `false`.
Future<bool> fileExists(String path) async => false;

/// On web, there is no writable temporary directory.
/// Returns [filename] unchanged – callers should handle this gracefully.
Future<String> writeBytesToTempFile(String filename, Uint8List bytes) async {
  // Web does not support writing to the local file-system.
  // Return the filename as-is; the caller must use a different strategy
  // (e.g. Blob/URL) to play back the bytes.
  return filename;
}
