import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoPod',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  String? _selectedMarkerText;

  // Define your points of interest - Larrakia significant sites near Darwin
  final List<MarkerData> _markers = [
    MarkerData(
      position: LatLng(-12.4634, 130.8456), // Darwin city center
      title: 'Garramilla (Darwin)',
      description:
          'The traditional Larrakia name for Darwin, meaning "white stone"',
    ),
    MarkerData(
      position: LatLng(-12.4686, 130.8403),
      title: 'Stokes Hill',
      description:
          'A site where the Larrakia people believe the spiritual ancestor "Chinute Chinute" lives, manifesting as a tawny frogmouth.',
    ),
    MarkerData(
      position: LatLng(-12.4294, 130.8350),
      title: 'Mindil Beach',
      description:
          'One of several popular sites around Darwin that holds specific cultural meaning for the Larrakia people.',
    ),
    MarkerData(
      position: LatLng(-12.3771, 130.8765),
      title: 'Rapid Creek',
      description: 'An important Larrakia cultural site in Darwin.',
    ),
    MarkerData(
      position: LatLng(-12.3589, 130.8655),
      title: 'Casuarina Beach',
      description: 'Significant coastal site for Larrakia people',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GeoPod'), elevation: 2),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(-12.4634, 130.8456), // Darwin
              initialZoom: 12.0,
              minZoom: 3.0,
              maxZoom: 18.0,
              onTap: (_, __) {
                setState(() {
                  _selectedMarkerText = null;
                });
              },
            ),
            children: [
              // OpenStreetMap tile layer
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.togaware.geopod',
              ),
              // Marker layer
              MarkerLayer(
                markers: _markers.map((markerData) {
                  return Marker(
                    point: markerData.position,
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMarkerText =
                              '${markerData.title}\n${markerData.description}';
                        });
                      },
                      child: const Icon(
                        Icons.location_on,
                        size: 40,
                        color: Colors.red,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          // Popup for selected marker
          if (_selectedMarkerText != null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Card(
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedMarkerText!,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _selectedMarkerText = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'zoom_in',
            mini: true,
            child: const Icon(Icons.add),
            onPressed: () {
              _mapController.move(
                _mapController.camera.center,
                _mapController.camera.zoom + 1,
              );
            },
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'zoom_out',
            mini: true,
            child: const Icon(Icons.remove),
            onPressed: () {
              _mapController.move(
                _mapController.camera.center,
                _mapController.camera.zoom - 1,
              );
            },
          ),
        ],
      ),
    );
  }
}

class MarkerData {
  final LatLng position;
  final String title;
  final String description;

  MarkerData({
    required this.position,
    required this.title,
    required this.description,
  });
}
