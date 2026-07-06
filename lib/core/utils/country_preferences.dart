import 'location_data.dart';

class CountryPreferenceDefaults {
  const CountryPreferenceDefaults({
    required this.language,
    required this.currencyCode,
  });

  final String language;
  final String currencyCode;
}

CountryPreferenceDefaults preferencesForCountry(CountryOption country) {
  final code = country.code.toUpperCase();
  return CountryPreferenceDefaults(
    language: _languageByCountryCode[code] ?? 'English',
    currencyCode: _currencyByCountryCode[code] ?? 'USD',
  );
}

const _languageByCountryCode = <String, String>{
  'GH': 'English',
  'NG': 'English',
  'US': 'English',
  'GB': 'English',
  'CA': 'English',
  'AU': 'English',
  'KE': 'Swahili',
  'TZ': 'Swahili',
  'ZA': 'English',
  'FR': 'French',
  'BE': 'French',
  'CI': 'French',
  'SN': 'French',
  'CM': 'French',
  'BJ': 'French',
  'TG': 'French',
  'ML': 'French',
  'BF': 'French',
  'NE': 'French',
  'ES': 'Spanish',
  'MX': 'Spanish',
  'AR': 'Spanish',
  'CO': 'Spanish',
  'BR': 'Portuguese',
  'PT': 'Portuguese',
  'AO': 'Portuguese',
  'MZ': 'Portuguese',
  'CV': 'Portuguese',
  'GW': 'Portuguese',
  'ST': 'Portuguese',
  'EG': 'Arabic',
  'MA': 'Arabic',
  'AE': 'Arabic',
  'SA': 'Arabic',
  'DZ': 'Arabic',
  'TN': 'Arabic',
  'SD': 'Arabic',
  'SO': 'Arabic',
};

const _currencyByCountryCode = <String, String>{
  'GH': 'GHS',
  'NG': 'NGN',
  'US': 'USD',
  'GB': 'GBP',
  'CA': 'CAD',
  'AU': 'AUD',
  'KE': 'KES',
  'ZA': 'ZAR',
  'FR': 'EUR',
  'BE': 'EUR',
  'ES': 'EUR',
  'DE': 'EUR',
  'IT': 'EUR',
  'NL': 'EUR',
  'CI': 'XOF',
  'SN': 'XOF',
  'MA': 'MAD',
  'EG': 'EGP',
  'AE': 'AED',
  'SA': 'SAR',
  'IN': 'INR',
  'CN': 'CNY',
  'JP': 'JPY',
  'BR': 'BRL',
  'MX': 'MXN',
};
