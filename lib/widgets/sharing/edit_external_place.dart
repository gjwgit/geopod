/// Widget for editing an externally owned place shared with the current user.
///
// Time-stamp: <2026-04-13 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

// ignore_for_file: use_build_context_synchronously

library;

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:solidpod/solidpod.dart';

import 'package:geopod/models/external_place.dart';
import 'package:geopod/services/sharing/sharing_service.dart';

/// A form widget for editing the note/title of an external place.
///
/// Requires `write` permission on the shared place.  Coordinates are
/// displayed as read-only; only the note field is editable as it is the
/// semantically meaningful content a recipient would update.

class EditExternalPlace extends StatefulWidget {
  const EditExternalPlace({
    super.key,
    required this.place,
    required this.backPage,
  });

  /// The shared place being edited.
  final FoundExternalPlace place;

  /// Widget to return to after saving or cancelling.
  final Widget backPage;

  @override
  State<EditExternalPlace> createState() => _EditExternalPlaceState();
}

class _EditExternalPlaceState extends State<EditExternalPlace> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _noteController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(
      text: widget.place.content?.note ?? '',
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final original = widget.place.content!;
      final updated = original.copyWith(note: _noteController.text.trim());

      await writeExternalPod(
        widget.place.placeUrl,
        jsonEncode(updated.toJson()),
        widget.place.placeOwner,
      );

      // Invalidate the in-memory cache so the list reloads fresh.
      invalidateExternalPlaceCache();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Place updated successfully.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('[EditExternalPlace] save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.place.content;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Shared Place',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Read-only info ──────────────────────────────────────
                if (content != null) ...[
                  Card(
                    color: Colors.grey.shade50,
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Place Info (read-only)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _InfoRow(
                            icon: Icons.location_on_outlined,
                            label: 'Coordinates',
                            value: content.coordinates,
                          ),
                          if (content.address != null)
                            _InfoRow(
                              icon: Icons.home_outlined,
                              label: 'Address',
                              value: content.address!,
                            ),
                          _InfoRow(
                            icon: Icons.person_outline,
                            label: 'Owner',
                            value: widget.place.placeOwner,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Editable note field ─────────────────────────────────
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note / Title',
                    hintText: 'Describe this place…',
                    prefixIcon: Icon(Icons.notes),
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  enabled: !_isSaving,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Note is required' : null,
                ),

                const SizedBox(height: 24),

                // ── Action buttons ──────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel'),
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: const Text('Save'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isSaving ? null : _save,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single read-only info row used within the info card.

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
