import 'package:shared_preferences/shared_preferences.dart';

class AppLaunchService {
  static const _welcomeSeenKey = 'welcome_seen';
  static const _firstInstallAtKey = 'first_install_at';
  static bool _hasSeenWelcome = false;
  static bool _initialized = false;
  static DateTime? _firstInstallAt;

  static Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _hasSeenWelcome = prefs.getBool(_welcomeSeenKey) ?? false;
    final rawInstallAt = prefs.getString(_firstInstallAtKey);
    _firstInstallAt = rawInstallAt == null
        ? null
        : DateTime.tryParse(rawInstallAt)?.toLocal();
    if (_firstInstallAt == null) {
      _firstInstallAt = DateTime.now();
      await prefs.setString(
        _firstInstallAtKey,
        _firstInstallAt!.toUtc().toIso8601String(),
      );
    }
    _initialized = true;
  }

  static bool get hasSeenWelcome => _hasSeenWelcome;

  static bool get canShowAds {
    final installAt = _firstInstallAt;
    if (installAt == null) return false;
    return DateTime.now().difference(installAt) >= const Duration(days: 3);
  }

  static Future<void> markWelcomeSeen() async {
    _hasSeenWelcome = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_welcomeSeenKey, true);
  }
}
