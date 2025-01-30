import 'package:flutter/material.dart';
import 'package:virtual_healthcare_assistant/features/user_auth/presentations/pages/map/gmap.dart';
import 'package:virtual_healthcare_assistant/features/user_auth/presentations/pages/settings/settings.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomepageState createState() => _HomepageState();
}

class _HomepageState extends State<HomePage> {
  final PageController _pageController = PageController();
  int _selectedIndex = 0;

  // Page navigation logic
  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return false; // Prevent back navigation to login page
      },
      child: Scaffold(
        body: Column(
          children: [
            // PageView for navigation
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: [
                  // Home Page
                  const Center(child: Text("Welcome to the Home Page")),
                  // Map Page
                  const MapPage(),
                  // Notifications Page
                  const Center(child: Text("Notifications Page")),
                  // Settings Page
                  const Settings(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            _pageController.jumpToPage(index); // Slide to the selected page
          },
          selectedItemColor: Colors.blue, // Change the color of the selected icon to blue
          unselectedItemColor: Colors.grey, // Change the color of the unselected icons
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map),
              label: "Maps",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications),
              label: "Notifications",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: "Settings",
            ),
          ],
        ),
      ),
    );
  }
}
