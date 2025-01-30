import 'package:flutter/material.dart';




class Settings extends StatefulWidget {
  const Settings({super.key});

  @override

  // ignore: library_private_types_in_public_api
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  String name = '';
  String email = '';

  @override

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Container(
          padding: const EdgeInsets.all(20),
          color: Colors.grey[200],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Settings',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 255, 254, 254),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Info
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue[100],
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name, // Display the loaded name here
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              email, // Display the loaded email here
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(),
                    // Accounts Section
                    ListTile(
                      leading: Transform.rotate(
                        angle: 90 * 3.1415926535897932 / 180, // Rotate the icon 90 degrees
                        child: const Icon(
                          Icons.key,
                          color: Colors.blue,
                        ),
                      ),
                      title: const Text('Accounts'),
                      onTap: () {

                      },
                    ),
                    // Other settings options
                    ListTile(
                      leading: const Icon(Icons.notifications, color: Colors.blue),
                      title: const Text('Notification Settings'),
                      onTap: () {
                        // Handle notification settings action
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.info, color: Colors.blue),
                      title: const Text('About Us'),
                      onTap: () {
                        // Handle about us action
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
