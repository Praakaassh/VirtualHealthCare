import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:virtual_healthcare_assistant/features/user_auth/presentations/pages/settings/timezone.dart';
import 'package:virtual_healthcare_assistant/features/user_auth/presentations/pages/username.dart';

class Settings extends StatefulWidget {
  final String? userName;
  final VoidCallback? onProfileUpdated; // Add callback parameter

  const Settings({super.key, this.userName, this.onProfileUpdated});

  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  String? _profileImageUrl;
  bool _isUploading = false;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
    _loadUserName();
  }

  Future<void> _loadProfileImage() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _profileImageUrl = userData['profileImageUrl'];
          });
        }
      }
    } catch (e) {
      print('Error loading profile image: $e');
      _showErrorMessage('Error loading profile image');
    }
  }

  void _loadUserName() {
    setState(() {
      _userName = widget.userName;
      if (_userName == null) {
        _fetchUserNameFromFirestore();
      }
    });
  }

  Future<void> _fetchUserNameFromFirestore() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _userName = userData['name'] as String?;
          });
        }
      }
    } catch (e) {
      print('Error fetching username: $e');
    }
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _uploadImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512, // Limit image size
        maxHeight: 512,
        imageQuality: 80, // Compress image
      );

      if (image == null) return;

      setState(() {
        _isUploading = true;
      });

      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        // Create unique filename with timestamp
        String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        String fileName = 'profile_${currentUser.uid}_$timestamp.jpg';

        // Create reference to the file location
        Reference storageRef = _storage
            .ref()
            .child('users')
            .child(currentUser.uid)
            .child('profile_images')
            .child(fileName);

        // Create file metadata
        SettableMetadata metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploaded_by': currentUser.uid,
            'timestamp': DateTime.now().toString(),
          },
        );

        // Upload file with metadata
        File imageFile = File(image.path);
        UploadTask uploadTask = storageRef.putFile(imageFile, metadata);

        // Monitor upload progress
        uploadTask.snapshotEvents.listen(
              (TaskSnapshot snapshot) {
            double progress = snapshot.bytesTransferred / snapshot.totalBytes;
            print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
          },
          onError: (error) {
            _showErrorMessage('Error during upload: $error');
          },
        );

        // Wait for upload to complete and get URL
        await uploadTask;
        String downloadUrl = await storageRef.getDownloadURL();

        // Update Firestore with new image URL
        await _firestore.collection('users').doc(currentUser.uid).update({
          'profileImageUrl': downloadUrl,
          'lastProfileUpdate': FieldValue.serverTimestamp(),
        });

        setState(() {
          _profileImageUrl = downloadUrl;
          _isUploading = false;
        });

        _showSuccessMessage('Profile picture updated successfully');

        // Notify HomePage to re-fetch the profile picture
        widget.onProfileUpdated?.call();

        // Delete old profile picture if exists (optional)
        try {
          if (_profileImageUrl != null && _profileImageUrl != downloadUrl) {
            await _storage.refFromURL(_profileImageUrl!).delete();
          }
        } catch (e) {
          print('Error deleting old profile picture: $e');
        }
      }
    } catch (e) {
      print('Error uploading image: $e');
      setState(() {
        _isUploading = false;
      });
      _showErrorMessage('Error uploading image. Please try again.');
    }
  }

  Future<void> _logOut(BuildContext context) async {
    try {
      await _auth.signOut();
      Navigator.pushReplacementNamed(context, '/chooseLoginOrSignup');
    } catch (e) {
      print('Error logging out: $e');
      _showErrorMessage('Error logging out');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(20),
        color: Colors.grey[200],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            const Text(
              'Settings',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 20),

            // Profile Container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: _isUploading ? null : _uploadImage,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue[100],
                          ),
                          child: _isUploading
                              ? const SizedBox(
                            width: 50,
                            height: 50,
                            child: CircularProgressIndicator(),
                          )
                              : _profileImageUrl != null
                              ? CircleAvatar(
                            radius: 25,
                            backgroundImage: NetworkImage(_profileImageUrl!),
                          )
                              : const Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      _userName ?? 'User',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Settings Options Container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Transform.rotate(
                      angle: 90 * 3.1415926535897932 / 180,
                      child: const Icon(
                        Icons.key,
                        color: Colors.blue,
                      ),
                    ),
                    title: const Text('Accounts'),
                    onTap: () {},
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.notifications, color: Colors.blue),
                    title: const Text('Notification Settings'),
                    onTap: () {},
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.info, color: Colors.blue),
                    title: const Text('About Us'),
                    onTap: () {},
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.access_time, color: Colors.blue),
                    title: const Text('Timezone'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const Timezone()),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      'Log Out',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () => _logOut(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}