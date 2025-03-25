import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:virtual_healthcare_assistant/features/user_auth/presentations/pages/Homepage/appointment.dart';
import 'dart:async';
import 'package:virtual_healthcare_assistant/features/user_auth/presentations/pages/Homepage/chatbot.dart';
import 'package:virtual_healthcare_assistant/features/user_auth/presentations/pages/Homepage/docupload.dart';
import 'package:virtual_healthcare_assistant/features/user_auth/presentations/pages/Homepage/reminder.dart';
import 'package:virtual_healthcare_assistant/features/user_auth/presentations/pages/map/gmap.dart';
import 'package:virtual_healthcare_assistant/features/user_auth/presentations/pages/settings/settings.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_database/firebase_database.dart';
import 'docretrieval.dart';

// Define the Reminder class (copied from Reminders.dart for consistency)
class Reminder {
  final String medicationName;
  final int timestamp;
  final String dosage;
  final bool notified;
  final String id;

  Reminder({
    required this.medicationName,
    required this.timestamp,
    required this.dosage,
    this.notified = false,
    required this.id,
  });

  factory Reminder.fromJson(String id, Map<dynamic, dynamic> json) {
    return Reminder(
      id: id,
      medicationName: json['medicationName']?.toString() ?? 'Unknown',
      timestamp: json['timestamp'] is int ? json['timestamp'] : 0,
      dosage: json['dosage']?.toString() ?? 'Unknown',
      notified: json['notified'] == true,
    );
  }
}

class HomePage extends StatefulWidget {
  final String? userName;

  const HomePage({super.key, this.userName});

  @override
  _HomepageState createState() => _HomepageState();
}

