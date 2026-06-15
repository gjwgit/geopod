/// Platform IO utilities for NATIVE (non-web) platforms.
///
// Time-stamp: <2026-02-19 Miduo>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:path_provider/path_provider.dart';

// C: char* setlocale(int category, const char* locale);
typedef _SetLocaleC = Pointer<Utf8> Function(Int32, Pointer<Utf8>);
typedef _SetLocaleDart = Pointer<Utf8> Function(int, Pointer<Utf8>);

// LC_NUMERIC category value on glibc (Linux).
const int _lcNumeric = 1;

/// Force the C locale for numeric formatting on Linux.
///
/// libmpv (used by media_kit for audio/video) aborts the process with
/// "Non-C locale detected" when LC_NUMERIC is anything other than "C",
/// because it relies on '.' as the decimal separator. Systems with e.g.
/// en_AU.UTF-8 trigger this. Calling setlocale(LC_NUMERIC, "C") via libc
/// before media_kit initialises avoids the crash. No-op on non-Linux.
void fixNumericLocale() {
  if (!Platform.isLinux) return;
  try {
    final libc = DynamicLibrary.open('libc.so.6');
    final setlocale = libc.lookupFunction<_SetLocaleC, _SetLocaleDart>(
      'setlocale',
    );
    final c = 'C'.toNativeUtf8();
    try {
      setlocale(_lcNumeric, c);
    } finally {
      malloc.free(c);
    }
  } catch (_) {
    // If libc/setlocale is unavailable for any reason, leave the locale as is.
  }
}

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
