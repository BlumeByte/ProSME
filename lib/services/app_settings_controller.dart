import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _languageKey = 'settings_language';
const _emailNotificationsKey = 'settings_email_notifications';
const _phoneNotificationsKey = 'settings_phone_notifications';

final appSettingsControllerProvider =
    StateNotifierProvider<AppSettingsController, AppSettings>((ref) {
  return AppSettingsController(AppSettingsController._initialSettings);
});

class AppSettings {
  const AppSettings({
    this.language = 'English',
    this.emailNotifications = true,
    this.phoneNotifications = true,
  });

  final String language;
  final bool emailNotifications;
  final bool phoneNotifications;

  Locale? get locale {
    switch (language) {
      case 'Arabic':
        return const Locale('ar');
      case 'Bengali':
        return const Locale('bn');
      case 'Chinese':
        return const Locale('zh');
      case 'Dutch':
        return const Locale('nl');
      case 'Ewe':
        return const Locale('ee');
      case 'French':
        return const Locale('fr');
      case 'Ga':
        return const Locale('gaa');
      case 'German':
        return const Locale('de');
      case 'Greek':
        return const Locale('el');
      case 'Hausa':
        return const Locale('ha');
      case 'Hindi':
        return const Locale('hi');
      case 'Indonesian':
        return const Locale('id');
      case 'Italian':
        return const Locale('it');
      case 'Japanese':
        return const Locale('ja');
      case 'Korean':
        return const Locale('ko');
      case 'Malay':
        return const Locale('ms');
      case 'Spanish':
        return const Locale('es');
      case 'Portuguese':
        return const Locale('pt');
      case 'Russian':
        return const Locale('ru');
      case 'Swahili':
        return const Locale('sw');
      case 'Tamil':
        return const Locale('ta');
      case 'Thai':
        return const Locale('th');
      case 'Twi':
        return const Locale('ak');
      case 'Turkish':
        return const Locale('tr');
      case 'Ukrainian':
        return const Locale('uk');
      case 'Urdu':
        return const Locale('ur');
      case 'Vietnamese':
        return const Locale('vi');
      case 'Yoruba':
        return const Locale('yo');
      case 'Zulu':
        return const Locale('zu');
      default:
        return const Locale('en');
    }
  }

  AppSettings copyWith({
    String? language,
    bool? emailNotifications,
    bool? phoneNotifications,
  }) {
    return AppSettings(
      language: language ?? this.language,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      phoneNotifications: phoneNotifications ?? this.phoneNotifications,
    );
  }
}

class AppSettingsController extends StateNotifier<AppSettings> {
  AppSettingsController(super.state);

  static AppSettings _initialSettings = const AppSettings();

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _initialSettings = AppSettings(
      language: prefs.getString(_languageKey) ?? 'English',
      emailNotifications: prefs.getBool(_emailNotificationsKey) ?? true,
      phoneNotifications: prefs.getBool(_phoneNotificationsKey) ?? true,
    );
  }

  Future<void> setLanguage(String language) async {
    state = state.copyWith(language: language);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language);
  }

  Future<void> setEmailNotifications(bool enabled) async {
    state = state.copyWith(emailNotifications: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_emailNotificationsKey, enabled);
  }

  Future<void> setPhoneNotifications(bool enabled) async {
    state = state.copyWith(phoneNotifications: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_phoneNotificationsKey, enabled);
  }
}
