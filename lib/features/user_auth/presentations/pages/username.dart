import 'package:shared_preferences/shared_preferences.dart';

class UserDataManager {
  static String userName = '';

  static Future<void> loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    userName = prefs.getString('userName') ?? '';
  }

  static Future<void> saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', name);
    userName = name;
  }

  static Future<void> clearUserName() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userName');
    userName = '';
  }
}