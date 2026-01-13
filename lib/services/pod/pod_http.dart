/// POD HTTP client for GeoPod.
///
/// Provides low-level HTTP operations for POD resources.
///
// Time-stamp: <2026-01-01 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'dart:convert' show utf8;

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:http/http.dart' as http;

import 'package:geopod/services/pod/pod_auth.dart';

/// Result of a POD HTTP operation.
class PodResponse {
  final int statusCode;
  final String body;
  final Map<String, String> headers;

  const PodResponse({
    required this.statusCode,
    required this.body,
    required this.headers,
  });

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
  bool get isNotFound => statusCode == 404;
  bool get isForbidden => statusCode == 403;
  bool get isUnauthorized => statusCode == 401;
}

/// Resource status enumeration.
enum ResourceStatus { exist, notExist, forbidden, unknown }

/// Content types for POD resources.
enum PodContentType {
  json('application/json'),
  turtle('text/turtle'),
  text('text/plain'),
  binary('application/octet-stream'),
  any('*/*');

  final String value;
  const PodContentType(this.value);
}

/// Low-level HTTP client for POD operations.
class PodHttp {
  PodHttp._();

  /// Perform a GET request to fetch a resource.
  static Future<PodResponse> get(
    String url, {
    PodContentType accept = PodContentType.any,
  }) async {
    try {
      final tokens = await PodAuth.getTokens(url, 'GET');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': accept.value,
          'Authorization': 'DPoP ${tokens.accessToken}',
          'Connection': 'keep-alive',
          'DPoP': tokens.dPopToken,
        },
      );

      return PodResponse(
        statusCode: response.statusCode,
        body: response.body,
        headers: response.headers,
      );
    } catch (e) {
      debugPrint('PodHttp.get() error: $e');
      rethrow;
    }
  }

  /// Perform a PUT request to create or replace a resource.
  static Future<PodResponse> put(
    String url,
    String content, {
    PodContentType contentType = PodContentType.json,
  }) async {
    try {
      final tokens = await PodAuth.getTokens(url, 'PUT');
      final bodyBytes = utf8.encode(content);

      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Accept': '*/*',
          'Authorization': 'DPoP ${tokens.accessToken}',
          'Connection': 'keep-alive',
          'Content-Type': contentType.value,
          'Content-Length': bodyBytes.length.toString(),
          'DPoP': tokens.dPopToken,
        },
        body: bodyBytes,
      );

      return PodResponse(
        statusCode: response.statusCode,
        body: response.body,
        headers: response.headers,
      );
    } catch (e) {
      debugPrint('PodHttp.put() error: $e');
      rethrow;
    }
  }

  /// Perform a POST request to create a resource.
  static Future<PodResponse> post(
    String containerUrl,
    String name,
    String content, {
    PodContentType contentType = PodContentType.json,
    bool isDirectory = false,
  }) async {
    try {
      final tokens = await PodAuth.getTokens(containerUrl, 'POST');

      // Link header for resource type
      const fileTypeLink = '<http://www.w3.org/ns/ldp#Resource>; rel="type"';
      const dirTypeLink =
          '<http://www.w3.org/ns/ldp#BasicContainer>; rel="type"';

      final response = await http.post(
        Uri.parse(containerUrl),
        headers: {
          'Accept': '*/*',
          'Authorization': 'DPoP ${tokens.accessToken}',
          'Connection': 'keep-alive',
          'Content-Type': isDirectory ? 'text/turtle' : contentType.value,
          'Link': isDirectory ? dirTypeLink : fileTypeLink,
          'Slug': name,
          'DPoP': tokens.dPopToken,
        },
        body: isDirectory ? '' : utf8.encode(content),
      );

      return PodResponse(
        statusCode: response.statusCode,
        body: response.body,
        headers: response.headers,
      );
    } catch (e) {
      debugPrint('PodHttp.post() error: $e');
      rethrow;
    }
  }

  /// Perform a DELETE request to remove a resource.
  static Future<PodResponse> delete(String url) async {
    try {
      final tokens = await PodAuth.getTokens(url, 'DELETE');

      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Accept': '*/*',
          'Authorization': 'DPoP ${tokens.accessToken}',
          'Connection': 'keep-alive',
          'DPoP': tokens.dPopToken,
        },
      );

      return PodResponse(
        statusCode: response.statusCode,
        body: response.body,
        headers: response.headers,
      );
    } catch (e) {
      debugPrint('PodHttp.delete() error: $e');
      rethrow;
    }
  }

  /// Perform a HEAD request to check resource existence.
  static Future<ResourceStatus> checkStatus(String url) async {
    try {
      final tokens = await PodAuth.getTokens(url, 'HEAD');

      final response = await http.head(
        Uri.parse(url),
        headers: {
          'Accept': '*/*',
          'Authorization': 'DPoP ${tokens.accessToken}',
          'Connection': 'keep-alive',
          'DPoP': tokens.dPopToken,
        },
      );

      switch (response.statusCode) {
        case 200:
        case 204:
          return ResourceStatus.exist;
        case 404:
          return ResourceStatus.notExist;
        case 401:
        case 403:
          return ResourceStatus.forbidden;
        default:
          return ResourceStatus.unknown;
      }
    } catch (e) {
      debugPrint('PodHttp.checkStatus() error: $e');
      return ResourceStatus.unknown;
    }
  }
}
