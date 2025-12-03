/// Web-specific utilities using package:web.
///
/// This file provides implementations that use browser APIs
/// available only on the web platform.

library;

import 'package:web/web.dart' as web;

/// Replaces the current browser URL state without triggering a page reload.
///
/// This is used to clear OAuth query parameters from the URL after
/// authentication is complete, preventing re-authentication on page refresh.
void replaceUrlState(String url) {
  web.window.history.replaceState(null, '', url);
}
