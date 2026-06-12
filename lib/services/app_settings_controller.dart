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

  String t(String text) {
    if (language == 'English') return text;
    return _translations[language]?[text] ?? text;
  }

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

const _translations = <String, Map<String, String>>{
  'French': {
    'ProSME   Find Professionals': 'ProSME   Trouver des professionnels',
    'ProSME': 'ProSME',
    'Home': 'Accueil',
    'Upload': 'Publier',
    'Chat': 'Discussion',
    'Chats': 'Discussions',
    'Bookings': 'Réservations',
    'Profile': 'Profil',
    'Artisan Dashboard': 'Tableau artisan',
    'Artisan': 'Artisan',
    'Listings': 'Annonces',
    'Jobs': 'Travaux',
    'Settings': 'Paramètres',
    'Search requests': 'Rechercher des demandes',
    'Sign in to view chats': 'Connectez-vous pour voir les discussions',
    'No chats yet. Open a professional listing and tap Chat to start.':
        'Aucune discussion. Ouvrez une annonce et appuyez sur Discussion.',
    'No messages yet': 'Aucun message',
    'Delete chat': 'Supprimer la discussion',
    'Delete this conversation from your chat home?':
        'Supprimer cette conversation de vos discussions ?',
    'Cancel': 'Annuler',
    'Delete': 'Supprimer',
  },
  'Spanish': {
    'ProSME   Find Professionals': 'ProSME   Buscar profesionales',
    'ProSME': 'ProSME',
    'Home': 'Inicio',
    'Upload': 'Publicar',
    'Chat': 'Chat',
    'Chats': 'Chats',
    'Bookings': 'Reservas',
    'Profile': 'Perfil',
    'Artisan Dashboard': 'Panel de artesano',
    'Artisan': 'Artesano',
    'Listings': 'Anuncios',
    'Jobs': 'Trabajos',
    'Settings': 'Ajustes',
    'Search requests': 'Buscar solicitudes',
    'Sign in to view chats': 'Inicia sesión para ver chats',
    'No chats yet. Open a professional listing and tap Chat to start.':
        'Aún no hay chats. Abre un anuncio y toca Chat.',
    'No messages yet': 'Sin mensajes',
    'Delete chat': 'Eliminar chat',
    'Delete this conversation from your chat home?':
        '¿Eliminar esta conversación de tus chats?',
    'Cancel': 'Cancelar',
    'Delete': 'Eliminar',
  },
  'Arabic': {
    'ProSME   Find Professionals': 'ProSME   ابحث عن محترفين',
    'ProSME': 'ProSME',
    'Home': 'الرئيسية',
    'Upload': 'نشر',
    'Chat': 'دردشة',
    'Chats': 'الدردشات',
    'Bookings': 'الحجوزات',
    'Profile': 'الملف الشخصي',
    'Artisan Dashboard': 'لوحة الحرفي',
    'Artisan': 'حرفي',
    'Listings': 'القوائم',
    'Jobs': 'الوظائف',
    'Settings': 'الإعدادات',
    'Search requests': 'بحث الطلبات',
    'Sign in to view chats': 'سجل الدخول لعرض الدردشات',
    'No chats yet. Open a professional listing and tap Chat to start.':
        'لا توجد دردشات بعد. افتح قائمة واضغط دردشة.',
    'No messages yet': 'لا توجد رسائل',
    'Delete chat': 'حذف الدردشة',
    'Delete this conversation from your chat home?':
        'حذف هذه المحادثة من الدردشات؟',
    'Cancel': 'إلغاء',
    'Delete': 'حذف',
  },
  'Twi': {
    'ProSME   Find Professionals': 'ProSME   Hwehwɛ adwumayɛfo',
    'Home': 'Fie',
    'Upload': 'Fa so',
    'Chat': 'Nkɔmmɔ',
    'Chats': 'Nkɔmmɔ',
    'Bookings': 'Nhyehyɛe',
    'Profile': 'Wo ho nsɛm',
    'Artisan Dashboard': 'Adwumfoɔ Dashboard',
    'Listings': 'Nnwuma',
    'Jobs': 'Adwuma',
    'Settings': 'Nhyehyɛe',
  },
};

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
