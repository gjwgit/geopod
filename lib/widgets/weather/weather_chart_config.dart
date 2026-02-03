/// Configuration constants for weather charts.
///
// Time-stamp: <Friday 2026-01-24 10:00:00 +1100>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

/// Daily data card width.

const double dailyCardWidth = 80.0;

/// Daily data card spacing.

const double dailyCardSpacing = 6.0;

/// Chart tooltip message for sampling algorithms.

const String chartSamplingTooltip =
    'Catmull-Rom spline: Smooth curve algorithm that passes through data points\n'
    'Ramer-Douglas-Peucker: Smart sampling to preserve key features';

/// Chart sampling info text.

const String chartSamplingInfo =
    'Curve fitting: Catmull-Rom spline | Data sampling: RDP algorithm';
