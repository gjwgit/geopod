/// Path management for encrypted places storage.
///
// Time-stamp: <Tuesday 2026-01-14 +1100>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.
///
/// Authors: Miduo

library;

import 'package:solidpod/solidpod.dart';

/// Directory name for encrypted places data.
/// Using underscore instead of space to avoid URL encoding issues.
const String encryptedPlacesDirName = 'encrypted_data';

/// File name for encrypted places.
const String encryptedPlacesFileName = 'encrypted_places.ttl';

/// Get the directory path for encrypted places (relative to data dir).
/// This is used with PathType.relativeToData, so just the subdirectory name.
String getEncryptedPlacesDirPath() {
  return encryptedPlacesDirName;
}

/// Get the file path for encrypted places (relative to data dir).
/// This is used with PathType.relativeToData.
String getEncryptedPlacesFilePath() {
  return '$encryptedPlacesDirName/$encryptedPlacesFileName';
}

/// Get the full directory path for encrypted places (relative to POD root).
Future<String> getFullEncryptedPlacesDirPath() async {
  final dataPath = await getDataDirPath();
  return '$dataPath/$encryptedPlacesDirName';
}
