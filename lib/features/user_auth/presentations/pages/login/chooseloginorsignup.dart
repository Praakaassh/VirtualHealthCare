import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:virtual_healthcare_assistant/features/user_auth/presentations/pages/Homepage/homepage.dart';
import 'package:virtual_healthcare_assistant/features/user_auth/presentations/pages/login/loginpage.dart';
import 'package:virtual_healthcare_assistant/features/user_auth/presentations/pages/login/signuppage.dart';
import 'package:virtual_healthcare_assistant/features/user_auth/presentations/pages/settings/personaldetails.dart';

class ChooseSignupOrLogin extends StatefulWidget {
  const ChooseSignupOrLogin({super.key});

  @override
  _ChooseSignupOrLoginState createState() => _ChooseSignupOrLoginState();
}

class _ChooseSignupOrLoginState extends State<ChooseSignupOrLogin> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkIfLoggedIn();
  }

  Future<void> _checkIfLoggedIn() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      // User is already logged in, navigate to HomePage
      await _checkUserDetails(context);
    }
  }

  Future<User?> _signInWithGoogle(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);

      // After successful login, check if personal details are completed
      await _checkUserDetails(context);

      return userCredential.user;
    } catch (e) {
      print('Error signing in with Google: $e');
      setState(() {
        _isLoading = false;
      });
      return null;
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
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Image above the text
                Image.asset(
                  'assets/images/hello_image.jpg', // Replace with your image path
                  height: 180,
                ),
                const SizedBox(height: 30),
                // Stylish "Hello" text
                Text(
                  'Hello!',
                  style: TextStyle(
                    fontSize: 50,
                    fontWeight: FontWeight.w900,
                    color: Colors.blueAccent,
                    fontFamily: 'Gupter', // Use your preferred font
                  ),
                ),
                const SizedBox(height: 10),
                // Subtitle text
                Text(
                  'Welcome to PanaPetti!\nLog in, create an account, or sign in with Google to get started.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 40),
                // Buttons: Log In, Create Account, and Sign in with Google
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Log In Button
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                        // Navigate to Log In page
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => LoginPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Log In',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Create Account Button
                    OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                        // Navigate to Create Account page
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => SignUpPage()),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.blueAccent, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Sign in with Google Button
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : () => _signInWithGoogle(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Image.asset(
                        'assets/images/google_logo.png', // Replace with Google logo asset
                        height: 20,
                      ),
                      label: const Text(
                        'Sign in with Google',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}