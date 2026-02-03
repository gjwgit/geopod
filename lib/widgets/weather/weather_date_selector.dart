/// Weather date range selector for historical weather.
///
// Time-stamp: <Tuesday 2026-01-14 10:00:00 +1100>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import 'package:geopod/utils/ui_utils.dart';

/// Build date range selector for historical weather.

Widget buildDateRangeSelector({
  required BuildContext context,
  required DateTime? historicalStartDate,
  required DateTime? historicalEndDate,
  required void Function(DateTime?) onStartDateChanged,
  required void Function(DateTime?) onEndDateChanged,
  required VoidCallback onLoadData,
}) {
  final now = DateTime.now();
  final maxEndDate = now.subtract(const Duration(days: 7));

  return Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Date Range (ERA5 has 5-7 day delay)',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final selectedDate = await showDatePicker(
                      context: context,
                      initialDate:
                          historicalStartDate ??
                          maxEndDate.subtract(const Duration(days: 30)),
                      firstDate: DateTime(1940),
                      lastDate: maxEndDate.subtract(const Duration(days: 1)),
                      helpText: 'Select Start Date',
                      initialDatePickerMode: DatePickerMode.day,
                    );
                    if (selectedDate != null) {
                      onStartDateChanged(selectedDate);
                    }
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    historicalStartDate == null
                        ? 'Start Date'
                        : DateFormat('yyyy-MM-dd').format(historicalStartDate),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final minDate = historicalStartDate ?? DateTime(1940);
                    final selectedDate = await showDatePicker(
                      context: context,
                      initialDate: historicalEndDate ?? maxEndDate,
                      firstDate: minDate.add(const Duration(days: 1)),
                      lastDate: maxEndDate,
                      helpText: 'Select End Date',
                      initialDatePickerMode: DatePickerMode.day,
                    );
                    if (selectedDate != null) {
                      final daysDiff = selectedDate.difference(minDate).inDays;
                      if (daysDiff > 365) {
                        if (context.mounted) {
                          SnackBarHelper.showWarning(
                            context,
                            'Date range cannot exceed 365 days',
                          );
                        }
                        return;
                      }
                      onEndDateChanged(selectedDate);
                    }
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    historicalEndDate == null
                        ? 'End Date'
                        : DateFormat('yyyy-MM-dd').format(historicalEndDate),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  (historicalStartDate != null && historicalEndDate != null)
                  ? onLoadData
                  : null,
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Load Data'),
            ),
          ),
        ],
      ),
    ),
  );
}
