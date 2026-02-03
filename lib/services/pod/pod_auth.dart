/// POD authentication utilities for GeoPod.
///
/// Provides access to authentication tokens and user information
/// without depending on solidpod's complex encryption system.
///
// Time-stamp: <Thursday 2026-01-15 21:09:50 +1100 Graham Williams>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:solid_auth/solid_auth.dart' show genDpopToken;
import 'package:solidpod/solidpod.dart' show AuthDataManager, authStateNotifier;

/// Authentication token pair for POD requests.

typedef TokenPair = ({String accessToken, String dPopToken});

/// Provides authentication utilities for POD access.

class PodAuth {
  PodAuth._();

  /// Get access token and DPoP token for a resource URL.
  ///
  /// [resourceUrl] - The URL of the resource to access.
  /// [method] - HTTP method (GET, PUT, POST, DELETE).

  static Future<TokenPair> getTokens(String resourceUrl, String method) async {
    final authData = await AuthDataManager.loadAuthData();
    if (authData == null) {
      throw Exception('Not authenticated - please log in first');
    }

    final accessToken = authData['accessToken'] as String;
    final rsaInfo = authData['rsaInfo'] as Map;
    final rsaKeyPair = rsaInfo['rsa'];
    final publicKeyJwk = rsaInfo['pubKeyJwk'];

    final dPopToken = genDpopToken(
      resourceUrl,
      rsaKeyPair,
      publicKeyJwk,
      method,
    );

    return (accessToken: accessToken, dPopToken: dPopToken);
  }

  /// Get the current user's WebID.

  static Future<String?> getWebId() async {
    return await AuthDataManager.getWebId();
  }

  /// Check if user is currently logged in.

  static Future<bool> isLoggedIn() async {
    final webId = await AuthDataManager.getWebId();
    return webId != null && webId.isNotEmpty;
  }

  /// Check if user is logged in (synchronous, uses cached data).

  static bool isLoggedInSync() {
    return authStateNotifier.value;
  }

  /// Profile card path constant (same as solidpod).

  static const String _profCard = 'profile/card#me';

  /// Extract POD base URL from WebID.
  ///
  /// Example: `https://pods.solidcommunity.au/ profile/card#me`
  /// Returns: `https://pods.solidcommunity.au/`
  ///
  /// Uses the same approach as solidpod to handle ports and custom paths.

  static Future<String?> getPodBaseUrl() async {
    final webId = await getWebId();
    if (webId == null) return null;

    // Same method as solidpod: replace profile/card#me with empty string
    // This preserves ports and any other URL components.

    if (!webId.contains(_profCard)) {
      // Fallback to URI parsing if WebID doesn't have standard format.
      final uri = Uri.parse(webId);
      final port = uri.hasPort ? ':${uri.port}' : '';
      return '${uri.scheme}://${uri.host}$port/';
    }

    return webId.replaceAll(_profCard, '');
  }

  /// Get resource URL from a path (same method as solidpod).
  ///
  /// [resourcePath] - Path to the resource (e.g., 'geopod/data/places').
  /// [isContainer] - Whether this is a directory (adds trailing slash).

  static Future<String> getResourceUrl(
    String resourcePath, {
    bool isContainer = false,
  }) async {
    final webId = await getWebId();
    if (webId == null || webId.isEmpty) {
      throw Exception('User not logged in: cannot access resource URL');
    }

    if (!webId.contains(_profCard)) {
      throw Exception('Invalid webId format: must contain $_profCard');
    }

    final resourceUrl = webId.replaceAll(_profCard, resourcePath);

    if (isContainer && !resourceUrl.endsWith('/')) {
      return '$resourceUrl/';
    }

    return resourceUrl;
  }
}
