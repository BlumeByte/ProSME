import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/currency.dart';

const _languageKey = 'settings_language';
const _currencyCodeKey = 'settings_currency_code';
const _currencyRateKeyPrefix = 'settings_currency_rate_';
const _emailNotificationsKey = 'settings_email_notifications';
const _phoneNotificationsKey = 'settings_phone_notifications';

final appSettingsControllerProvider =
    StateNotifierProvider<AppSettingsController, AppSettings>((ref) {
  return AppSettingsController(AppSettingsController._initialSettings);
});

class AppSettings {
  const AppSettings({
    this.language = 'English',
    this.currencyCode = 'GHS',
    this.emailNotifications = true,
    this.phoneNotifications = true,
  });

  final String language;
  final String currencyCode;
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
        return const Locale('en');
      case 'French':
        return const Locale('fr');
      case 'Ga':
        return const Locale('en');
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
        return const Locale('en');
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
    String? currencyCode,
    bool? emailNotifications,
    bool? phoneNotifications,
  }) {
    return AppSettings(
      language: language ?? this.language,
      currencyCode: currencyCode ?? this.currencyCode,
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
      currencyCode: prefs.getString(_currencyCodeKey) ?? 'GHS',
      emailNotifications: prefs.getBool(_emailNotificationsKey) ?? true,
      phoneNotifications: prefs.getBool(_phoneNotificationsKey) ?? true,
    );
    final cachedRate = prefs
        .getDouble('$_currencyRateKeyPrefix${_initialSettings.currencyCode}');
    if (cachedRate != null) {
      setCurrencyRateFromGhs(_initialSettings.currencyCode, cachedRate);
    }
    unawaited(_refreshCurrencyRate(_initialSettings.currencyCode, prefs));
  }

  Future<void> setCurrencyCode(String currencyCode) async {
    state = state.copyWith(currencyCode: currencyCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyCodeKey, currencyCode);
    final cachedRate = prefs.getDouble('$_currencyRateKeyPrefix$currencyCode');
    if (cachedRate != null) setCurrencyRateFromGhs(currencyCode, cachedRate);
    await _refreshCurrencyRate(currencyCode, prefs);
  }

  static Future<void> _refreshCurrencyRate(
    String currencyCode,
    SharedPreferences prefs,
  ) async {
    if (currencyCode == 'GHS') {
      setCurrencyRateFromGhs('GHS', 1);
      await prefs.setDouble('${_currencyRateKeyPrefix}GHS', 1);
      return;
    }
    try {
      final uri = Uri.parse('https://open.er-api.com/v6/latest/GHS');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return;
      final rates = decoded['rates'];
      if (rates is! Map) return;
      final rawRate = rates[currencyCode];
      final rate = rawRate is num ? rawRate.toDouble() : null;
      if (rate == null || rate <= 0) return;
      setCurrencyRateFromGhs(currencyCode, rate);
      await prefs.setDouble('$_currencyRateKeyPrefix$currencyCode', rate);
    } catch (_) {
      // Built-in fallback rates keep the app usable offline.
    }
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
