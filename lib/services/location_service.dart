/// Location service for getting user's current position.
///
// Time-stamp: <Thursday 2026-01-16 +0800>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Result of location request with detailed error message.
class LocationResult {
  final LatLng? location;
  final String? errorMessage;
  final bool success;

  LocationResult({this.location, this.errorMessage})
    : success = location != null;

  LocationResult.success(this.location) : errorMessage = null, success = true;

  LocationResult.error(this.errorMessage) : location = null, success = false;
}

/// Service class for handling location operations.
class LocationService {
  /// Get current user location with detailed error information.
  /// Returns LocationResult with location or error message.
  static Future<LocationResult> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult.error(
          'Location services are disabled. Please enable location in your device settings.',
        );
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.denied) {
          return LocationResult.error(
            'Location permission denied. Please allow location access in your browser or device settings.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult.error(
          'Location permission permanently denied. Please enable location access in your browser or device settings.',
        );
      }

      // Get current position with platform-specific settings
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: kIsWeb
            ? const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 15),
              )
            : const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 10),
              ),
      );

      return LocationResult.success(
        LatLng(position.latitude, position.longitude),
      );
    } on PermissionDeniedException {
      return LocationResult.error(
        'Location permission denied. Please allow location access.',
      );
    } on TimeoutException {
      return LocationResult.error(
        'Location request timed out. Please check your GPS signal and try again.',
      );
    } catch (e) {
      // Check for specific error messages
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('location') && errorStr.contains('disabled')) {
        return LocationResult.error(
          'Location services are disabled. Please enable location in your device settings.',
        );
      }

      return LocationResult.error('Unable to get location: ${e.toString()}');
    }
  }

  /// Check if location permission is granted.
  static Future<bool> hasLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Open app settings to allow user to enable location permission.
  static Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }
}
