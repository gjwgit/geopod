/// Tests for Location Photo Uploads & Visualization (Issue #67).
///
// Time-stamp: <2026-09-07 Amogh>
///
/// Copyright (C) 2026, Software Innovation Institute, ANU.
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program.  If not, see <https://opensource.org/license/gpl-3-0>.
///
/// Authors: Amogh

library;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:geopod/models/media_item.dart';
import 'package:geopod/models/place.dart';
import 'package:geopod/services/map_settings_service.dart';
import 'package:geopod/services/media/media_pod_paths.dart';
import 'package:geopod/widgets/map/marker_data.dart';

void main() {
  group('MediaItem - photo support', () {
    test('instantiates with MediaType.photo and convenience getters work', () {
      const item = MediaItem(
        name: 'Opera House View',
        type: MediaType.photo,
        podRelativePath: 'data/photo/opera.png',
        locationIds: ['place-1', 'place-2'],
      );

      expect(item.type, MediaType.photo);
      expect(item.isPhoto, isTrue);
      expect(item.isAudio, isFalse);
      expect(item.isVideo, isFalse);
      expect(item.name, 'Opera House View');
      expect(item.locationIds, ['place-1', 'place-2']);
    });

    test('serializes and deserializes photo items correctly', () {
      const item = MediaItem(
        name: 'Harbour Bridge',
        type: MediaType.photo,
        podRelativePath: 'data/photo/bridge.jpg',
        isEncrypted: true,
        podItemId: 'uuid-1234',
        locationIds: ['place-sydney'],
      );

      final json = item.toJson();
      expect(json['type'], 'photo');
      expect(json['name'], 'Harbour Bridge');
      expect(json['podRelativePath'], 'data/photo/bridge.jpg');
      expect(json['isEncrypted'], isTrue);
      expect(json['podItemId'], 'uuid-1234');
      expect(json['locationIds'], ['place-sydney']);

      final restored = MediaItem.fromJson(json);
      expect(restored.type, MediaType.photo);
      expect(restored.isPhoto, isTrue);
      expect(restored.name, item.name);
      expect(restored.podRelativePath, item.podRelativePath);
      expect(restored.isEncrypted, isTrue);
      expect(restored.podItemId, 'uuid-1234');
      expect(restored.locationIds, ['place-sydney']);
    });

    test('deserializes legacy "image" type string as MediaType.photo', () {
      final json = {
        'name': 'Scenic View',
        'type': 'image',
        'podRelativePath': 'data/photo/scenic.webp',
      };

      final item = MediaItem.fromJson(json);
      expect(item.type, MediaType.photo);
      expect(item.isPhoto, isTrue);
    });

    test('copyWith works with photo type and locationIds', () {
      const item = MediaItem(
        name: 'Original',
        type: MediaType.photo,
        podRelativePath: 'data/photo/orig.jpg',
      );

      final updated = item.copyWith(
        name: 'Updated Name',
        locationIds: ['loc-1'],
      );

      expect(updated.name, 'Updated Name');
      expect(updated.type, MediaType.photo);
      expect(updated.locationIds, ['loc-1']);
    });
  });

  group('MediaPodPaths - photo paths & MIME types', () {
    test('photo directory and index path constants and helpers', () {
      expect(photoDirName, 'photo');
      expect(photoIndexFileName, 'photo_index.json');
      expect(getPhotoDirPath(), 'data/photo');
      expect(getPhotoIndexPath(), 'data/photo/photo_index.json');
      expect(getPhotoFilePath('photo.jpg'), 'data/photo/photo.jpg');
    });

    test('MIME types for standard image formats', () {
      expect(mimeTypeForFilename('test.jpg'), 'image/jpeg');
      expect(mimeTypeForFilename('test.jpeg'), 'image/jpeg');
      expect(mimeTypeForFilename('test.png'), 'image/png');
      expect(mimeTypeForFilename('test.webp'), 'image/webp');
      expect(mimeTypeForFilename('test.gif'), 'image/gif');
      expect(mimeTypeForFilename('test.svg'), 'image/svg+xml');
    });
  });

  group('MarkerData & Map Visualization', () {
    test('MarkerData holds photo metadata and computes hasPhotos', () {
      final markerWithPhotos = MarkerData(
        position: const LatLng(-33.8568, 151.2153),
        title: 'Sydney Opera House',
        description: 'Iconic performing arts centre',
        id: 'opera-1',
        photoCount: 3,
      );

      expect(markerWithPhotos.photoCount, 3);
      expect(markerWithPhotos.hasPhotos, isTrue);

      final markerWithoutPhotos = MarkerData(
        position: const LatLng(-33.8568, 151.2153),
        title: 'Standard Pin',
        description: 'No photos here',
        id: 'pin-1',
        photoCount: 0,
      );

      expect(markerWithoutPhotos.photoCount, 0);
      expect(markerWithoutPhotos.hasPhotos, isFalse);
    });

    test('buildFilteredMarkers attaches photo counts to markers', () {
      final place1 = Place(
        id: 'p1',
        lat: -35.2809,
        lng: 149.1300,
        title: 'Canberra Central',
        note: 'Capital city',
        timestamp: '2026-01-01',
      );
      final place2 = Place(
        id: 'p2',
        lat: -37.8136,
        lng: 144.9631,
        title: 'Melbourne Central',
        note: 'Art capital',
        timestamp: '2026-01-01',
      );

      final settings = MapSettings(
        mapSource: MapSettings.getDefaultMapSource(),
      );

      final markers = buildFilteredMarkers(
        allPlaces: [place1, place2],
        mapSettings: settings,
        savingPlaceIds: {},
        photoCounts: {'p1': 4, 'p2': 0},
      );

      expect(markers.length, 2);

      final m1 = markers.firstWhere((m) => m.id == 'p1');
      expect(m1.photoCount, 4);
      expect(m1.hasPhotos, isTrue);

      final m2 = markers.firstWhere((m) => m.id == 'p2');
      expect(m2.photoCount, 0);
      expect(m2.hasPhotos, isFalse);
    });
  });
}
