import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PersonalDetailsPage extends StatelessWidget {
  const PersonalDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController ageController = TextEditingController();

    Future<void> _saveDetails() async {
      try {
        User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) return;

        await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).set({
          'name': nameController.text,
          'age': int.tryParse(ageController.text) ?? 0,
          'detailsCompleted': true,
        }, SetOptions(merge: true));

        // Navigate back to HomePage
        Navigator.pushReplacementNamed(context, '/home');
      } catch (e) {
        print('Error saving details: $e');
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Your Details'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Age'),
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