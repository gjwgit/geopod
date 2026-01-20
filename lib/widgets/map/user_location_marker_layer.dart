/// User location marker layer widget for GeoMap.
///
// Time-stamp: <2026-01-17 Miduo>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Builds a marker layer for user's current location.
///
/// Displays a pulsing blue dot with a semi-transparent circle
/// to indicate the user's current position on the map.
MarkerLayer? buildUserLocationMarkerLayer({required LatLng? userLocation}) {
  if (userLocation == null) return null;

  return MarkerLayer(
    markers: [
      Marker(
        point: userLocation,
        width: 80,
        height: 80,
        alignment: Alignment.center,
        child: const _UserLocationMarker(),
      ),
    ],
  );
}

/// Widget that displays the user location marker with animation.
class _UserLocationMarker extends StatefulWidget {
  const _UserLocationMarker();

  @override
  State<_UserLocationMarker> createState() => _UserLocationMarkerState();
}

class _UserLocationMarkerState extends State<_UserLocationMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    // Create pulsing animation
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: false);

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.4,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacityAnimation = Tween<double>(
      begin: 0.6,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
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
        // Pulsing outer circle
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withValues(
                    alpha: 0.3 * _opacityAnimation.value,
                  ),
                  border: Border.all(
                    color: Colors.blue.withValues(
                      alpha: 0.5 * _opacityAnimation.value,
                    ),
                    width: 2,
                  ),
                ),
              ),
            );
          },
        ),
        // Static accuracy circle
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.withValues(alpha: 0.15),
            border: Border.all(
              color: Colors.blue.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
        ),
        // Inner blue dot
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.shade600,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
