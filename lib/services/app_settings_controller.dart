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
      case 'French':
        return const Locale('fr');
      case 'Spanish':
        return const Locale('es');
      case 'Portuguese':
        return const Locale('pt');
      default:
        return null;
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
