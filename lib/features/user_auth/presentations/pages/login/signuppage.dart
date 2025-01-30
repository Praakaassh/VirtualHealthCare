import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:virtual_healthcare_assistant/features/user_auth/fire_base_implementation/Firebase_auth_services.dart';
import 'package:virtual_healthcare_assistant/features/user_auth/presentations/pages/login/loginpage.dart';
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}
class _SignUpPageState extends State<SignUpPage> {
  final FirebaseAuthServices _auth = FirebaseAuthServices();

  final TextEditingController _usernamecontroller = TextEditingController();
  final TextEditingController _emailcontroller = TextEditingController();
  final TextEditingController _passwordcontroller = TextEditingController();

  @override
  void dispose() {
    _usernamecontroller.dispose();
    _emailcontroller.dispose();
    _passwordcontroller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(

        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo or app name (if applicable)
              const SizedBox(height: 132),
              const Icon(
                Icons.account_circle,
                size: 100,
                color: Colors.blue,
              ),
              const SizedBox(height: 40),

              // Full name text field
              TextField(
                controller: _usernamecontroller,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 20),

              // Email text field
              TextField(
                controller: _emailcontroller,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 20),

              // Password text field
              TextField(
                controller: _passwordcontroller,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 20),

              // Confirm password text field
              TextField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 20),

              // Sign Up button
              ElevatedButton(
                onPressed: _signUp,
                child: const Text('Create Account'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.blue,
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
              Row(
                children: [
                  const Expanded(child: Divider(thickness: 1)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('OR'),
                  ),
                  const Expanded(child: Divider(thickness: 1)),
                ],
              ),
              // Already have an account? Login link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account? '),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) =>  LoginPage()),
                      );
                    },
                    child: const Text('Login'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _signUp() async {
    String username = _usernamecontroller.text;
    String email = _emailcontroller.text;
    String password = _passwordcontroller.text;

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Error"),
            content: const Text("Please fill in all fields."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("OK"),
              ),
            ],
          );
        },
      );
      return;
    }

    try {
      // Sign up the user using FirebaseAuth
      User? user = await _auth.signUpWithEmailAndPassword(email, password);

      if (user != null) {
        // Save the username and other details to Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': username,
          'detailsCompleted': false, // Default to false until additional details are entered
          'createdAt': DateTime.now().toIso8601String(), // Optional: Track when the user signed up
        });

        // Navigate to the login page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LoginPage(),
          ),
        );
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Error"),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("OK"),
              ),
            ],
          );
        },
      );
    }
  }

}