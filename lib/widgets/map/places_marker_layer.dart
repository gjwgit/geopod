/// Places marker layer widget for GeoMap.
///
// Time-stamp: <2025-12-18 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';

import 'package:geopod/widgets/map/marker_data.dart';
import 'package:geopod/widgets/map/marker_details_sheet.dart';
import 'package:geopod/widgets/map/marker_with_animation.dart';

/// Builds a marker layer for places.

MarkerLayer buildPlacesMarkerLayer({
  required BuildContext context,
  required List<MarkerData> markers,
  required bool shouldAnimate,
  required void Function(MarkerData) onDelete,
}) {
  return MarkerLayer(
    markers: [
      for (int i = 0; i < markers.length; i++)
        _buildMarker(
          context: context,
          marker: markers[i],
          index: i,
          shouldAnimate: shouldAnimate,
          onDelete: onDelete,
        ),
    ],
  );
}

/// Builds a single marker widget.

Marker _buildMarker({
  required BuildContext context,
  required MarkerData marker,
  required int index,
  required bool shouldAnimate,
  required void Function(MarkerData) onDelete,
}) {
  // Skip entrance animation for markers being saved (they have their own indicator)
  final animate = shouldAnimate && !marker.isSaving;

  return Marker(
    key: ValueKey('marker_${marker.id}'),
    point: marker.position,
    width: 40,
    height: 40,
    child: MarkerWithAnimation(
      key: ValueKey('anim_${marker.id}'),
      index: index,
      shouldAnimate: animate,
      child: GestureDetector(
        onTap: () => showMarkerDetailsSheet(
          context,
          marker,
          onDelete: () => onDelete(marker),
        ),
        child: marker.isSaving
            ? _buildSavingMarker()
            : marker.isEncrypted
            ? _buildEncryptedMarker(marker.color)
            : Icon(Icons.location_on, size: 40, color: marker.color),
      ),
    ),
  );
}

/// Builds marker with encryption indicator.

Widget _buildEncryptedMarker(Color color) {
  return Stack(
    alignment: Alignment.center,
    children: [
      Icon(Icons.location_on, size: 40, color: color),
      const Positioned(
        top: 6,
        child: Icon(Icons.lock, size: 12, color: Colors.white),
      ),
    ],
  );
}

/// Builds the saving state marker with rotating animation.

class _SavingMarker extends StatefulWidget {
  const _SavingMarker();

  @override
  State<_SavingMarker> createState() => _SavingMarkerState();
}

class _SavingMarkerState extends State<_SavingMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Base marker icon - cyan color to distinguish from examples (orange)
        Icon(Icons.location_on, size: 40, color: Colors.cyan.shade400),

        // Rotating ring around the marker.
        Positioned(
          top: 2,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.rotate(
                angle: _controller.value * 2 * 3.14159,
                child: child,
              );
            },
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.9),
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
                gradient: SweepGradient(
                  colors: [
                    Colors.cyan.shade200,
                    Colors.cyan.shade400,
                    Colors.cyan.shade200,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Cloud upload icon in center.
        const Positioned(
          top: 6,
          child: Icon(Icons.cloud_upload, size: 12, color: Colors.white),
        ),
      ],
    );
  }
}

Widget _buildSavingMarker() {
  return const _SavingMarker();
}
