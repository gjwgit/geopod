/// Global navigation service for switching app pages programmatically.
///
// Time-stamp: <2026-03-02>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/foundation.dart' show ValueNotifier;

import 'package:latlong2/latlong.dart' show LatLng;

/// Notifier that holds the currently selected top-level page index.
///
/// Index 0 = Home (map), 1 = Locations, 2 = Audio, 3 = Video, 4 = Files.
/// Changing this value will cause [AppScaffoldWidget] to switch the visible
/// page in the navigation rail / bottom bar.

final ValueNotifier<int> currentPageNotifier = ValueNotifier<int>(0);

/// Pending map navigation target.
///
/// When non-null, [GeoMapWidgetState] will move the map to this position as
/// soon as it is mounted and ready, then clear the value.

final ValueNotifier<LatLng?> pendingNavTarget = ValueNotifier<LatLng?>(null);
