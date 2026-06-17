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
    'Search results': 'Resultats de recherche',
    'Open service requests': 'Demandes ouvertes',
    'Matching requests': 'Demandes correspondantes',
    'All professionals': 'Tous les professionnels',
    'Matching professionals': 'Professionnels correspondants',
    'Latest Artisan Updates': 'Dernieres mises a jour',
    'No artisan updates yet.': 'Aucune mise a jour pour le moment.',
    'Featured Professionals': 'Professionnels en vedette',
    'View All': 'Tout voir',
    'No professionals found for this search.':
        'Aucun professionnel trouve pour cette recherche.',
    'Popular Services': 'Services populaires',
    'Open Service Requests': 'Demandes de service ouvertes',
    'Post': 'Publier',
    'pros': 'pros',
    'Verified': 'Verifie',
    'active service': 'service actif',
    'active services': 'services actifs',
    'won bids': 'offres gagnees',
    'Unavailable': 'Indisponible',
    'Available': 'Disponible',
    'From': 'A partir de',
    'comment': 'commentaire',
    'comments': 'commentaires',
    'View profile & comments': 'Voir le profil et les commentaires',
    'Busy': 'Occupe',
    'Book Now': 'Reserver',
    'Listing': 'Annonce',
    'Professional': 'Professionnel',
    'Professional profile': 'Profil professionnel',
    'Unavailable now': 'Indisponible maintenant',
    'Artisan unavailable': 'Artisan indisponible',
    'Bookmark': 'Favori',
    'Bookmarked': 'Ajoute aux favoris',
    'This listing is no longer available.':
        'Cette annonce n est plus disponible.',
    'Could not load this listing. Check your connection and try again.':
        'Impossible de charger cette annonce. Verifiez votre connexion.',
    'Loading listing...': 'Chargement de l annonce...',
    'This artisan is currently unavailable.':
        'Cet artisan est actuellement indisponible.',
    'You cannot chat with yourself.':
        'Vous ne pouvez pas discuter avec vous-meme.',
    'Could not start chat. Please try again.':
        'Impossible de demarrer la discussion. Reessayez.',
    'Could not load professional profile.':
        'Impossible de charger le profil professionnel.',
    'Loading profile...': 'Chargement du profil...',
    'Services': 'Services',
    'No active services': 'Aucun service actif',
    'Comments': 'Commentaires',
    'No comments yet': 'Aucun commentaire pour le moment',
    'Active services': 'Services actifs',
    'Bids won': 'Offres gagnees',
    'Completed reviews': 'Avis termines',
    'Upload service request': 'Publier une demande de service',
    'Service title': 'Titre du service',
    'Describe your need': 'Decrivez votre besoin',
    'Location': 'Localisation',
    'Title is required': 'Le titre est requis',
    'Description is required': 'La description est requise',
    'Location is required': 'La localisation est requise',
    'Enter a valid budget': 'Entrez un budget valide',
    'Budget': 'Budget',
    'Uploading...': 'Publication...',
    'My uploaded requests': 'Mes demandes publiees',
    'No uploads yet.': 'Aucune publication pour le moment.',
    'Sign in to upload requests': 'Connectez-vous pour publier des demandes',
    'Request uploaded successfully.': 'Demande publiee avec succes.',
    'Could not upload request. Check Supabase setup.':
        'Impossible de publier la demande. Verifiez Supabase.',
    'Could not load uploads. Check Supabase credentials and try again.':
        'Impossible de charger les publications. Verifiez Supabase.',
    'Notifications': 'Notifications',
    'Refresh': 'Actualiser',
    'Could not load notifications.': 'Impossible de charger les notifications.',
    'Loading notifications...': 'Chargement des notifications...',
    'All': 'Tout',
    'Unread': 'Non lues',
    'Read': 'Lues',
    'Type': 'Type',
    'Date': 'Date',
    'Clear date filter': 'Effacer le filtre de date',
    'No notifications': 'Aucune notification',
    'Mark read': 'Marquer comme lue',
    'Hello': 'Bonjour',
    'Favourites': 'Favoris',
    'Mark services unavailable': 'Marquer les services indisponibles',
    'Chat and booking buttons show unavailable to users.':
        'Les boutons de discussion et de reservation indiquent indisponible.',
    'Users can chat and book your active services.':
        'Les utilisateurs peuvent discuter et reserver vos services actifs.',
    'Services marked unavailable.': 'Services marques indisponibles.',
    'Services marked available.': 'Services marques disponibles.',
    'Could not update status': 'Impossible de mettre a jour le statut',
    'Verified artisan': 'Artisan verifie',
    'Verified account': 'Compte verifie',
    'Verification': 'Verification',
    'Your profile shows a public verified checkmark.':
        'Votre profil affiche un badge verifie public.',
    'Submit or update your ID for Support review.':
        'Envoyez ou mettez a jour votre piece d identite pour verification.',
    'Account settings': 'Parametres du compte',
    'Username, phone, email, password, and privacy.':
        'Nom d utilisateur, telephone, e-mail, mot de passe et confidentialite.',
    'Open': 'Ouvrir',
    'App settings': 'Parametres de l application',
    'Language, dark mode, and notifications.':
        'Langue, mode sombre et notifications.',
    'History, bid, chat, and account alerts.':
        'Historique, offres, discussions et alertes de compte.',
    'Logout': 'Deconnexion',
    'Delete account': 'Supprimer le compte',
    'Sign in to continue': 'Connectez-vous pour continuer',
    'Manage your profile and settings.':
        'Gerez votre profil et vos parametres.',
    'Dark mode': 'Mode sombre',
    'Email notifications': 'Notifications par e-mail',
    'Phone notifications': 'Notifications telephone',
    'Language': 'Langue',
    'Currency': 'Devise',
    'Close': 'Fermer',
    'Username': 'Nom d utilisateur',
    'Edit': 'Modifier',
    'Add full name': 'Ajouter le nom complet',
    'Full name or business contact name':
        'Nom complet ou contact professionnel',
    'Full name': 'Nom complet',
    'Add phone': 'Ajouter un telephone',
    'Phone number and country code': 'Telephone et indicatif du pays',
    'Country code': 'Indicatif du pays',
    'Add profile description': 'Ajouter une description du profil',
    'Company or artisan profile description':
        'Description de l entreprise ou de l artisan',
    'Customer profile description': 'Description du profil client',
    'Account security': 'Securite du compte',
    'Email codes, password recovery, and Google verification are handled by Supabase.':
        'Les codes e-mail, la recuperation du mot de passe et Google sont geres par Supabase.',
    'Privacy': 'Confidentialite',
    'Support': 'Assistance',
    'Terms of Service': 'Conditions d utilisation',
    'About': 'A propos',
    'About Pro SME': 'A propos de Pro SME',
    'Pro SME helps customers connect with verified SMEs and artisans.':
        'Pro SME aide les clients a trouver des PME et artisans verifies.',
    'Artisan profile': 'Profil artisan',
    'Customer profile': 'Profil client',
    'saved listing': 'annonce enregistree',
    'saved listings': 'annonces enregistrees',
    'No favourites added': 'Aucun favori ajoute',
    'Tap to view your saved listings.':
        'Appuyez pour voir vos annonces enregistrees.',
    'Save all your favourites in one place using the bookmark icon.':
        'Enregistrez vos favoris au meme endroit avec l icone favori.',
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
    'Search results': 'Resultados de busqueda',
    'Open service requests': 'Solicitudes abiertas',
    'Matching requests': 'Solicitudes coincidentes',
    'All professionals': 'Todos los profesionales',
    'Matching professionals': 'Profesionales coincidentes',
    'Latest Artisan Updates': 'Ultimas actualizaciones',
    'No artisan updates yet.': 'Aun no hay actualizaciones.',
    'Featured Professionals': 'Profesionales destacados',
    'View All': 'Ver todo',
    'No professionals found for this search.':
        'No se encontraron profesionales para esta busqueda.',
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
