import 'package:shared_preferences/shared_preferences.dart';

class AppLaunchService {
  static const _welcomeSeenKey = 'welcome_seen';
  static bool _hasSeenWelcome = false;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _hasSeenWelcome = prefs.getBool(_welcomeSeenKey) ?? false;
    _initialized = true;
  }

  static bool get hasSeenWelcome => _hasSeenWelcome;

  static Future<void> markWelcomeSeen() async {
    _hasSeenWelcome = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_welcomeSeenKey, true);
  }
}
