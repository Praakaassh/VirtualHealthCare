import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentData {
  final String hospitalName;
  final DateTime dateTime;
  final String? id;

  AppointmentData(this.hospitalName, this.dateTime, {this.id});

  Map<String, dynamic> toJson() => {
    'hospitalName': hospitalName,
    'dateTime': dateTime.toIso8601String(),
  };

  factory AppointmentData.fromJson(Map<String, dynamic> json, String id) => AppointmentData(
    json['hospitalName'],
    DateTime.parse(json['dateTime']),
    id: id,
  );
}

class Appointment extends StatefulWidget {
  final Function(AppointmentData)? onAppointmentBooked;
  final String? hospitalName;
  final String? hospitalPhone;

  const Appointment({
    super.key,
    required this.onAppointmentBooked,
    this.hospitalName,
    this.hospitalPhone,
  });

  @override
  State<Appointment> createState() => _AppointmentState();
}

class _AppointmentState extends State<Appointment> {
  List<Map<String, dynamic>> hospitals = [];
  Position? _currentPosition;
  bool _isLoading = false;
  final String apiKey = 'AIzaSyBi64Rv17l9KsYs0civEAQooLfhdFdiCxE';
  final TextEditingController _searchController = TextEditingController();
  late FirebaseFirestore _firestore;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
    if (widget.hospitalName == null) {
      _getCurrentLocationAndHospitals();
    } else {
      hospitals = [
        {
          'name': widget.hospitalName,
          'vicinity': 'Selected from map',
          'phone': widget.hospitalPhone ?? 'Not available'
        }
      ];
    }
  }

  Future<void> _initializeFirebase() async {
    await Firebase.initializeApp();
    _firestore = FirebaseFirestore.instance;
  }

  Future<void> _getCurrentLocationAndHospitals() async {
    setState(() => _isLoading = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are required')),
            );
          }
          return;
        }
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await _fetchNearbyHospitals();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _fetchNearbyHospitals() async {
    if (_currentPosition == null) return;

    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
            '?location=${_currentPosition!.latitude},${_currentPosition!.longitude}'
            '&radius=5000'
            '&type=hospital'
            '&key=$apiKey');

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      await _fetchHospitalDetails(data['results']);
    } else {
      throw Exception('Failed to load nearby hospitals');
    }
  }

  Future<void> _searchHospitals(String query) async {
    setState(() => _isLoading = true);

    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/textsearch/json'
            '?query=$query+hospital'
            '&key=$apiKey');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final hospitalResults = data['results']
            .where((result) => result['types'] != null && result['types'].contains('hospital'))
            .toList();
        await _fetchHospitalDetails(hospitalResults);
      } else {
        throw Exception('Failed to search hospitals');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _fetchHospitalDetails(List<dynamic> results) async {
    List<Map<String, dynamic>> detailedHospitals = [];

    for (var hospital in results) {
      final placeId = hospital['place_id'];
      final detailsUrl = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json'
              '?place_id=$placeId'
              '&fields=name,vicinity,formatted_address,formatted_phone_number,types'
              '&key=$apiKey');

      final detailsResponse = await http.get(detailsUrl);
      if (detailsResponse.statusCode == 200) {
        final detailsData = json.decode(detailsResponse.body);
        final result = detailsData['result'];
        if (result['types'] != null && result['types'].contains('hospital')) {
          detailedHospitals.add({
            'name': result['name'] ?? 'Unknown',
            'vicinity': result['vicinity'] ?? result['formatted_address'] ?? 'No address',
            'phone': result['formatted_phone_number'] ?? 'Not available',
          });
        }
      }
    }

    setState(() {
      hospitals = detailedHospitals;
    });
  }

  Future<void> _makePhoneCall(String phoneNumber, String hospitalName) async {
    if (phoneNumber == 'Not available') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No phone number available')),
        );
      }
      _showAppointmentDetailsDialog(hospitalName);
      return;
    }

    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);

    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
      if (mounted) {
        _showAppointmentConfirmationDialog(hospitalName);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch phone call')),
        );
      }
      _showAppointmentDetailsDialog(hospitalName);
    }
  }

  void _showAppointmentConfirmationDialog(String hospitalName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Appointment with $hospitalName'),
          content: const Text('Was your appointment confirmed?'),
          actions: [
            TextButton(
              child: const Text('No'),
              onPressed: () {
                Navigator.of(context).pop();
                _showAppointmentDetailsDialog(hospitalName);
              },
            ),
            TextButton(
              child: const Text('Yes'),
              onPressed: () {
                Navigator.of(context).pop();
                _showAppointmentDetailsDialog(hospitalName);
              },
            ),
          ],
        );
      },
    );
  }

  Future<AppointmentData> _saveAppointmentToFirebase(AppointmentData appointment) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Add user ID to the appointment data
      Map<String, dynamic> data = appointment.toJson();
      data['userId'] = user.uid;  // Add user ID to the document

      final docRef = await _firestore.collection('appointments').add(data);

      // Create new AppointmentData with the generated ID
      final savedAppointment = AppointmentData(
        appointment.hospitalName,
        appointment.dateTime,
        id: docRef.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Appointment saved successfully with ID: ${docRef.id}')),
        );
      }
      return savedAppointment;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save appointment: $e')),
        );
      }
      rethrow; // Rethrow the exception to maintain error handling
    }
  }
  void _showAppointmentDetailsDialog(String hospitalName, {bool isManual = false}) {
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    TextEditingController hospitalNameController = TextEditingController(text: hospitalName);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isManual ? 'Manual Appointment' : 'Appointment Details for $hospitalName'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isManual)
                      TextField(
                        controller: hospitalNameController,
                        decoration: const InputDecoration(
                          labelText: 'Hospital Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Text(selectedDate == null
                          ? 'Select Date'
                          : 'Date: ${DateFormat('MMMM d, yyyy').format(selectedDate!)}'),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedTime = picked;
                          });
                        }
                      },
                      child: Text(selectedTime == null
                          ? 'Select Time'
                          : 'Time: ${selectedTime!.format(context)}'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Confirm'),
                  onPressed: () async {
                    if (isManual && hospitalNameController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a hospital name')),
                      );
                      return;
                    }
                    if (selectedDate == null || selectedTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select both date and time')),
                      );
                      return;
                    }

                    final appointmentDateTime = DateTime(
                      selectedDate!.year,
                      selectedDate!.month,
                      selectedDate!.day,
                      selectedTime!.hour,
                      selectedTime!.minute,
                    );
                    final finalHospitalName = isManual ? hospitalNameController.text : hospitalName;

                    // Create initial appointment data without ID
                    final initialAppointment = AppointmentData(finalHospitalName, appointmentDateTime);

                    // Save to Firebase and get appointment with ID
                    final savedAppointment = await _saveAppointmentToFirebase(initialAppointment);

                    Navigator.of(context).pop();

                    if (widget.onAppointmentBooked != null) {
                      widget.onAppointmentBooked!(savedAppointment);
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Appointment confirmed with $finalHospitalName',
                          style: const TextStyle(fontSize: 14),
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );

                    Navigator.pop(context, savedAppointment);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addManualAppointment() {
    _showAppointmentDetailsDialog('', isManual: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Appointment'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addManualAppointment,
            tooltip: 'Add Manual Appointment',
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.hospitalName == null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search for hospitals...',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      if (_searchController.text.isNotEmpty) {
                        _searchHospitals(_searchController.text);
                      } else {
                        _getCurrentLocationAndHospitals();
                      }
                    },
                  ),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    _searchHospitals(value);
                  }
                },
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : hospitals.isEmpty
                ? const Center(child: Text('No hospitals found'))
                : ListView.builder(
              itemCount: hospitals.length,
              itemBuilder: (context, index) {
                final hospital = hospitals[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(hospital['name']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(hospital['vicinity']),
                        Text('Phone: ${hospital['phone']}'),
                      ],
                    ),
                    trailing: ElevatedButton(
                      onPressed: () => _makePhoneCall(hospital['phone'], hospital['name']),
                      child: const Text('Book Appointment'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}