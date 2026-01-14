/// Security key dialog widget for encrypted data access.
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

import 'package:solidpod/solidpod.dart';

/// Shows a dialog to prompt user for security key.
/// Returns true if key was successfully entered and verified.
Future<bool> showSecurityKeyDialog(BuildContext context) async {
  final keyController = TextEditingController();
  bool result = false;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      bool isLoading = false;
      bool obscureText = true;
      String? errorText;

      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Row(
            children: [
              Icon(Icons.key, color: Colors.blue),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Enter Security Key',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please enter your security key to access encrypted data.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: keyController,
                obscureText: obscureText,
                decoration: InputDecoration(
                  labelText: 'Security Key',
                  border: const OutlineInputBorder(),
                  errorText: errorText,
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => obscureText = !obscureText),
                  ),
                ),
                enabled: !isLoading,
                onSubmitted: (_) async {
                  if (keyController.text.isNotEmpty && !isLoading) {
                    await _verifyAndSetKey(
                      keyController.text,
                      setState,
                      ctx,
                      () => result = true,
                      (msg, loading) {
                        errorText = msg;
                        isLoading = loading;
                      },
                    );
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (keyController.text.isEmpty) {
                        setState(() => errorText = 'Please enter a key');
                        return;
                      }
                      await _verifyAndSetKey(
                        keyController.text,
                        setState,
                        ctx,
                        () => result = true,
                        (msg, loading) {
                          errorText = msg;
                          isLoading = loading;
                        },
                      );
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirm'),
            ),
          ],
        ),
      );
    },
  );

  keyController.dispose();
  return result;
}

/// Verify security key and set it if valid.
Future<void> _verifyAndSetKey(
  String key,
  void Function(void Function()) setState,
  BuildContext ctx,
  void Function() onSuccess,
  void Function(String?, bool) onUpdate,
) async {
  setState(() => onUpdate(null, true));

  try {
    final verificationKey = await KeyManager.getVerificationKey();
    if (verifySecurityKey(key, verificationKey)) {
      await KeyManager.setSecurityKey(key);
      onSuccess();
      if (ctx.mounted) Navigator.pop(ctx);
    } else {
      setState(() => onUpdate('Incorrect security key', false));
    }
  } catch (e) {
    setState(() => onUpdate('Error verifying key', false));
  }
}

/// Shows a dialog when encryption is not set up.
Future<void> showEncryptionNotSetupDialog(BuildContext context) async {
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange),
          SizedBox(width: 8),
          Text('Encryption Not Set Up'),
        ],
      ),
      content: const Text(
        'Encryption has not been set up for your Pod. '
        'Please set up encryption first through the initial setup process.',
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
