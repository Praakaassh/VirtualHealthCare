import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

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

  Map<String, dynamic> toJson() {
    return {
      'medicationName': medicationName,
      'timestamp': timestamp,
      'dosage': dosage,
      'notified': notified,
    };
  }

  factory Reminder.fromJson(String id, Map<dynamic, dynamic> json) {
    print("Creating Reminder from JSON: $id, $json");
    return Reminder(
      id: id,
      medicationName: json['medicationName']?.toString() ?? 'Unknown',
      timestamp: json['timestamp'] is int ? json['timestamp'] : 0,
      dosage: json['dosage']?.toString() ?? 'Unknown',
      notified: json['notified'] == true,
    );
  }
}

class Reminders extends StatefulWidget {
  const Reminders({super.key});

  @override
  State<Reminders> createState() => _RemindersState();
}

class _RemindersState extends State<Reminders> with WidgetsBindingObserver {
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  DateTime? _selectedTime;
  List<Reminder> _reminders = [];
  bool _isLoading = true;
  StreamSubscription<DatabaseEvent>? _reminderSubscription;
  String _timezoneName = 'Asia/Kolkata';

  final List<String> _medicationSuggestions = [
    'Crocin', 'Calpol', 'Cefixime', 'Cetirizine', 'Ciprofloxacin',
    'Paracetamol', 'Aspirin', 'Ibuprofen', 'Amoxicillin', 'Azithromycin',
    'Dolo', 'Doxycycline', 'Metformin', 'Losartan', 'Atorvastatin'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    tz.initializeTimeZones();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (FirebaseAuth.instance.currentUser == null) {
        Navigator.pushNamed(context, '/login');
        return;
      }
      _setupTimezone();
      _setupFCMAndListeners();
      _loadReminders();
      _checkBatteryOptimization();
      _requestNotificationPermissions();
      _scheduleAllReminders();
    });
  }

  void _setupTimezone() {
    final indiaTimezone = tz.getLocation('Asia/Kolkata');
    setState(() {
      _timezoneName = indiaTimezone.name;
    });
  }

  Future<void> _requestNotificationPermissions() async {
    final status = await Permission.notification.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Notification permission is required for reminders."),
          action: SnackBarAction(label: "Settings", onPressed: () => openAppSettings()),
        ),
      );
    }
    if (Platform.isAndroid) {
      final exactAlarmsStatus = await Permission.scheduleExactAlarm.request();
      if (!exactAlarmsStatus.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Exact alarm permission is needed for precise reminders."),
            action: SnackBarAction(label: "Settings", onPressed: () => openAppSettings()),
          ),
        );
      }
    }
  }

  Future<void> _checkBatteryOptimization() async {
    if (Platform.isAndroid) {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (!status.isGranted) {}
    }
  }

  Future<void> _testNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'medication_reminders_channel',
      'Medication Reminders',
      channelDescription: 'Notifications for medication reminders',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
    );
    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);

    final indiaTimezone = tz.getLocation('Asia/Kolkata');
    final localTime = tz.TZDateTime.now(indiaTimezone);
    final formattedTime = localTime.toString().split('.')[0];

    await flutterLocalNotificationsPlugin
        .show(999, 'Test Notification', 'India time: $formattedTime', notificationDetails);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reminderSubscription?.cancel();
    _nameController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  Future<void> _setupFCMAndListeners() async {
    try {
      await _setupFCM();
    } catch (e) {
      print("Error setting up FCM: $e");
    }
  }

  Future<void> _setupFCM() async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );

    final token = await messaging.getToken();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (token != null && userId != null) {
      await FirebaseDatabase.instance.ref("users/$userId/deviceToken").set(token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
    }

    messaging.onTokenRefresh.listen((newToken) async {
      if (userId != null) {
        await FirebaseDatabase.instance.ref("users/$userId/deviceToken").set(newToken);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', newToken);
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'fcm_channel',
        'FCM Notifications',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
      );
      const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);
      flutterLocalNotificationsPlugin.show(
        0,
        message.notification?.title ?? 'Foreground Message',
        message.notification?.body ?? 'No body',
        notificationDetails,
      );
    });
  }

  Future<void> _loadReminders() async {
    setState(() {
      _isLoading = true;
    });

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(() {
        _isLoading = false;
      });
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

          data.forEach((key, value) {
            if (value is Map<dynamic, dynamic>) {
              final reminder = Reminder.fromJson(key.toString(), value);
              loadedReminders.add(reminder);
            }
          });

          loadedReminders.sort((a, b) => a.timestamp.compareTo(b.timestamp));

          setState(() {
            _reminders = loadedReminders;
            _isLoading = false;
          });

          _scheduleAllReminders();
        } else {
          setState(() {
            _reminders = [];
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        setState(() {
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _scheduleAllReminders() async {
    await flutterLocalNotificationsPlugin.cancelAll();

    final prefs = await SharedPreferences.getInstance();
    List<String> reminderIds = [];
    List<int> reminderTimestamps = [];
    List<String> reminderNames = [];
    List<String> reminderDosages = [];

    final indiaTimezone = tz.getLocation('Asia/Kolkata');
    final now = tz.TZDateTime.now(indiaTimezone);

    for (var reminder in _reminders) {
      final reminderTime = tz.TZDateTime.fromMillisecondsSinceEpoch(indiaTimezone, reminder.timestamp);
      if (reminderTime.isAfter(now) && !reminder.notified) {
        await _scheduleNotification(reminder);

        reminderIds.add(reminder.id);
        reminderTimestamps.add(reminder.timestamp);
        reminderNames.add(reminder.medicationName);
        reminderDosages.add(reminder.dosage);
      }
    }

    await prefs.setStringList('reminder_ids', reminderIds);
    await prefs.setStringList('reminder_names', reminderNames);
    await prefs.setStringList('reminder_dosages', reminderDosages);
    await prefs.setString('reminder_timestamps', reminderTimestamps.join(','));
    await prefs.setString('timezone', _timezoneName);
  }

  Future<void> _scheduleNotification(Reminder reminder) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'medication_reminders_channel',
      'Medication Reminders',
      channelDescription: 'Notifications for medication reminders',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
    );

    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);

    final indiaTimezone = tz.getLocation('Asia/Kolkata');
    final scheduledDate = tz.TZDateTime.fromMillisecondsSinceEpoch(indiaTimezone, reminder.timestamp);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      reminder.id.hashCode.abs(),
      'Time for ${reminder.medicationName}',
      'Take ${reminder.dosage} now',
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _saveReminder() async {
    if (_selectedTime == null || _nameController.text.isEmpty || _dosageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Please fill all fields")));
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("User not logged in")));
      return;
    }

    final indiaTimezone = tz.getLocation('Asia/Kolkata');
    final localDateTime = tz.TZDateTime.from(_selectedTime!, indiaTimezone);
    final timestamp = localDateTime.millisecondsSinceEpoch;

    final dbRef = FirebaseDatabase.instance.ref("reminders/$userId");
    final newRef = dbRef.push();
    final newId = newRef.key!;

    final reminder = Reminder(
      medicationName: _nameController.text,
      timestamp: timestamp,
      dosage: _dosageController.text,
      id: newId,
    );

    await newRef.set(reminder.toJson());
    await _scheduleNotification(reminder);

    _nameController.clear();
    _dosageController.clear();
    setState(() {
      _selectedTime = null;
    });
    _loadReminders();
  }

  String _formatDateTime(int timestamp) {
    final indiaTimezone = tz.getLocation('Asia/Kolkata');
    final dateTime = tz.TZDateTime.fromMillisecondsSinceEpoch(indiaTimezone, timestamp);
    return dateTime.toString().split('.')[0];
  }

  void _printPageContent() {
    print("=== Medication Reminders Page Content ===");
    print("Timezone: $_timezoneName");
    print("\nNew Reminder Form:");
    print("Medication Name: ${_nameController.text}");
    print("Dosage: ${_dosageController.text}");
    print("Selected Time: ${_selectedTime != null ? _formatDateTime(_selectedTime!.millisecondsSinceEpoch) : 'Not selected'}");
    print("\nExisting Reminders (Total: ${_reminders.length}):");
    if (_isLoading) {
      print("Loading...");
    } else if (_reminders.isEmpty) {
      print("No reminders yet");
    } else {
      for (var reminder in _reminders) {
        print("- ID: ${reminder.id}");
        print("  Name: ${reminder.medicationName}");
        print("  Dosage: ${reminder.dosage}");
        print("  Time: ${_formatDateTime(reminder.timestamp)}");
        print("  Notified: ${reminder.notified}");
        print("  Status: ${tz.TZDateTime.fromMillisecondsSinceEpoch(tz.getLocation('Asia/Kolkata'), reminder.timestamp).isBefore(tz.TZDateTime.now(tz.getLocation('Asia/Kolkata'))) ? 'Past' : 'Upcoming'}");
      }
    }
    print("======================================");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Medication Reminders"),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade600, Colors.blue.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReminders,
            tooltip: "Refresh Reminders",
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.purple.shade50, Colors.blue.shade50],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Text(
                          "Add New Reminder",
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Autocomplete<String>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return const Iterable<String>.empty();
                            }
                            return _medicationSuggestions.where((String option) {
                              return option.toLowerCase().startsWith(
                                textEditingValue.text.toLowerCase(),
                              );
                            });
                          },
                          onSelected: (String selection) {
                            _nameController.text = selection;
                          },
                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                            _nameController.value = controller.value;
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: "Medication Name",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(color: Colors.purple.shade300),
                                ),
                                prefixIcon: const Icon(Icons.medication, color: Colors.purple),
                                filled: true,
                                fillColor: Colors.white,
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(color: Colors.purple.shade700, width: 2),
                                ),
                              ),
                            );
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 6,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 300,
                                  constraints: const BoxConstraints(maxHeight: 250),
                                  child: ListView.builder(
                                    padding: const EdgeInsets.all(8),
                                    itemCount: options.length,
                                    shrinkWrap: true,
                                    itemBuilder: (context, index) {
                                      final String option = options.elementAt(index);
                                      return ListTile(
                                        title: Text(option),
                                        onTap: () => onSelected(option),
                                        tileColor: Colors.white,
                                        hoverColor: Colors.purple.shade50,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _dosageController,
                          decoration: InputDecoration(
                            labelText: "Dosage",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(color: Colors.purple.shade300),
                            ),
                            prefixIcon: const Icon(Icons.scale, color: Colors.purple),
                            filled: true,
                            fillColor: Colors.white,
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(color: Colors.purple.shade700, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            _selectedTime == null
                                ? "Select Date & Time"
                                : _formatDateTime(_selectedTime!.millisecondsSinceEpoch),
                            style: const TextStyle(fontSize: 16),
                          ),
                          onPressed: () async {
                            final initialDate = DateTime.now();
                            _selectedTime = await showDatePicker(
                              context: context,
                              initialDate: initialDate,
                              firstDate: initialDate,
                              lastDate: DateTime(2026),
                              builder: (context, child) {
                                return Theme(
                                  data: ThemeData.light().copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: Colors.purple.shade700,
                                      onPrimary: Colors.white,
                                      surface: Colors.purple.shade50,
                                    ),
                                    dialogBackgroundColor: Colors.white,
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (_selectedTime != null) {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                                builder: (context, child) {
                                  return Theme(
                                    data: ThemeData.light().copyWith(
                                      colorScheme: ColorScheme.light(
                                        primary: Colors.purple.shade700,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (time != null) {
                                setState(() {
                                  _selectedTime = DateTime(
                                    _selectedTime!.year,
                                    _selectedTime!.month,
                                    _selectedTime!.day,
                                    time.hour,
                                    time.minute,
                                  );
                                });
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            backgroundColor: Colors.purple.shade100,
                            foregroundColor: Colors.purple.shade800,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save, size: 28),
                          label: const Text(
                            "Save Reminder",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          onPressed: _saveReminder,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
                            backgroundColor: Colors.purple.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 4,
                            minimumSize: const Size(double.infinity, 60),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Your Reminders",
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade700,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "${_reminders.length}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.4,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _reminders.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_off,
                          size: 80,
                          color: Colors.purple.shade200,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "No reminders yet",
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.purple.shade700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Add your first medication reminder above",
                          style: TextStyle(color: Colors.purple.shade400),
                        ),
                      ],
                    ),
                  )
                      : ListView.builder(
                    itemCount: _reminders.length,
                    itemBuilder: (context, index) {
                      final reminder = _reminders[index];
                      final indiaTimezone = tz.getLocation('Asia/Kolkata');
                      final reminderTime = tz.TZDateTime.fromMillisecondsSinceEpoch(
                          indiaTimezone, reminder.timestamp);
                      final bool isPast =
                      reminderTime.isBefore(tz.TZDateTime.now(indiaTimezone));

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        color: isPast ? Colors.grey.shade100 : Colors.white,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isPast
                                ? Colors.grey.shade400
                                : Colors.purple.shade700,
                            child: const Icon(Icons.medication, color: Colors.white),
                          ),
                          title: Text(
                            reminder.medicationName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: isPast ? TextDecoration.lineThrough : null,
                              color: isPast ? Colors.grey.shade600 : Colors.purple.shade800,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Dosage: ${reminder.dosage}",
                                style: TextStyle(color: Colors.purple.shade600),
                              ),
                              Text(
                                "Time: ${_formatDateTime(reminder.timestamp)}",
                                style: TextStyle(
                                  color: isPast ? Colors.grey : Colors.purple.shade600,
                                ),
                              ),
                              if (reminder.notified)
                                Text(
                                  "Notified",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete, color: Colors.red.shade400),
                            onPressed: () async {
                              final shouldDelete = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  title: const Text("Delete Reminder"),
                                  content: const Text(
                                      "Are you sure you want to delete this reminder?"),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text("CANCEL"),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: const Text("DELETE"),
                                    ),
                                  ],
                                ),
                              ) ?? false;

                              if (shouldDelete) {
                                final userId = FirebaseAuth.instance.currentUser?.uid;
                                if (userId != null) {
                                  await FirebaseDatabase.instance
                                      .ref("reminders/$userId/${reminder.id}")
                                      .remove();
                                  await flutterLocalNotificationsPlugin
                                      .cancel(reminder.id.hashCode.abs());
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text("Reminder deleted"),
                                      backgroundColor: Colors.red.shade400,
                                    ),
                                  );
                                  _loadReminders();
                                }
                              }
                            },
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20), // Extra padding at bottom
              ],
            ),
          ),
        ),
      ),
    );
  }
}