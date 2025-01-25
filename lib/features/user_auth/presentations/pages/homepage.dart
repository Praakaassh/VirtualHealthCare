import 'package:flutter/material.dart';
import 'package:virtual_healthcare_assistant/features/user_auth/presentations/pages/personaldetails.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Page'),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome to the Home Page!',
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Navigate to PersonalDetailsPage when button is pressed
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PersonalDetailsPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, // Set button color
                textStyle: const TextStyle(fontSize: 16), // Set text size
              ),
              child: const Text('Go to Personal Details'),
            ),
          ],
        ),
      ),
    );
  }
}
