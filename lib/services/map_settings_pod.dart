/// POD file operations for map settings.
///
/// Contains low-level file read/write operations for map settings data.
///
// Time-stamp: <2026-01-02 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solidpod/solidpod.dart';

import 'package:geopod/services/pod/pod_directory_service.dart';

const String settingsFileName = 'settings.json';

/// Keys for last viewport storage.
const String keyLastLat = 'map_last_lat';
const String keyLastLng = 'map_last_lng';
const String keyLastZoom = 'map_last_zoom';

/// Get the full file path for settings in POD.
Future<String> getSettingsFilePath() async {
  final path = await getDataDirPath();
  return '$path/$settingsFileName';
}

/// Read settings from POD.
/// Returns null if not logged in or if no settings exist.
Future<Map<String, dynamic>?> readSettingsFromPod() async {
  try {
    // Quick sync check - avoid slow async checkLoggedIn()
    if (!authStateNotifier.value) return null;

    final fp = await getSettingsFilePath();
    final url = await getFileUrl(fp);
    final (:accessToken, :dPopToken) = await getTokensForResource(url, 'GET');
    final r = await http.get(
      Uri.parse(url),
      headers: {
        'Accept': 'application/json, */*',
        'Authorization': 'DPoP $accessToken',
        'Connection': 'keep-alive',
        'DPoP': dPopToken,
      },
    );

    if (r.statusCode == 200 && r.body.trim().isNotEmpty) {
      final decoded = jsonDecode(r.body);
      if (decoded is Map<String, dynamic>) return decoded;
    }
    return null;
  } catch (e) {
    debugPrint('Error reading settings from POD: $e');
    return null;
  }
}

/// Write settings to POD (silently, in background).
/// Note: This is only called when user is logged in (from settings dialog close).
Future<bool> writeSettingsToPod(Map<String, dynamic> data) async {
  try {
    final fp = await getSettingsFilePath();
    final url = await getFileUrl(fp);
    final (:accessToken, :dPopToken) = await getTokensForResource(url, 'PUT');
    final r = await http.put(
      Uri.parse(url),
      headers: {
        'Accept': '*/*',
        'Authorization': 'DPoP $accessToken',
        'Connection': 'keep-alive',
        'Content-Type': 'application/json',
        'DPoP': dPopToken,
      },
      body: jsonEncode(data),
    );
    final success = r.statusCode >= 200 && r.statusCode < 300;
    if (success) {
      PodDirectoryService.invalidateCache('data');
      PodDirectoryService.notifyChange();
    }
    return success;
  } catch (e) {
    debugPrint('Error writing settings to POD: $e');
    return false;
  }
}

/// Represents a map viewport position (center + zoom).
class ViewportPosition {
  final double lat;
  final double lng;
  final double zoom;

  const ViewportPosition({
    required this.lat,
    required this.lng,
    required this.zoom,
  });
}

/// Saves the last viewed viewport position.
Future<bool> saveLastViewport({
  required double lat,
  required double lng,
  required double zoom,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(keyLastLat, lat);
    await prefs.setDouble(keyLastLng, lng);
    await prefs.setDouble(keyLastZoom, zoom);
    return true;
  } catch (_) {
    return false;
  }
}

/// Loads the last viewed viewport position.
Future<ViewportPosition?> loadLastViewport() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(keyLastLat);
    final lng = prefs.getDouble(keyLastLng);
    final zoom = prefs.getDouble(keyLastZoom);
    if (lat != null && lng != null && zoom != null) {
      return ViewportPosition(lat: lat, lng: lng, zoom: zoom);
    }
    return null;
  } catch (_) {
    return null;
  }
}
