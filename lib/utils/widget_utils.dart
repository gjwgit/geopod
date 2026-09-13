/// Common utilities for widget state management.
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

import 'package:flutter/material.dart';

import 'package:solidpod/solidpod.dart' show authStateNotifier;

/// Mixin for managing authentication state in widgets.
///
/// Provides automatic auth state listening and cleanup.
///
/// Usage:
/// ```dart
/// class MyWidget extends StatefulWidget with AuthStateManagement {
///   @override
///   void onAuthStateChanged(bool isLoggedIn) {
///     // Handle auth state change
///   }
/// }
/// ```

mixin AuthStateManagement<T extends StatefulWidget> on State<T> {
  bool _isLoggedIn = false;

  /// Current login state.

  bool get isLoggedIn => _isLoggedIn;

  /// Called when authentication state changes.
  /// Override this method to handle auth state changes.

  void onAuthStateChanged(bool isLoggedIn);

  /// Initialize auth state listener.
  /// Call this in initState().

  void initAuthStateListener() {
    _isLoggedIn = authStateNotifier.value;
    authStateNotifier.addListener(_handleAuthStateChanged);
  }

  /// Cleanup auth state listener.
  /// Call this in dispose().

  void disposeAuthStateListener() {
    authStateNotifier.removeListener(_handleAuthStateChanged);
  }

  void _handleAuthStateChanged() {
    if (!mounted) return;
    final newState = authStateNotifier.value;
    if (newState != _isLoggedIn) {
      setState(() => _isLoggedIn = newState);
      onAuthStateChanged(newState);
    }
  }
}

/// Adds [safeSetState] and [executeWithLoading] to a [State].
///
/// 20260914 gjw A mixin rather than a pair of functions taking the State,
/// because setState is protected: calling it on somebody else's State has to
/// suppress the invalid-use-of-protected-member lint, whereas a mixin on
/// State is inside the class it belongs to.
///
/// Usage:
/// ```dart
/// class _MyWidgetState extends State<MyWidget> with SafeSetState {
///   void _update() => safeSetState(() {
///     _myValue = newValue;
///   });
/// }
/// ```

mixin SafeSetState<T extends StatefulWidget> on State<T> {
  /// Rebuild with [fn], doing nothing once the widget is gone.

  void safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  /// Execute an async operation with automatic error handling and loading
  /// state.
  ///
  /// Returns true if operation succeeded, false if failed.
  ///
  /// Usage:
  /// ```dart
  /// await executeWithLoading(
  ///   setLoading: (loading) => _isLoading = loading,
  ///   setError: (error) => _errorMessage = error,
  ///   operation: () async {
  ///     final data = await fetchData();
  ///     _data = data;
  ///   },
  /// );
  /// ```

  Future<bool> executeWithLoading({
    required void Function(bool) setLoading,
    void Function(String?)? setError,
    required Future<void> Function() operation,
  }) async {
    if (!mounted) return false;

    safeSetState(() {
      setLoading(true);
      setError?.call(null);
    });

    try {
      await operation();

      // CRITICAL: Execute setState to trigger rebuild after operation
      // completes.

      safeSetState(() => setLoading(false));

      return true;
    } catch (e) {
      safeSetState(() {
        setError?.call(e.toString());
        setLoading(false);
      });

      return false;
    }
  }
}

/// Post-frame callback helper that checks mounted state.

void addPostFrameCallback(State state, VoidCallback callback) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (state.mounted) {
      callback();
    }
  });
}
