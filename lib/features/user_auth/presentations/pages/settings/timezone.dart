import 'dart:async';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class Timezone extends StatefulWidget {
  const Timezone({super.key});

  @override
  State<Timezone> createState() => _TimezoneState();
}

class _TimezoneState extends State<Timezone> {
  late Timer _timer;
  String _currentTime = '';

  @override
  void initState() {
    super.initState();
    _initializeTimezone();
    _startClock();
  }

  // Initialize the timezone database and set the initial time
  void _initializeTimezone() {
    tz.initializeTimeZones(); // Load timezone data
    _updateTime(); // Set initial time
  }

  // Update the current time based on India's timezone (Asia/Kolkata)
  void _updateTime() {
    final indiaTimezone = tz.getLocation('Asia/Kolkata'); // India's timezone
    final now = tz.TZDateTime.now(indiaTimezone); // Get current time in IST
    setState(() {
      _currentTime = now.toString().split('.')[0]; // Format to exclude microseconds
    });
  }

  // Start a timer to update the time every second
  void _startClock() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
  }

  @override
  void dispose() {
    _timer.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timezone Settings'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.access_time,
                size: 100,
                color: Colors.blue,
              ),
              const SizedBox(height: 20),
              const Text(
                'Current Time in India (IST)',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _currentTime.isEmpty ? 'Loading...' : _currentTime,
                style: const TextStyle(
                  fontSize: 20,
                  fontFamily: 'monospace', // Monospace for a clock-like feel
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Go back to Settings page
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text(
                  'Back to Settings',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}