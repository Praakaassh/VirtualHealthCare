import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordPage extends StatefulWidget {
  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  bool isEmailSent = false; // To track if email was sent

  // Function to send the verification email (Password Reset Email)
  Future<void> _sendVerificationCode(BuildContext context) async {
    String email = _emailController.text.trim();

    if (email.isEmpty) {
      _showErrorDialog(context, "Please enter your email.");
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      setState(() {
        isEmailSent = true;
      });

      // Show success dialog after sending the verification email
      _showSuccessDialog(context, "A verification code has been sent to your email.");
    } catch (e) {
      _showErrorDialog(context, "Failed to send verification email. Please try again.");
    }
  }

  // Function to change password after email verification
  Future<void> _changePassword(BuildContext context) async {
    String newPassword = _newPasswordController.text.trim();

    if (newPassword.isEmpty) {
      _showErrorDialog(context, "Please enter a new password.");
      return;
    }

    try {
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null && user.emailVerified) {
        // If email is verified, update the password
        await user.updatePassword(newPassword);

        // Show success dialog
        _showSuccessDialog(context, "Password has been successfully updated.");
      } else {
        _showErrorDialog(context, "Please verify your email before changing the password.");
      }
    } catch (e) {
      _showErrorDialog(context, "Failed to change the password. Please try again.");
    }
  }

  // Show an error dialog
  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // Show a success dialog
  void _showSuccessDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Success"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Forgot Password"),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.lock_reset, size: 100, color: Colors.blue),
            const SizedBox(height: 40),

            // Email input field
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 20),

            // Button to send verification code
            ElevatedButton(
              onPressed: () => _sendVerificationCode(context),
              child: const Text('Send Verification Code'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.blue,
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),

            const SizedBox(height: 40),
            if (isEmailSent)
              const Text(
                "A reset link has been sent to your email.",
                style: TextStyle(color: Colors.green, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            // New Password input field (visible only after email is verified)

          ],
        ),
      ),
    );
  }
}