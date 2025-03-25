import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:virtual_healthcare_assistant/features/app/splash%20screen/splash_screen.dart';
import 'package:virtual_healthcare_assistant/features/togetherAI/chatprovider.dart';
import 'package:virtual_healthcare_assistant/features/user_auth/presentations/pages/Homepage/reminder.dart' as ReminderLib;
import 'package:virtual_healthcare_assistant/features/user_auth/presentations/pages/Homepage/homepage.dart' as HomepageLib;
import 'package:virtual_healthcare_assistant/features/user_auth/presentations/pages/login/chooseloginorsignup.dart';
import 'package:virtual_healthcare_assistant/features/user_auth/presentations/pages/login/loginpage.dart';
import 'package:virtual_healthcare_assistant/features/user_auth/presentations/pages/login/signuppage.dart';
import 'package:virtual_healthcare_assistant/features/user_auth/presentations/pages/settings/personaldetails.dart';
import 'package:workmanager/workmanager.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
Timer? _globalClockTimer;

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Background message: ${message.notification?.body}");
}

void _startGlobalClock(BuildContext context) {
  _globalClockTimer?.cancel();
  _globalClockTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final dbRef = FirebaseDatabase.instance.ref("reminders/$userId");
    final snapshot = await dbRef.get();
    if (!snapshot.exists) return;

    final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
    final now = DateTime.now();
    final List<ReminderLib.Reminder> reminders = data.entries
        .map((entry) => ReminderLib.Reminder.fromJson(entry.key, entry.value))
        .where((reminder) => !(reminder.notified ?? false))
        .toList();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'medication_reminders_channel',
      'Medication Reminders',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);

    for (var reminder in reminders) {
      final reminderTime = DateTime.fromMillisecondsSinceEpoch(reminder.timestamp);
      if (now.difference(reminderTime).inSeconds.abs() <= 1 && !(reminder.notified ?? false)) {
        await flutterLocalNotificationsPlugin.show(
          reminder.id.hashCode.abs(),
          'Time for ${reminder.medicationName}',
          'Take ${reminder.dosage} now',
          notificationDetails,
        );
        await dbRef.child(reminder.id).update({'notified': true});
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Time for ${reminder.medicationName}: Take ${reminder.dosage} now')),
          );
        }
      }
    }
  });
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyDn0iBDh9CmShYLRtCJsNluwkMR9FVUa4c",
          authDomain: "your-project-id.firebaseapp.com",
          databaseURL: "https://virtual-healthcare-assis-36428-default-rtdb.asia-southeast1.firebasedatabase.app",
          projectId: "virtual-healthcare-assis-36428",
          storageBucket: "virtual-healthcare-assis-36428.firebasestorage.app",
          messagingSenderId: "387375906951",
          appId: "1:387375906951:android:9c3e7aac184c0aae233822",
        ),
      );

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return Future.value(true);

      final dbRef = FirebaseDatabase.instance.ref("reminders/$userId");
      final snapshot = await dbRef.get();
      if (!snapshot.exists) return Future.value(true);

      final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
      final now = DateTime.now();
      final List<ReminderLib.Reminder> reminders = data.entries
          .map((entry) => ReminderLib.Reminder.fromJson(entry.key, entry.value))
          .where((reminder) => !(reminder.notified ?? false))
          .toList();

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'medication_reminders_channel',
        'Medication Reminders',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );
      const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);

      for (var reminder in reminders) {
        final reminderTime = DateTime.fromMillisecondsSinceEpoch(reminder.timestamp);
        if (now.difference(reminderTime).inSeconds.abs() <= 60) {
          await flutterLocalNotificationsPlugin.show(
            reminder.id.hashCode.abs(),
            'Time for ${reminder.medicationName}',
            'Take ${reminder.dosage} now',
            notificationDetails,
          );
          await dbRef.child(reminder.id).update({'notified': true});
        }
      }
    } catch (e) {
      print("Error in background task: $e");
    }
    return Future.value(true);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDn0iBDh9CmShYLRtCJsNluwkMR9FVUa4c",
      authDomain: "your-project-id.firebaseapp.com",
      databaseURL: "https://virtual-healthcare-assis-36428-default-rtdb.asia-southeast1.firebasedatabase.app",
      projectId: "virtual-healthcare-assis-36428",
      storageBucket: "virtual-healthcare-assis-36428.firebasestorage.app",
      messagingSenderId: "387375906951",
      appId: "1:387375906951:android:9c3e7aac184c0aae233822",
    ),
  ).catchError((error) {
    print('Firebase initialization error: $error');
  });

  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin
      .initialize(initializationSettings)
      .then((value) => print("Local notifications initialized: $value"))
      .catchError((error) => print("Error initializing local notifications: $error"));

  const AndroidNotificationChannel remindersChannel = AndroidNotificationChannel(
    'medication_reminders_channel',
    'Medication Reminders',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  if (androidPlugin != null) {
    await androidPlugin
        .createNotificationChannel(remindersChannel)
        .then((_) => print("Medication reminders channel created"));
    final bool? notificationsGranted = await androidPlugin.requestNotificationsPermission();
    print("Notification permission: $notificationsGranted");
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  Workmanager().registerPeriodicTask(
    "reminderCheck",
    "checkRemindersTask",
    initialDelay: Duration(seconds: 10),
    constraints: Constraints(networkType: NetworkType.connected),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ChatProvider()),
      ],
      child: MaterialApp(
        title: 'Virtual Healthcare Assistant',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(primarySwatch: Colors.blue),
        routes: {
          '/chooseLoginOrSignup': (context) => const ChooseSignupOrLogin(),
          '/login': (context) => LoginPage(),
          '/signup': (context) => const SignUpPage(),
          '/home': (context) => const HomepageLib.HomePage(),
          '/personalDetails': (context) => const PersonalDetailsPage(),
          '/reminders': (context) => const ReminderLib.Reminders(),
        },
        home: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _startGlobalClock(context);
            });
            return const SplashScreen();
          },
        ),
      ),
    );
  }
}