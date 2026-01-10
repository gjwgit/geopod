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

/// Animated marker widget with delayed entrance animation.
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
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    if (widget.shouldAnimate) {
      // Create animation controller with staggered delay based on index
      _controller = AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      );

      // Scale animation: bounce effect (0.0 → 1.0 with overshoot)
      _scaleAnimation = CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      );

      // Fade animation: smooth fade-in
      _fadeAnimation = CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      );

      // Start animation with staggered delay (50ms per marker)
      Future.delayed(Duration(milliseconds: 100 + (widget.index * 50)), () {
        if (mounted) {
          _controller.forward();
        }
      });
    } else {
      // No animation needed - create dummy controller
      _controller = AnimationController(duration: Duration.zero, vsync: this)
        ..value = 1.0;

      _scaleAnimation = const AlwaysStoppedAnimation(1.0);
      _fadeAnimation = const AlwaysStoppedAnimation(1.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.shouldAnimate) {
      // No animation - return child directly
      return widget.child;
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}
