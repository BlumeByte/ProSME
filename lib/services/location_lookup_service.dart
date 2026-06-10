import 'dart:convert';

import 'package:http/http.dart' as http;

class LocationLookupResult {
  const LocationLookupResult({
    required this.displayName,
    required this.country,
    required this.region,
    required this.city,
    required this.town,
  });

  final String displayName;
  final String country;
  final String region;
  final String city;
  final String town;

  String get searchText => [
        displayName,
        country,
        region,
        city,
        town,
      ].where((item) => item.trim().isNotEmpty).join(' ');
}

class LocationLookupService {
  LocationLookupService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, LocationLookupResult?> _cache = {};

  Future<LocationLookupResult?> searchOne(
    String query, {
    String? countryCode,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return null;
    final cacheKey = '${countryCode ?? ''}|${trimmed.toLowerCase()}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '1',
      'q': trimmed,
      if (countryCode != null && countryCode.trim().isNotEmpty)
        'countrycodes': countryCode.toLowerCase(),
    });

    try {
      final response = await _client.get(
        uri,
        headers: const {
          'User-Agent': 'ProSME/1.0 (support@prosme.app)',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _cache[cacheKey] = null;
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty || decoded.first is! Map) {
        _cache[cacheKey] = null;
        return null;
      }
      final item = Map<String, dynamic>.from(decoded.first as Map);
      final address = item['address'] is Map
          ? Map<String, dynamic>.from(item['address'] as Map)
          : const <String, dynamic>{};
      final result = LocationLookupResult(
        displayName: (item['display_name'] ?? '').toString(),
        country: (address['country'] ?? '').toString(),
        region:
            (address['state'] ?? address['region'] ?? address['county'] ?? '')
                .toString(),
        city: (address['city'] ??
                address['town'] ??
                address['village'] ??
                address['municipality'] ??
                '')
            .toString(),
        town: (address['suburb'] ??
                address['neighbourhood'] ??
                address['quarter'] ??
                address['hamlet'] ??
                '')
            .toString(),
      );
      _cache[cacheKey] = result;
      return result;
    } catch (_) {
      _cache[cacheKey] = null;
      return null;
    }
  }
}
