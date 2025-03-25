import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:virtual_healthcare_assistant/features/user_auth/presentations/pages/Homepage/homepage.dart';
import 'package:virtual_healthcare_assistant/features/user_auth/presentations/pages/login/loginpage.dart';
import 'package:virtual_healthcare_assistant/features/user_auth/presentations/pages/settings/personaldetails.dart';

import '../../user_auth/presentations/pages/login/chooseloginorsignup.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthentication();
    });
  }


  Future<void> _checkAuthentication() async {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      // User is logged in, check if details are completed
      await _checkUserDetails(context);
    } else {
      // User is not logged in, navigate to ChooseSignupOrLogin
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ChooseSignupOrLogin()),
      );
    }
  }
  Future<void> _checkUserDetails(BuildContext context) async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Fetch user data from Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      // Check if the user has completed their details
      bool detailsCompleted =
          userDoc.exists && userDoc['detailsCompleted'] == true;

      // Navigate to the respective page based on detailsCompleted
      if (detailsCompleted) {
        // If details are completed, go to HomePage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } else {
        // If details are not completed, go to PersonalDetailsPage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PersonalDetailsPage()),
        );
      }
    } catch (e) {
      print('Error checking details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(), // Show a loading indicator
      ),
    );
  }
}