class _HomepageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _selectedIndex = 0;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  Timer? _topBarTimer;
  List<Map<String, String>> _prefetchedDocuments = [];
  bool _isLoadingDocuments = false;
  List<AppointmentData> _upcomingAppointments = [];
  List<Reminder> _medicationReminders = [];
  late firestore.FirebaseFirestore _firestore;
  String? _userName;
  String? _profileImageUrl; // To store the profile image URL
  StreamSubscription<DatabaseEvent>? _reminderSubscription;

  // Define the color scheme based on the screenshot
  final Color primaryColor = const Color(0xFF1976D2); // Blue accent color
  final Color backgroundColor = Colors.grey[100]!; // Light grayish-white background
  final Color cardColor = Colors.white; // White cards
  final Color textColor = Colors.black; // Primary text color
  final Color secondaryTextColor = Colors.grey; // Secondary text color
  final Color unselectedColor = Colors.grey; // Unselected icon/label color

  @override
  void initState() {
    super.initState();
    _firestore = firestore.FirebaseFirestore.instance;
    _userName = widget.userName;
    _fetchUserName();
    _fetchProfileImage(); // Fetch the profile image
    _fetchAppointments();
    _fetchReminders();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 1), () {
        _showTopBar();
      });
      _prefetchDocuments();
    });
  }

  // Fetch the profile image from Firebase Storage
  Future<void> _fetchProfileImage() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('User not logged in');
        return;
      }

      // Add more logging
      print('Fetching profile image for user: ${user.uid}');

      // First, try to get the URL from Firestore
      firestore.DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        String? firestoreImageUrl = userDoc.get('profileImageUrl');
        if (firestoreImageUrl != null) {
          print('Found profile image URL in Firestore: $firestoreImageUrl');
          setState(() {
            _profileImageUrl = firestoreImageUrl;
          });
          return;
        }
      }

      // If Firestore method fails, fall back to storage method
      Reference storageReference = FirebaseStorage.instance
          .ref()
          .child('users/${user.uid}/profile_images/');

      ListResult result = await storageReference.listAll();
      print('Number of profile images found: ${result.items.length}');

      if (result.items.isNotEmpty) {
        result.items.sort((a, b) {
          int timestampA = int.parse(a.name.split('_').last.replaceAll('.jpg', ''));
          int timestampB = int.parse(b.name.split('_').last.replaceAll('.jpg', ''));
          return timestampB.compareTo(timestampA);
        });

        String downloadUrl = await result.items.first.getDownloadURL();
        print('Most recent profile image URL: $downloadUrl');

        setState(() {
          _profileImageUrl = downloadUrl;
        });
      } else {
        print('No profile images found in users/${user.uid}/profile_images/');
      }
    } catch (e) {
      print('Comprehensive error fetching profile image: $e');
      setState(() {
        _profileImageUrl = null;
      });
    }
  }
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good Morning,';
    } else if (hour >= 12 && hour < 17) {
      return 'Good Afternoon,';
    } else if (hour >= 17 && hour < 22) {
      return 'Good Evening,';
    } else {
      return 'Good Night,';
    }
  }

  Future<void> _fetchUserName() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _userName = 'Guest';
      });
      return;
    }

    if (_userName != null) {
      await _saveUsernameToFirestore(user.uid, _userName!);
      return;
    }

    if (user.displayName != null && user.displayName!.isNotEmpty) {
      setState(() {
        _userName = user.displayName;
      });
      await _saveUsernameToFirestore(user.uid, _userName!);
      return;
    }

    try {
      firestore.DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc['name'] != null) {
        setState(() {
          _userName = userDoc['name'] as String;
        });
      } else {
        setState(() async {
          _userName = 'User';
          await _saveUsernameToFirestore(user.uid, _userName!);
        });
      }
    } catch (e) {
      print('Error fetching username from Firestore: $e');
      setState(() async {
        _userName = 'User';
        await _saveUsernameToFirestore(user.uid, _userName!);
      });
    }
  }

  Future<void> _saveUsernameToFirestore(String uid, String username) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'name': username,
        'lastUpdated': firestore.FieldValue.serverTimestamp(),
      }, firestore.SetOptions(merge: true));
    } catch (e) {
      print('Error saving username to Firestore: $e');
    }
  }

  Future<void> _fetchAppointments() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('User not logged in');
        return;
      }

      firestore.QuerySnapshot snapshot = await _firestore
          .collection('appointments')
          .where('userId', isEqualTo: user.uid)
          .get();

      List<AppointmentData> appointments = snapshot.docs.map((doc) {
        return AppointmentData.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      setState(() {
        _upcomingAppointments = appointments;
      });
    } catch (e) {
      print('Error fetching appointments: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load appointments: $e')),
        );
      }
    }
  }

  Future<void> _fetchReminders() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      print("No user ID available, cannot load reminders");
      return;
    }

    final dbRef = FirebaseDatabase.instance.ref("reminders/$userId");

    _reminderSubscription?.cancel();
    _reminderSubscription = dbRef.onValue.listen(
          (event) {
        final snapshot = event.snapshot;
        if (snapshot.exists) {
          final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
          final List<Reminder> loadedReminders = [];
          final now = DateTime.now().millisecondsSinceEpoch;

          data.forEach((key, value) {
            if (value is Map<dynamic, dynamic>) {
              final reminder = Reminder.fromJson(key.toString(), value);
              if (reminder.timestamp > now && !reminder.notified) {
                loadedReminders.add(reminder);
              } else {
                _deletePastReminder(userId, reminder); // Optional deletion
              }
            }
          });

          loadedReminders.sort((a, b) => a.timestamp.compareTo(b.timestamp));

          setState(() {
            _medicationReminders = loadedReminders;
          });
        } else {
          setState(() {
            _medicationReminders = [];
          });
        }
      },
      onError: (error) {
        print("Error in database listener: $error");
      },
    );
  }

  Future<void> _deletePastReminder(String userId, Reminder reminder) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (reminder.timestamp <= now || reminder.notified) {
        await FirebaseDatabase.instance
            .ref("reminders/$userId/${reminder.id}")
            .remove();
        print("Deleted reminder: ${reminder.medicationName} (ID: ${reminder.id})");
      }
    } catch (e) {
      print("Error deleting reminder: $e");
    }
  }

  void _showTopBar() {
    _animationController.forward();
    _topBarTimer = Timer(const Duration(seconds: 3), () {
      _animationController.reverse();
    });
  }

  void _addAppointment(AppointmentData appointment) {
    bool isDuplicate = _upcomingAppointments.any((existingAppointment) =>
    existingAppointment.hospitalName == appointment.hospitalName &&
        existingAppointment.dateTime == appointment.dateTime);

    if (!isDuplicate) {
      setState(() {
        _upcomingAppointments.add(appointment);
      });
    }
    _fetchAppointments();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _topBarTimer?.cancel();
    _reminderSubscription?.cancel();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get the screen height to calculate 45% of the screen
    final double screenHeight = MediaQuery.of(context).size.height;
    final double topContainerHeight = screenHeight * 0.45;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: backgroundColor, // Set the background color
        body: Stack(
          children: [
            Column(
              children: [
                // Top section (only visible on Home page)
                if (_selectedIndex == 0)
                  Container(
                    height: topContainerHeight, // 45% of screen height
                    padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300], // Changed from Colors.grey[200] to Colors.grey[300]
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.grey[400],
                                  backgroundImage: _profileImageUrl != null
                                      ? NetworkImage(_profileImageUrl!)
                                      : null,
                                  child: _profileImageUrl == null
                                      ? Icon(Icons.person, size: 25, color: Colors.grey[600])
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 10),
                                    Text(
                                      _getGreeting(),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      _userName ?? 'Loading...',
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            IconButton(
                              icon: Container(
                                padding: EdgeInsets.all(4), // Optional padding for better spacing
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2), // White outline
                                ),
                                child: Icon(
                                  Icons.notifications_none,
                                  color: Colors.grey.shade700, // Darker grey for the icon
                                ),
                              ),
                              onPressed: () {
                                _reminderpage(context); // Navigate to Reminders page
                              },
                            ),

                          ],
                        ),
                        const SizedBox(height: 25),
                        const Text(
                          'How Are You ',
                          style: TextStyle(
                            fontSize: 40,
                            //fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const Text(
                          'Feeling Today ?',
                          style: TextStyle(
                            fontSize: 40,
                            //fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Expanded(child: Container()), // Spacer to push buttons to the bottom
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildTopActionButton(
                                icon: Icons.local_hospital_rounded, // Heartbeat icon
                                label: 'Appointment+',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => Appointment(
                                        onAppointmentBooked: _addAppointment,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 10), // Reduced spacing between buttons
                              _buildTopActionButton(
                                icon: Icons.chat_bubble_outline,
                                label: 'Disease Prediction',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const ChatScreen()),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [


                            Text(
                              'Upcoming Appointments',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (_upcomingAppointments.isEmpty)
                              Text(
                                'No upcoming appointments',
                                style: TextStyle(color: secondaryTextColor),
                              )
                            else
                              ..._upcomingAppointments.map((appointment) => _buildAppointmentCard(
                                appointment.hospitalName,
                                appointment.dateTime.toString().substring(0, 16),
                              )),
                            const SizedBox(height: 20),
                            Text(
                              'Medication Reminders',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (_medicationReminders.isEmpty)
                              Text(
                                'No medication reminders',
                                style: TextStyle(color: secondaryTextColor),
                              )
                            else
                              ..._medicationReminders.map((reminder) {
                                final time = DateTime.fromMillisecondsSinceEpoch(reminder.timestamp);
                                return _buildMedicationReminder(
                                  reminder.medicationName,
                                  reminder.dosage,
                                  'Take as prescribed',
                                  TimeOfDay.fromDateTime(time),
                                );
                              }),
                          ],
                        ),
                      ),
                      _buildMapPage(),
                      DocPage(documents: _prefetchedDocuments),
                      const Settings(),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, "Home", 0),        // Home
              _buildNavItem(Icons.map, "Map", 1),          // Map
              _buildNavItem(Icons.description, "Documents", 2), // Documents
              _buildNavItem(Icons.person, "Profile", 3),   // Profile
            ],
          ),
        ),



      ),
    );
  }

  // Helper method to build the top action buttons
  Widget _buildTopActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[300], // Grey background
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white, width: 2), // White outline
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build the condition cards
  Widget _buildConditionCard(String title, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 40,
                color: title == 'My Heart' ? Colors.red : Colors.grey,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: primaryColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to build each navigation item
  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: 50,
        width: isSelected ? 150 : 50,
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(25),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: primaryColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
              : [],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.2 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  icon,
                  size: 24,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
              ),
              if (isSelected)
                FutureBuilder(
                  future: Future.delayed(const Duration(milliseconds: 150)),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      return AnimatedOpacity(
                        opacity: isSelected ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 150),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 90),
                            child: Text(
                              label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(
      BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 15),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapPage() {
    return MapPage(
      onAppointmentBooked: _addAppointment,
    );
  }

  Widget _buildAppointmentCard(String hospitalName, String dateTime) {
    DateTime parsedDateTime = DateTime.parse(dateTime);
    String formattedDateTime = DateFormat('MMMM d, yyyy h:mm a').format(parsedDateTime);

    return Card(
      elevation: 3,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: primaryColor.withOpacity(0.2),
              child: Icon(Icons.local_hospital, color: primaryColor),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hospitalName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    formattedDateTime,
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationReminder(
      String medicineName, String dosage, String instructions, TimeOfDay time) {
    return Card(
      elevation: 3,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.medication, color: Colors.orange),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicineName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    dosage,
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    instructions,
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${time.hour}:${time.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _prefetchDocuments() async {
    if (_isLoadingDocuments) return;

    setState(() {
      _isLoadingDocuments = true;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('User not logged in.');
        setState(() {
          _isLoadingDocuments = false;
        });
        return;
      }

      Reference storageReference = FirebaseStorage.instance.ref().child('uploads/${user.uid}');
      ListResult result = await storageReference.listAll();

      List<Map<String, String>> documents = [];
      for (Reference ref in result.items) {
        String url = await ref.getDownloadURL();
        final metadata = await ref.getMetadata();
        String fileName = metadata.customMetadata?['filename'] ?? ref.name;
        documents.add({
          'url': url,
          'fileName': fileName,
          'contentType': metadata.contentType ?? 'application/octet-stream',
        });
      }

      setState(() {
        _prefetchedDocuments = documents;
        _isLoadingDocuments = false;
      });
    } catch (e) {
      print('Error prefetching documents: $e');
      setState(() {
        _isLoadingDocuments = false;
      });
    }
  }

  void _showUploadOptions(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const DocumentUploadPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
      ),
    );
  }

  void _reminderpage(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const Reminders(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
      ),
    );
  }

  void _showDocuments(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => DocPage(
          documents: _prefetchedDocuments,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null) {
        PlatformFile file = result.files.first;
        print('File picked: ${file.name}');
        await _uploadFileToFirebase(File(file.path!));
      } else {
        print('No file selected.');
      }
    } catch (e) {
      print('Error picking file: $e');
    }
  }

  Future<void> refreshDocuments() async {
    await _prefetchDocuments();
  }

  Future<void> _takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);

      if (photo != null) {
        print('Photo taken: ${photo.path}');
        await _uploadFileToFirebase(File(photo.path));
      } else {
        print('No photo taken.');
      }
    } catch (e) {
      print('Error taking photo: $e');
    }
  }

  Future<void> _uploadFileToFirebase(File file) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('User not logged in.');
        return;
      }

      String fileName = file.path.split('/').last;
      Reference storageReference = FirebaseStorage.instance
          .ref()
          .child('uploads/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_$fileName');

      await storageReference.putFile(
        file,
        SettableMetadata(
          customMetadata: {
            'fileName': fileName,
          },
        ),
      );

      print('File uploaded successfully.');
      String downloadURL = await storageReference.getDownloadURL();
      print('Download URL: $downloadURL');
      await _prefetchDocuments();
    } catch (e) {
      print('Error uploading file: $e');
    }
  }
}