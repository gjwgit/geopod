/// Common UI utilities for showing dialogs and snackbars.
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

/// Helper for showing snackbars with consistent styling.
class SnackBarHelper {
  /// Shows a loading snackbar with a progress indicator.
  static void showLoading(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue.shade600,
        behavior: SnackBarBehavior.floating,
        duration: duration,
      ),
    );
  }

  /// Shows a success snackbar with a checkmark icon.
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        duration: duration,
      ),
    );
  }

  /// Shows an error snackbar with an error icon.
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        duration: duration,
      ),
    );
  }

  /// Shows a warning snackbar with a warning icon.
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange.shade600,
        behavior: SnackBarBehavior.floating,
        duration: duration,
      ),
    );
  }

  /// Shows an info snackbar.
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: duration,
      ),
    );
  }
}

/// Helper for showing confirmation dialogs.
class DialogHelper {
  /// Shows a confirmation dialog with customizable title, content, and buttons.
  ///
  /// Returns true if user confirmed, false if cancelled or dismissed.
  static Future<bool> showConfirmation(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color? confirmColor,
    IconData? titleIcon,
    Color? titleIconColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: titleIcon != null
            ? Row(
                children: [
                  Icon(titleIcon, color: titleIconColor),
                  const SizedBox(width: 8),
                  Text(title),
                ],
              )
            : Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: confirmColor != null
                ? ElevatedButton.styleFrom(
                    backgroundColor: confirmColor,
                    foregroundColor: Colors.white,
                  )
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result == true;
  }

  /// Shows a destructive confirmation dialog (for delete operations).
  static Future<bool> showDestructiveConfirmation(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = 'Delete',
    String cancelText = 'Cancel',
  }) {
    return showConfirmation(
      context,
      title: title,
      content: content,
      confirmText: confirmText,
      cancelText: cancelText,
      confirmColor: Colors.red,
      titleIcon: Icons.warning_amber,
      titleIconColor: Colors.orange,
    );
  }
}
