import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:virtual_healthcare_assistant/features/user_auth/presentations/pages/Homepage/homepage.dart';

class PersonalDetailsPage extends StatefulWidget {
  const PersonalDetailsPage({super.key});

  @override
  State<PersonalDetailsPage> createState() => _PersonalDetailsPageState();
}

class _PersonalDetailsPageState extends State<PersonalDetailsPage> {
  final TextEditingController dobController = TextEditingController();
  String? userName; // To store the fetched username
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    _initializeDetails();
    _fetchUserName();
  }

  Future<void> _initializeDetails() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists || userDoc['detailsCompleted'] == null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .set({
          'detailsCompleted': false,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error initializing details: $e');
    }
  }

  Future<void> _fetchUserName() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      setState(() {
        userName = userDoc['name'];
      });
    } catch (e) {
      print('Error fetching username: $e');
    }
  }

  Future<void> _saveDetails() async {
    try {
      if (selectedDate == null) {
        print('Error: Date of birth not selected');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select your date of birth')),
        );
        return;
      }

      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('Error: User is not logged in');
        return;
      }

      int age = _calculateAge(selectedDate!);

      await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).set({
        'date_of_birth': selectedDate?.toIso8601String(),
        'age': age,
        'detailsCompleted': true,
      }, SetOptions(merge: true));

      print('Details saved successfully: detailsCompleted set to true');

      // Navigate to HomePage and pass the fetched username
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(userName: userName), // Pass userName
        ),
      );
    } catch (e) {
      print('Error saving details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving details: $e')),
      );
    }
  }

  int _calculateAge(DateTime dob) {
    DateTime today = DateTime.now();
    int age = today.year - dob.year;

    if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) {
      age--;
    }

    return age;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null && pickedDate != selectedDate) {
      setState(() {
        selectedDate = pickedDate;
        dobController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(userName != null ? 'Hello, $userName!' : 'Hello!'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            TextField(
              controller: dobController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Date of Birth',
                hintText: 'Select your date of birth',
                suffixIcon: Icon(Icons.calendar_today),
              ),
              onTap: () => _selectDate(context),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveDetails,
              child: const Text('Save Details'),
            ),
          ],
        ),
      ),
    );
  }
}