/// Animated marker widget with delayed entrance animation.
///
// Time-stamp: <Monday 2025-12-08 08:22:27 +1100 Graham Williams>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
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
/// Authors: Graham Williams, Miduo

library;

import 'package:flutter/material.dart';

/// Maximum number of markers to animate simultaneously to prevent jank.
const int _maxAnimatedMarkers = 8;

/// Animated marker widget with delayed entrance animation.
///
/// Performance optimizations:
/// - Only animates first [_maxAnimatedMarkers] markers to reduce overhead
/// - Uses lightweight easeOutBack curve instead of elasticOut
/// - Minimal stagger delay (max 200ms total)
/// - Returns child directly when animation not needed
class MarkerWithAnimation extends StatefulWidget {
  const MarkerWithAnimation({
    super.key,
    required this.index,
    required this.shouldAnimate,
    required this.child,
  });

  final int index;
  final bool shouldAnimate;
  final Widget child;

  @override
  State<MarkerWithAnimation> createState() => _MarkerWithAnimationState();
}

class _MarkerWithAnimationState extends State<MarkerWithAnimation>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _scaleAnimation;
  Animation<double>? _fadeAnimation;
  bool _animationStarted = false;

  @override
  void initState() {
    super.initState();

    // Skip animation for markers beyond threshold to reduce jank
    final shouldActuallyAnimate =
        widget.shouldAnimate && widget.index < _maxAnimatedMarkers;

    if (shouldActuallyAnimate) {
      // Defer controller creation to avoid blocking initState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _setupAnimation();
      });
    }
  }

  void _setupAnimation() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250), // Shorter duration
      vsync: this,
    );

    // Use lighter curves
    _scaleAnimation = CurvedAnimation(
      parent: _controller!,
      curve: Curves.easeOutCubic, // Lighter than easeOutBack
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller!,
      curve: Curves.easeOut,
    );

    // Reduced stagger: max 200ms total delay for better perceived performance
    final delay = (widget.index * 25).clamp(0, 200);
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted && _controller != null) {
        _animationStarted = true;
        _controller!.forward();
        // Trigger rebuild to show animation
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fast path: no animation needed
    if (!widget.shouldAnimate || widget.index >= _maxAnimatedMarkers) {
      return widget.child;
    }

    // Animation not yet set up - show child with reduced opacity
    if (_controller == null || !_animationStarted) {
      return Opacity(opacity: 0.3, child: widget.child);
    }

    return FadeTransition(
      opacity: _fadeAnimation!,
      child: ScaleTransition(scale: _scaleAnimation!, child: widget.child),
    );
  }
}
