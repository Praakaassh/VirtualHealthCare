import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:virtual_healthcare_assistant/features/user_auth/presentations/pages/Homepage/appointment.dart';

enum PlaceType { hospitals, pharmacies, both }

class Facility {
  final String name;
  final double lat;
  final double lng;
  final String type;
  final String placeId;
  final String? phone;
  double? distance;

  Facility({
    required this.name,
    required this.lat,
    required this.lng,
    required this.type,
    required this.placeId,
    this.phone,
    this.distance,
  });
}

class MapPage extends StatefulWidget {
  final Function(AppointmentData)? onAppointmentBooked;
  const MapPage({Key? key, this.onAppointmentBooked}) : super(key: key);

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const String apiKey = 'AIzaSyBi64Rv17l9KsYs0civEAQooLfhdFdiCxE'; // Replace with your API key
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _locationSubscription;
  LatLng? _currentLocation;
  Set<Marker> _markers = {};
  bool _isInNavigationMode = false;
  Set<Polyline> _polylines = {};
  PlaceType _selectedPlaceType = PlaceType.both;
  List<Facility> _facilities = [];
  bool _isLoading = false;
  Facility? _selectedFacility;
  String? _distance;
  String? _duration;
  final PanelController _panelController = PanelController();
  Timer? _debounceTimer;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      _searchNearbyPlaces();
      return;
    }

    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/textsearch/json?'
            'query=$query+${_selectedPlaceType == PlaceType.hospitals ? 'hospital' : _selectedPlaceType == PlaceType.pharmacies ? 'pharmacy' : 'hospital|pharmacy'}'
            '&key=$apiKey');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          setState(() {
            _isLoading = true;
            _facilities.clear();
            _polylines.clear();
            _selectedFacility = null;
            _distance = null;
            _duration = null;
          });

          List<Facility> newFacilities = [];
          for (var place in data['results']) {
            final placeId = place['place_id'];
            final detailsUrl = Uri.parse(
                'https://maps.googleapis.com/maps/api/place/details/json?'
                    'place_id=$placeId'
                    '&fields=name,geometry/location,formatted_phone_number'
                    '&key=$apiKey');
            final detailsResponse = await http.get(detailsUrl);
            if (detailsResponse.statusCode == 200) {
              final detailsData = json.decode(detailsResponse.body);
              final result = detailsData['result'];
              final type = place['types'].contains('hospital') ? 'Hospital' : 'Pharmacy';
              newFacilities.add(
                Facility(
                  name: result['name'],
                  lat: result['geometry']['location']['lat'],
                  lng: result['geometry']['location']['lng'],
                  type: type,
                  placeId: placeId,
                  phone: result['formatted_phone_number'] ?? 'Not available',
                ),
              );
            }
          }

          setState(() {
            _facilities = newFacilities;
            _updateDistances(_currentLocation ?? LatLng(0, 0));
            _updateMarkers();
            if (newFacilities.isNotEmpty) {
              _mapController?.animateCamera(
                CameraUpdate.newLatLngZoom(
                  LatLng(newFacilities.first.lat, newFacilities.first.lng),
                  14,
                ),
              );
            }
          });
        }
      }
    } catch (e) {
      print('Error searching places: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error searching places')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<Facility>> _getNearbyPlaces(String type, LatLng center) async {
    final radius = 5000;
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?'
            'location=${center.latitude},${center.longitude}'
            '&radius=$radius'
            '&type=$type'
            '&key=$apiKey');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          List<Facility> facilities = [];
          for (var place in data['results']) {
            final placeId = place['place_id'];
            final detailsUrl = Uri.parse(
                'https://maps.googleapis.com/maps/api/place/details/json?'
                    'place_id=$placeId'
                    '&fields=name,geometry/location,formatted_phone_number'
                    '&key=$apiKey');
            final detailsResponse = await http.get(detailsUrl);
            if (detailsResponse.statusCode == 200) {
              final detailsData = json.decode(detailsResponse.body);
              final result = detailsData['result'];
              facilities.add(
                Facility(
                  name: result['name'],
                  lat: result['geometry']['location']['lat'],
                  lng: result['geometry']['location']['lng'],
                  type: type == 'hospital' ? 'Hospital' : 'Pharmacy',
                  placeId: placeId,
                  phone: result['formatted_phone_number'] ?? 'Not available',
                ),
              );
            }
          }
          return facilities;
        }
      }
      return [];
    } catch (e) {
      print('Error fetching $type: $e');
      return [];
    }
  }

  Future<void> _searchNearbyPlaces({LatLng? center}) async {
    final searchCenter = center ?? _currentLocation;
    if (searchCenter == null) return;

    setState(() {
      _isLoading = true;
      _facilities.clear();
      _polylines.clear();
      // Only reset _selectedFacility, _distance, and _duration if not in navigation mode or panel isn’t open
      if (!_isInNavigationMode && _panelController.isPanelClosed) {
        _selectedFacility = null;
        _distance = null;
        _duration = null;
      }
    });

    try {
      List<Facility> newFacilities = [];
      if (_selectedPlaceType == PlaceType.hospitals || _selectedPlaceType == PlaceType.both) {
        final hospitals = await _getNearbyPlaces('hospital', searchCenter);
        newFacilities.addAll(hospitals);
      }
      if (_selectedPlaceType == PlaceType.pharmacies || _selectedPlaceType == PlaceType.both) {
        final pharmacies = await _getNearbyPlaces('pharmacy', searchCenter);
        newFacilities.addAll(pharmacies);
      }

      setState(() {
        _facilities = newFacilities;
        _updateDistances(searchCenter);
        _updateMarkers();
      });
    } catch (e) {
      print("Error searching nearby places: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error fetching nearby places')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  void _updateDistances(LatLng center) {
    for (var facility in _facilities) {
      facility.distance = _calculateDistance(
        center.latitude,
        center.longitude,
        facility.lat,
        facility.lng,
      );
    }
  }

  Future<void> _getUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });

      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_currentLocation!, 14));
      await _searchNearbyPlaces();
    } catch (e) {
      print("Error getting location: $e");
    }
  }

  Future<void> _getDirections(Facility facility) async {
    if (_currentLocation == null) return;

    final url = Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes');
    final headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': apiKey,
      'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline',
    };

    final body = json.encode({
      'origin': {
        'location': {'latLng': {'latitude': _currentLocation!.latitude, 'longitude': _currentLocation!.longitude}}
      },
      'destination': {
        'location': {'latLng': {'latitude': facility.lat, 'longitude': facility.lng}}
      },
      'travelMode': 'DRIVE',
      'routingPreference': 'TRAFFIC_AWARE',
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final distance = (route['distanceMeters'] / 1000).toStringAsFixed(2) + ' km';
          final duration = route['duration'];
          final seconds = int.parse(duration.replaceAll('s', ''));
          final durationText = '${(seconds / 60).floor()} min ${(seconds % 60)} sec';

          setState(() {
            _selectedFacility = facility;
            _distance = distance;
            _duration = durationText;
            _panelController.open();
          });
        } else {
          throw Exception('No routes found');
        }
      } else {
        throw Exception('Failed to fetch directions: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching directions: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching directions: $e')),
      );
    }
  }

  void _startNavigation(Facility facility) {
    final url = Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes');
    final headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': apiKey,
      'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline',
    };

    final body = json.encode({
      'origin': {
        'location': {'latLng': {'latitude': _currentLocation!.latitude, 'longitude': _currentLocation!.longitude}}
      },
      'destination': {
        'location': {'latLng': {'latitude': facility.lat, 'longitude': facility.lng}}
      },
      'travelMode': 'DRIVE',
      'routingPreference': 'TRAFFIC_AWARE',
    });

    http.post(url, headers: headers, body: body).then((response) {
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final polylinePoints = route['polyline']['encodedPolyline'];
          List<LatLng> points = _decodePolyline(polylinePoints);

          setState(() {
            _markers.clear();
            _markers.add(
              Marker(
                markerId: const MarkerId("userLocation"),
                position: _currentLocation!,
                infoWindow: const InfoWindow(title: "You are here"),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              ),
            );

            _markers.add(
              Marker(
                markerId: MarkerId("destination_${facility.placeId}"),
                position: LatLng(facility.lat, facility.lng),
                infoWindow: InfoWindow(title: facility.name),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  facility.type == 'Hospital' ? BitmapDescriptor.hueRed : BitmapDescriptor.hueGreen,
                ),
              ),
            );

            _polylines.clear();
            _polylines.add(
              Polyline(
                polylineId: PolylineId(facility.placeId),
                points: points,
                color: Colors.blue,
                width: 5,
              ),
            );
          });

          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_currentLocation!, 16));
          _panelController.close();
          _enterNavigationMode(facility);
        }
      }
    }).catchError((e) {
      print('Error starting navigation: $e');
    });
  }

  void _enterNavigationMode(Facility facility) {
    setState(() {
      _isInNavigationMode = true;
    });

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((Position position) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _markers.removeWhere((marker) => marker.markerId.value == "userLocation");
        _markers.add(
          Marker(
            markerId: const MarkerId("userLocation"),
            position: _currentLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          ),
        );

        if (_isInNavigationMode) {
          _mapController?.animateCamera(CameraUpdate.newLatLng(_currentLocation!));
        }
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigating to ${facility.name}'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Exit',
          onPressed: _exitNavigationMode,
        ),
      ),
    );
  }

  void _exitNavigationMode() {
    _locationSubscription?.cancel();

    setState(() {
      _isInNavigationMode = false;
      _updateMarkers();
      _polylines.clear();
    });
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  void _updateMarkers() {
    if (_currentLocation == null) return;

    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId("userLocation"),
          position: _currentLocation!,
          infoWindow: const InfoWindow(title: "You are here"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );

      for (var facility in _facilities) {
        _markers.add(
          Marker(
            markerId: MarkerId("place_${facility.placeId}"),
            position: LatLng(facility.lat, facility.lng),
            infoWindow: InfoWindow(
              title: facility.name,
              snippet: "${facility.type} - ${(facility.distance! / 1000).toStringAsFixed(2)} km away",
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              facility.type == 'Hospital' ? BitmapDescriptor.hueRed : BitmapDescriptor.hueGreen,
            ),
            onTap: () => _getDirections(facility),
          ),
        );
      }
    });
  }

  void _onCameraMove(CameraPosition position) {
    if (_isInNavigationMode) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchNearbyPlaces(center: position.target);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SlidingUpPanel(
            controller: _panelController,
            minHeight: 0,
            maxHeight: MediaQuery.of(context).size.height * 0.3,
            panel: _selectedFacility != null
                ? Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedFacility!.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Distance: ${_distance ?? 'Calculating...'}'),
                  Text('ETA: ${_duration ?? 'Calculating...'}'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _startNavigation(_selectedFacility!),
                        icon: const Icon(Icons.directions),
                        label: const Text('Start'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                      ),
                      if (_selectedFacility!.type == 'Hospital')
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => Appointment(
                                  onAppointmentBooked: widget.onAppointmentBooked,
                                  hospitalName: _selectedFacility!.name,
                                  hospitalPhone: _selectedFacility!.phone,
                                ),
                              ),
                            ).then((result) {
                              if (result != null && result is AppointmentData) {
                                _panelController.close();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Appointment booked at ${result.hospitalName} for ${DateFormat('MMMM d, yyyy h:mm a').format(result.dateTime)}',
                                    ),
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              }
                            });
                          },
                          icon: const Icon(Icons.calendar_today),
                          label: const Text('Book Appointment'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        ),
                    ],
                  ),
                ],
              ),
            )
                : const SizedBox.shrink(),
            body: _currentLocation == null
                ? const Center(child: CircularProgressIndicator())
                : GoogleMap(
              initialCameraPosition: CameraPosition(target: _currentLocation!, zoom: 14),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomGesturesEnabled: true,
              zoomControlsEnabled: false,
              mapToolbarEnabled: true,
              compassEnabled: true,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
              onCameraMove: _onCameraMove,
              gestureRecognizers: {Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer())},
            ),
          ),
          // Search bar (top center)
          if (!_isInNavigationMode)
            Positioned(
              top: 40,
              left: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search hospitals or pharmacies...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  onSubmitted: (value) {
                    _searchPlaces(value);
                  },
                ),
              ),
            ),
          // Filter button (top right, below search bar)
          if (!_isInNavigationMode)
            Positioned(
              top: 80,
              right: 16,
              child: Row(
                children: [
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  FloatingActionButton(
                    mini: true,
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.local_hospital),
                              title: const Text('Hospitals Only'),
                              onTap: () {
                                setState(() => _selectedPlaceType = PlaceType.hospitals);
                                _searchPlaces(_searchController.text);
                                Navigator.pop(context);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.local_pharmacy),
                              title: const Text('Pharmacies Only'),
                              onTap: () {
                                setState(() => _selectedPlaceType = PlaceType.pharmacies);
                                _searchPlaces(_searchController.text);
                                Navigator.pop(context);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.all_inclusive),
                              title: const Text('Both'),
                              onTap: () {
                                setState(() => _selectedPlaceType = PlaceType.both);
                                _searchPlaces(_searchController.text);
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Icon(Icons.filter_list),
                  ),
                ],
              ),
            ),
          // Recenter and navigation controls (bottom right)
          if (_isInNavigationMode)
            Positioned(
              bottom: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton(
                    onPressed: () {
                      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_currentLocation!, 16));
                    },
                    child: const Icon(Icons.my_location),
                    backgroundColor: Colors.blue,
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    onPressed: _exitNavigationMode,
                    child: const Icon(Icons.close),
                    backgroundColor: Colors.red,
                  ),
                ],
              ),
            )
          else
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                onPressed: () {
                  _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_currentLocation!, 14));
                },
                child: const Icon(Icons.my_location),
                backgroundColor: Colors.blue,
              ),
            ),
          // Refresh button (bottom left)
          if (!_isInNavigationMode)
            Positioned(
              bottom: 16,
              left: 16,
              child: FloatingActionButton(
                onPressed: _searchNearbyPlaces,
                child: const Icon(Icons.refresh),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}