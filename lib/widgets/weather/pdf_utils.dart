/// Utility functions for PDF generation.
///
// Time-stamp: <Friday 2026-01-24 10:00:00 +1100>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

/// Format timezone offset for PDF display (e.g., "+1100", "-0500", "+0000").

String formatTimeZoneOffset(Duration offset) {
  final hours = offset.inHours;
  final minutes = offset.inMinutes.remainder(60).abs();
  final sign = hours >= 0 ? '+' : '-';
  return '$sign${hours.abs().toString().padLeft(2, '0')}${minutes.toString().padLeft(2, '0')}';
}
