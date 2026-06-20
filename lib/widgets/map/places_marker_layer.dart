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

/// Maximum number of markers that receive entrance animations.
const int _kMaxAnimatedMarkers = 20;

/// Builds a marker layer for places.
///
/// Performance design:
/// - When [shouldAnimate] is false (the common steady-state case) every
///   Marker.child is a plain stateless widget.  No StatefulWidget, no Ticker,
///   no SingleTickerProviderStateMixin anywhere in the marker subtree.  This
///   eliminates the composited-layer artefacts (ghost copies / drift) that
///   appear during fast map panning.
/// - When [shouldAnimate] is true (only during initial load / post-login
///   refresh) the first [_kMaxAnimatedMarkers] use a self-disposing
///   TweenAnimationBuilder, which also leaves no residual State once the
///   animation completes.

MarkerLayer buildPlacesMarkerLayer({
  required BuildContext context,
  required List<MarkerData> markers,
  required bool shouldAnimate,
  required void Function(MarkerData) onDelete,
  required void Function(MarkerData) onEdit,
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
          onEdit: onEdit,
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
  required void Function(MarkerData) onEdit,
}) {
  // Saving markers have their own animated indicator; skip entrance animation.
  final doAnimate =
      shouldAnimate && !marker.isSaving && index < _kMaxAnimatedMarkers;

  // Build the visual child (pure stateless widgets when not saving).
  final Widget icon = marker.isSaving
      ? _buildSavingMarker()
      : Icon(Icons.location_on, size: 40, color: marker.color);

  final Widget tapTarget = GestureDetector(
    onTap: () => showMarkerDetailsSheet(
      context,
      marker,
      onDelete: () => onDelete(marker),
      onEdit: () => onEdit(marker),
    ),
    child: icon,
  );

  // When no animation is needed, pass the stateless widget directly.
  // This is the steady-state path (shouldAnimate = false after initial load).
  // No StatefulWidget, no SingleTickerProviderStateMixin in the subtree —
  // markers cannot create independent composited layers that drift from the map.
  final Widget child = doAnimate
      ? _buildAnimatedMarker(tapTarget, index)
      : tapTarget;

  return Marker(
    key: ValueKey('marker_${marker.id}'),
    point: marker.position,
    width: 40,
    height: 40,
    alignment: const Alignment(
      0.0,
      -0.8,
    ), // Align the bottom center of the icon to the point.
    child: child,
  );
}

/// Wraps [child] in a staggered scale+fade entrance animation.
///
/// Uses [TweenAnimationBuilder] which is stateless from the parent's
/// perspective: it owns its own internal state and disposes it automatically
/// when the animation value reaches 1.0 and the widget is removed from the
/// tree.  No [SingleTickerProviderStateMixin] leaks into the marker subtree.

Widget _buildAnimatedMarker(Widget child, int index) {
  final delay = Duration(milliseconds: (index * 25).clamp(0, 200));
  return TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.0, end: 1.0),
    duration: const Duration(milliseconds: 250) + delay,
    curve: Curves.easeOutCubic,
    builder: (context, value, animChild) {
      // Clamp the stagger: opacity/scale only starts after the delay fraction.
      final delayFraction = delay.inMilliseconds / (250 + delay.inMilliseconds);
      final progress = ((value - delayFraction) / (1.0 - delayFraction)).clamp(
        0.0,
        1.0,
      );
      return Opacity(
        opacity: progress,
        child: Transform.scale(scale: progress, child: animChild),
      );
    },
    child: child,
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
