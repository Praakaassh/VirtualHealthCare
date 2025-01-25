import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'homepage.dart';

class SetupYourAccountPage extends StatelessWidget {
  const SetupYourAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Up Your Account'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome! Please complete your profile setup.',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // After setup, update the isFirstTime flag in Firestore
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .update({'isFirstTime': false});
                }

                // Navigate to HomePage
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const HomePage()),
                );
              },
              child: const Text('Complete Setup'),
            ),
          ],
        ),
      ),
    );
  }
}
