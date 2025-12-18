/// State mixin for GeoMapWidget initialization and lifecycle.
///
// Time-stamp: <2025-12-08 Miduo>
///
/// Copyright (C) 2025, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.

library;

import 'package:flutter/material.dart';
import 'package:solidpod/solidpod.dart';
import 'package:geopod/models/place.dart';
import 'package:geopod/services/gdelt_news_service.dart';
import 'package:geopod/services/map_settings_service.dart';
import 'package:geopod/services/places_service.dart'
    show PlacesService, PlacesCacheManager, placesChangeNotifier;

/// Mixin providing state management and lifecycle methods for GeoMapWidget.
mixin GeoMapStateMixin<T extends StatefulWidget>
    on State<T>, SingleTickerProviderStateMixin<T>, WidgetsBindingObserver {
  List<Place> allPlaces = [];
  final Set<String> savingPlaceIds = {};
  bool isLoadingPlaces = false;
  MapSettings mapSettings = MapSettings(
    mapSource: MapSettings.getDefaultMapSource(),
  );
  bool isLoggedIn = false;
  late AnimationController animController;
  late Animation<double> fadeAnim;
  bool initialAnimComplete = false;
  bool isPostLoginRefresh = false;
  final GdeltNewsService newsService = GdeltNewsService();
  List<NewsMarker> newsMarkers = [];
  bool showNewsMarkers = false;
  bool isLoadingNews = false;

  void initAnimations() {
    animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    fadeAnim = CurvedAnimation(parent: animController, curve: Curves.easeOut);
    animController.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        setState(() {
          initialAnimComplete = true;
          isPostLoginRefresh = false;
        });
      }
    });
  }

  void initStateSetup() {
    initAnimations();
    isLoggedIn = AuthDataManager.isLoggedInSync();
    authStateNotifier.addListener(onAuthStateChanged);
    placesChangeNotifier.addListener(onPlacesChanged);
    loadSettingsSync();
    verifyLoginStateAndLoadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) animController.forward();
    });
    WidgetsBinding.instance.addObserver(this as WidgetsBindingObserver);
  }

  void disposeResources() {
    animController.dispose();
    newsService.dispose();
    authStateNotifier.removeListener(onAuthStateChanged);
    placesChangeNotifier.removeListener(onPlacesChanged);
    WidgetsBinding.instance.removeObserver(this as WidgetsBindingObserver);
  }

  void onPlacesChanged() {
    if (mounted && isLoggedIn) loadAllPlaces(forceRefresh: false);
  }

  void onAuthStateChanged() {
    if (!mounted) return;
    final wasLoggedIn = isLoggedIn;
    final isNowLoggedIn = authStateNotifier.value;
    if (isNowLoggedIn == wasLoggedIn) return;
    setState(() => isLoggedIn = isNowLoggedIn);
    if (isNowLoggedIn && !wasLoggedIn) {
      handleLogin();
    } else if (!isNowLoggedIn && wasLoggedIn) {
      handleLogout();
    }
  }

  Future<void> handleLogin() async {
    if (!mounted) return;
    isPostLoginRefresh = true;
    initialAnimComplete = false;
    setState(() => isLoggedIn = true);
    final places = await PlacesService.refreshPodDataOnly();
    if (mounted) setState(() => allPlaces = places);
  }

  Future<void> handleLogout() async {
    await PlacesService.clearPodCacheOnly();
    if (!mounted) return;
    isPostLoginRefresh = false;
    initialAnimComplete = false;
    setState(() => isLoggedIn = false);
    final localPlaces = await PlacesService.loadLocalPlaces();
    if (mounted) setState(() => allPlaces = localPlaces);
  }

  void loadSettingsSync() {
    MapSettingsService.loadSettings()
        .then((s) {
          if (mounted) setState(() => mapSettings = s);
        })
        .catchError((_) {});
  }

  Future<void> verifyLoginStateAndLoadData() async {
    final actuallyLoggedIn = await checkLoggedIn();
    if (!mounted) return;
    if (isLoggedIn != actuallyLoggedIn) {
      setState(() => isLoggedIn = actuallyLoggedIn);
      authStateNotifier.value = actuallyLoggedIn;
      PlacesService.clearCache();
    }
    final cm = PlacesCacheManager();
    final cached = cm.allPlaces;
    final cacheState = cm.wasLoggedInWhenCached;
    if (cached != null && cacheState == isLoggedIn) {
      setState(() => allPlaces = List.from(cached));
    } else {
      if (cached != null && cacheState != isLoggedIn) {
        PlacesService.clearCache();
      }
      await loadAllPlaces(forceRefresh: true);
    }
  }

  Future<void> loadAllPlaces({bool forceRefresh = false}) async {
    final cm = PlacesCacheManager();
    if (cm.allPlaces == null) setState(() => isLoadingPlaces = true);
    try {
      final places = await PlacesService.fetchPlaces(
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          allPlaces = List.from(places);
          isLoadingPlaces = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => isLoadingPlaces = false);
    }
  }

  void updateMapSettings(MapSettings ns, {required bool mapSourceChanged}) {
    setState(() => mapSettings = ns);
  }
}
