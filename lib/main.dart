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

  // Define your points of interest
  final List<MarkerData> _markers = [
    MarkerData(
      position: LatLng(-35.2809, 149.1300), // Canberra
      title: 'The Playhouse',
      description:
          'This has been a significant cultural hub for the Arts in Canberra.',
    ),
    MarkerData(
      position: LatLng(-35.3075, 149.1244),
      title: 'Parliament House',
      description:
          'This is where our politicians spend to much time arguing '
          'rather than debating.',
    ),
    MarkerData(
      position: LatLng(-35.2915, 149.1351),
      title: 'Lake Burley Griffin',
      description:
          'The central basin supports regular Arts events for the Canberra community',
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
              initialCenter: LatLng(-35.2809, 149.1300), // Canberra
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
