/// Platform-specific PDF download stub for non-web platforms.
///
// Time-stamp: <Tuesday 2026-01-16 10:00:00 +1100>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

/// Download PDF file (stub for non-web platforms).
///
/// This function is not used on non-web platforms as PDF handling
/// is done through the printing package.
void downloadPdfWeb(List<int> bytes, String filename) {
  throw UnsupportedError('downloadPdfWeb is only supported on web platform');
}
