import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    // Add sample data for hospitals and medical shops.
    _addMarkers();
  }

void _addMarkers() {
  // Example data with Map<String, Object>
  var hospitals = [
    {
      'id': '1',
      'name': 'General Hospital',
      'location': LatLng(12.9716, 77.5946),
      'icu': true,
      'open': true,
      'type': 'General',
    },
    {
      'id': '2',
      'name': 'City Medical Shop',
      'location': LatLng(12.9756, 77.5976),
      'icu': false,
      'open': false,
      'type': 'Medical Shop',
    }
  ];

  // Adding markers for each hospital
  for (var hospital in hospitals) {
    _markers.add(
      Marker(
        markerId: MarkerId(hospital['id'] as String), // Cast 'id' to String
        position: hospital['location'] as LatLng, // Cast 'location' to LatLng
        infoWindow: InfoWindow(
          title: hospital['name'] as String, // Cast 'name' to String
          snippet:
              '${hospital['type'] as String} | ICU: ${hospital['icu'] as bool ? 'Yes' : 'No'} | Open: ${hospital['open'] as bool ? 'Yes' : 'No'}', // Cast 'type', 'icu', and 'open'
        ),
      ),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hospital Locator'),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(12.9716, 77.5946), // Center map at some location
          zoom: 14.0,
        ),
        markers: _markers,
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // You can add filtering logic here
          // For example: show hospitals with ICU and open status
        },
        child: const Icon(Icons.filter_list),
      ),
    );
  }
}
