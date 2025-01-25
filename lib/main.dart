import 'package:flutter/material.dart';
import 'package:virtual_healthcare_assistant/features/app/splash%20screen/splash_screen.dart';
import 'package:virtual_healthcare_assistant/features/user_auth/presentations/pages/loginpage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:virtual_healthcare_assistant/features/user_auth/presentations/pages/signuppage.dart';

Future main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: splashscreen(
        child: SignUpPage(),
      ),
    );
  }
}
