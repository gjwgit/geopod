// Tests for ExternalPlace models and marker generation for shared places.

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:geopod/models/external_place.dart';
import 'package:geopod/models/external_places_call_result.dart';
import 'package:geopod/models/place.dart';
import 'package:geopod/services/map_settings_service.dart';
import 'package:geopod/widgets/map/marker_data.dart';

void main() {
  group('ExternalPlace model', () {
    test('instantiates and creates copies with withContent and toFound', () {
      final ext = ExternalPlace(
        sharedTime: '2026-09-07T00:00:00.000Z',
        placeUrl: 'https://alice.solidcommunity.au/places/place_1.json',
        placeFileName: 'place_1.json',
        placeOwner: 'https://alice.solidcommunity.au/profile/card#me',
        permissionGranter: 'https://alice.solidcommunity.au/profile/card#me',
        permissionRecepient: 'https://bob.solidcommunity.au/profile/card#me',
        permissionType: 'grant',
        permissionList: 'read',
      );

      expect(ext.content, isNull);
      expect(ext.placeFileName, 'place_1.json');

      final sample = Place(
        id: '1',
        lat: -35.2809,
        lng: 149.13,
        title: 'Canberra Shared',
        note: 'Shared location note',
        timestamp: '2026-09-07T00:00:00.000Z',
      );

      final withContent = ext.withContent(sample);
      expect(withContent.content, isNotNull);
      expect(withContent.content?.title, 'Canberra Shared');

      final found = withContent.toFound(isSelected: true);
      expect(found.isSelected, isTrue);
      expect(found.content?.title, 'Canberra Shared');
    });

    test(
      'ExternalPlaceListExtension converts to list of FoundExternalPlace',
      () {
        final list = [
          ExternalPlace(
            sharedTime: '2026-09-07T00:00:00.000Z',
            placeUrl: 'https://alice.solidcommunity.au/places/place_1.json',
            placeFileName: 'place_1.json',
            placeOwner: 'https://alice.solidcommunity.au/profile/card#me',
            permissionGranter:
                'https://alice.solidcommunity.au/profile/card#me',
            permissionRecepient:
                'https://bob.solidcommunity.au/profile/card#me',
            permissionType: 'grant',
            permissionList: 'read',
          ),
        ];

        final foundList = list.toListFoundExternalPlace();
        expect(foundList.length, 1);
        expect(foundList.first.isSelected, isFalse);
      },
    );

    test('ExternalPlacesCallResult defaults to empty lists', () {
      const result = ExternalPlacesCallResult();
      expect(result.places, isEmpty);
      expect(result.nonExistentPlaces, isEmpty);
      expect(result.forbiddenPlaces, isEmpty);
      expect(result.encryptionErrorPlaces, isEmpty);
      expect(result.unparseablePlaces, isEmpty);
    });
  });

  group('buildFilteredMarkers with shared places', () {
    test(
      'renders shared places with deep purple color and shared metadata',
      () {
        final settings = MapSettings(
          mapSource: MapSettings.getDefaultMapSource(),
        );

        final ext = ExternalPlace(
          sharedTime: '2026-09-07T00:00:00.000Z',
          placeUrl: 'https://alice.solidcommunity.au/places/place_ext1.json',
          placeFileName: 'place_ext1.json',
          placeOwner: 'https://alice.solidcommunity.au/profile/card#me',
          permissionGranter: 'https://alice.solidcommunity.au/profile/card#me',
          permissionRecepient: 'https://bob.solidcommunity.au/profile/card#me',
          permissionType: 'grant',
          permissionList: 'read',
          content: Place(
            id: 'ext1',
            lat: -33.8688,
            lng: 151.2093,
            title: 'Sydney Opera House',
            note: 'Iconic landmark',
            timestamp: '2026-09-07T00:00:00.000Z',
          ),
        );

        final markers = buildFilteredMarkers(
          allPlaces: [],
          mapSettings: settings,
          savingPlaceIds: {},
          sharedPlaces: [ext],
        );

        expect(markers.length, 1);
        final m = markers.first;
        expect(m.id, 'ext1');
        expect(m.title, 'Sydney Opera House');
        expect(m.isShared, isTrue);
        expect(m.sharedBy, 'https://alice.solidcommunity.au/profile/card#me');
        expect(m.color, Colors.deepPurple);
      },
    );

    test('respects hideAllMarkers setting for shared markers', () {
      final settings = MapSettings(
        mapSource: MapSettings.getDefaultMapSource(),
        hideAllMarkers: true,
      );

      final ext = ExternalPlace(
        sharedTime: '2026-09-07T00:00:00.000Z',
        placeUrl: 'https://alice.solidcommunity.au/places/place_ext1.json',
        placeFileName: 'place_ext1.json',
        placeOwner: 'https://alice.solidcommunity.au/profile/card#me',
        permissionGranter: 'https://alice.solidcommunity.au/profile/card#me',
        permissionRecepient: 'https://bob.solidcommunity.au/profile/card#me',
        permissionType: 'grant',
        permissionList: 'read',
        content: Place(
          id: 'ext1',
          lat: -33.8688,
          lng: 151.2093,
          title: 'Sydney Opera House',
          note: 'Iconic landmark',
          timestamp: '2026-09-07T00:00:00.000Z',
        ),
      );

      final markers = buildFilteredMarkers(
        allPlaces: [],
        mapSettings: settings,
        savingPlaceIds: {},
        sharedPlaces: [ext],
      );

      expect(markers, isEmpty);
    });
  });
}
