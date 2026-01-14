/// Data sampling algorithms for weather chart.
///
// Time-stamp: <Tuesday 2026-01-14 10:00:00 +1100>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'dart:math';

/// Sample data using Ramer-Douglas-Peucker algorithm to preserve curve characteristics.
/// This algorithm keeps points that are important for maintaining the shape of the curve.
Map<DateTime, double> sampleData(
  Map<DateTime, double> data,
  int targetCount,
) {
  if (data.length <= targetCount) return data;

  final entries = data.entries.toList();

  // Use Douglas-Peucker algorithm for smart sampling
  final sampled = douglasPeucker(entries, targetCount);

  // Convert back to map
  return Map.fromEntries(sampled);
}

/// Ramer-Douglas-Peucker algorithm implementation.
/// Reduces number of points while preserving the overall shape.
List<MapEntry<DateTime, double>> douglasPeucker(
  List<MapEntry<DateTime, double>> points,
  int targetCount,
) {
  if (points.length <= targetCount) return points;

  // Calculate appropriate epsilon (tolerance) based on data range
  final values = points.map((e) => e.value).toList();
  final minVal = values.reduce((a, b) => a < b ? a : b);
  final maxVal = values.reduce((a, b) => a > b ? a : b);
  final range = maxVal - minVal;

  // Start with a small epsilon and increase until we reach target count
  var epsilon = range * 0.01;
  var result = rdpRecursive(points, epsilon);

  // Adjust epsilon to get closer to target count
  var iterations = 0;
  while (result.length > targetCount && iterations < 10) {
    epsilon *= 1.5;
    result = rdpRecursive(points, epsilon);
    iterations++;
  }

  // If still too many points, fall back to uniform sampling
  if (result.length > targetCount) {
    final step = result.length / targetCount;
    final uniformSampled = <MapEntry<DateTime, double>>[];
    for (var i = 0; i < targetCount; i++) {
      final index = (i * step).round();
      if (index < result.length) {
        uniformSampled.add(result[index]);
      }
    }
    return uniformSampled;
  }

  return result;
}

/// Recursive RDP algorithm.
List<MapEntry<DateTime, double>> rdpRecursive(
  List<MapEntry<DateTime, double>> points,
  double epsilon,
) {
  if (points.length < 3) return points;

  // Find the point with maximum distance from line segment
  var maxDistance = 0.0;
  var maxIndex = 0;

  final firstPoint = points.first;
  final lastPoint = points.last;

  for (var i = 1; i < points.length - 1; i++) {
    final distance = perpendicularDistance(
      points[i],
      firstPoint,
      lastPoint,
      points.length,
    );
    if (distance > maxDistance) {
      maxDistance = distance;
      maxIndex = i;
    }
  }

  // If max distance is greater than epsilon, recursively simplify
  if (maxDistance > epsilon) {
    final left = rdpRecursive(points.sublist(0, maxIndex + 1), epsilon);
    final right = rdpRecursive(points.sublist(maxIndex), epsilon);

    // Combine results (remove duplicate middle point)
    return [...left.sublist(0, left.length - 1), ...right];
  } else {
    // If max distance is less than epsilon, keep only endpoints
    return [firstPoint, lastPoint];
  }
}

/// Calculate perpendicular distance from point to line segment.
double perpendicularDistance(
  MapEntry<DateTime, double> point,
  MapEntry<DateTime, double> lineStart,
  MapEntry<DateTime, double> lineEnd,
  int totalPoints,
) {
  // Normalize time to 0-1 range for distance calculation
  final x0 = point.key.millisecondsSinceEpoch.toDouble();
  final y0 = point.value;

  final x1 = lineStart.key.millisecondsSinceEpoch.toDouble();
  final y1 = lineStart.value;

  final x2 = lineEnd.key.millisecondsSinceEpoch.toDouble();
  final y2 = lineEnd.value;

  // Calculate perpendicular distance
  final dx = x2 - x1;
  final dy = y2 - y1;
  final numerator = ((dy * (x0 - x1)) - (dx * (y0 - y1))).abs();
  final denominator = sqrt(dx * dx + dy * dy);

  return denominator != 0 ? numerator / denominator : 0;
}

/// Sample entries for PDF to reduce clutter.
List<MapEntry<DateTime, double>> sampleEntriesForPdf(
  List<MapEntry<DateTime, double>> entries,
  int targetCount,
) {
  if (entries.length <= targetCount) return entries;

  final step = entries.length / targetCount;
  final sampled = <MapEntry<DateTime, double>>[];

  for (var i = 0; i < targetCount; i++) {
    final index = (i * step).floor().clamp(0, entries.length - 1);
    sampled.add(entries[index]);
  }

  // Always include the last entry
  if (sampled.last.key != entries.last.key) {
    sampled.add(entries.last);
  }

  return sampled;
}
