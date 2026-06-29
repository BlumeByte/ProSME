const kTownNeighborhoodsByCountryStateCity =
    <String, Map<String, Map<String, List<String>>>>{
  'GH': {
    'Greater Accra': {
      'Accra': [
        'Osu',
        'Labone',
        'Cantonments',
        'Airport Residential',
        'Dzorwulu',
        'Roman Ridge',
        'East Legon',
        'Adjiringanor',
        'Madina',
        'Adenta',
        'Legon',
        'Achimota',
        'Abelemkpe',
        'Tesano',
        'Kaneshie',
        'Dansoman',
        'Lapaz',
        'Nima',
        'Mamobi',
        'Circle',
        'Ridge',
        'Asylum Down',
        'North Kaneshie',
        'South La',
        'Teshie',
        'Nungua',
        'Spintex',
        'Sakumono',
      ],
      'Tema': [
        'Community 1',
        'Community 2',
        'Community 4',
        'Community 5',
        'Community 7',
        'Community 8',
        'Community 9',
        'Community 11',
        'Community 18',
        'Community 25',
        'Sakumono',
        'Lashibi',
        'Ashaiman',
        'Michel Camp',
        'Kpone',
      ],
      'Madina': ['Zongo Junction', 'Estate', 'Atomic', 'Ritz Junction'],
      'Adenta': ['Barrier', 'Frafraha', 'Commandos', 'Housing Down'],
      'Ashaiman': ['Lebanon', 'Tulaku', 'Middle East', 'Zenu'],
      'Nungua': ['Buade', 'C5', 'Cold Store', 'Nungua Barrier'],
      'Teshie': ['Bush Road', 'Tsuibleoo', 'Camp 2', 'Manna Mission'],
    },
    'Ashanti': {
      'Kumasi': [
        'Adum',
        'Bantama',
        'Asokwa',
        'Ahodwo',
        'Patasi',
        'Suame',
        'Tafo',
        'Asafo',
        'Santasi',
        'Atonsu',
        'Ayigya',
        'Kwadaso',
        'Danyame',
        'Nhyiaeso',
        'Kronum',
        'Oforikrom',
      ],
      'Obuasi': ['Tutuka', 'Sansu', 'Brahabebome', 'Anyinam'],
      'Ejisu': ['Besease', 'Kwaso', 'Onwe', 'Juaben Road'],
      'Mampong': ['Atonsuagya', 'Daaho', 'Kofiase', 'Bosofour'],
      'Konongo': ['Odumase', 'Low Cost', 'Zongo', 'Estate'],
    },
    'Western': {
      'Takoradi': [
        'Market Circle',
        'Effia',
        'Anaji',
        'Kwesimintsim',
        'Fijai',
        'West Tanokrom',
        'Airport Ridge',
        'New Site',
      ],
      'Sekondi': ['Ketan', 'Essikado', 'Kojokrom', 'Nkotompo'],
      'Tarkwa': ['Tarkwa Nsuaem', 'Brenuakyim', 'Akyempim', 'Tamso'],
    },
    'Central': {
      'Cape Coast': ['Pedu', 'Abura', 'Adisadel', 'Siwdu', 'Apewosika'],
      'Kasoa': ['Old Barrier', 'Opeikuma', 'Nyanyano', 'Amanfrom'],
      'Winneba': ['Low Cost', 'Kokoado', 'Zongo', 'University Area'],
    },
    'Eastern': {
      'Koforidua': ['Srodae', 'Betom', 'Effiduase', 'Jumapo', 'Mile 50'],
      'Nkawkaw': ['Amanfrom', 'Zongo', 'Nsuta', 'Akuamoah Estate'],
      'Akim Oda': ['Old Town', 'Aboabo', 'Community 6', 'Estate'],
    },
    'Northern': {
      'Tamale': ['Aboabo', 'Lamashegu', 'Sakasaka', 'Kalpohin', 'Vittin'],
      'Yendi': ['Zongo', 'Kuga', 'Dagbanado', 'Old Town'],
    },
    'Volta': {
      'Ho': ['Bankoe', 'Ahoe', 'Dome', 'Fiave', 'Heve'],
      'Keta': ['Dzelukope', 'Vui', 'Anloga Junction', 'Abutiakope'],
      'Hohoe': ['Gbi', 'Lolobi Road', 'Zongo', 'Godenu'],
    },
    'Bono': {
      'Sunyani': ['Penkwase', 'Estate', 'New Dormaa', 'Abesim', 'Fiapre'],
      'Berekum': ['Zongo', 'Senase', 'Jamde', 'Kyiribaa'],
    },
    'Upper East': {
      'Bolgatanga': ['Zongo', 'Sooboya', 'Tindonsobligo', 'Bukere'],
      'Navrongo': ['Nogsenia', 'Kologo', 'Pungu', 'Central'],
    },
    'Upper West': {
      'Wa': ['Kpaguri', 'Dobile', 'Kambali', 'Mangu', 'Zongo'],
    },
    'Western North': {
      'Sefwi Wiawso': ['Asawinso', 'Bopa', 'Dwinase', 'Central'],
    },
    'Ahafo': {
      'Goaso': ['Kukuom Road', 'Zongo', 'Low Cost', 'Central'],
    },
    'Bono East': {
      'Techiman': ['Kentikrono', 'Zongo', 'Hansua', 'New Town'],
    },
    'Oti': {
      'Dambai': ['Zongo', 'Central', 'Lakeside', 'Asukawkaw Road'],
    },
    'Savannah': {
      'Damongo': ['Canteen', 'Zongo', 'Larabanga Road', 'Central'],
    },
    'North East': {
      'Nalerigu': ['Central', 'Zongo', 'Hospital Area', 'Gambaga Road'],
    },
  },
  'NG': {
    'Lagos': {
      'Lagos': [
        'Ikeja',
        'Lekki',
        'Victoria Island',
        'Ikoyi',
        'Yaba',
        'Surulere',
        'Ajah',
        'Maryland',
        'Gbagada',
        'Agege',
      ],
      'Ikeja': ['Allen Avenue', 'Opebi', 'Alausa', 'Maryland'],
      'Lekki': ['Phase 1', 'Chevron', 'Agungi', 'Ikate', 'Osapa London'],
    },
    'Federal Capital Territory': {
      'Abuja': ['Garki', 'Wuse', 'Maitama', 'Asokoro', 'Gwarinpa', 'Kubwa'],
    },
  },
};

const kGlobalTownNeighborhoodFallback = [
  'City Centre',
  'Downtown',
  'Old Town',
  'New Town',
  'North Side',
  'South Side',
  'East Side',
  'West Side',
  'Central Business District',
  'Market Area',
  'Main Street',
  'High Street',
  'Station Area',
  'Airport Area',
  'Industrial Area',
  'Commercial Area',
  'Residential Area',
  'University Area',
  'Hospital Area',
  'Waterfront',
  'Suburbs',
  'Outskirts',
];

const kTownNeighborhoodsByCountry = <String, List<String>>{
  'AE': [
    'City Centre',
    'Old Town',
    'Marina',
    'Business Bay',
    'Industrial Area',
    'Free Zone',
    'Waterfront',
    'Residential District',
  ],
  'AU': [
    'CBD',
    'Inner North',
    'Inner South',
    'Eastern Suburbs',
    'Western Suburbs',
    'Northern Beaches',
    'Industrial Estate',
    'University Area',
  ],
  'BR': [
    'Centro',
    'Zona Norte',
    'Zona Sul',
    'Zona Leste',
    'Zona Oeste',
    'Vila',
    'Jardim',
    'Distrito Industrial',
  ],
  'CA': [
    'Downtown',
    'Old Town',
    'North End',
    'South End',
    'East End',
    'West End',
    'Harbourfront',
    'Industrial Park',
  ],
  'CN': [
    'City Centre',
    'Old District',
    'New District',
    'Development Zone',
    'Industrial Park',
    'University Town',
    'Railway Station Area',
    'Airport Area',
  ],
  'DE': [
    'Altstadt',
    'Innenstadt',
    'Bahnhofsviertel',
    'Nord',
    'Sud',
    'Ost',
    'West',
    'Industriegebiet',
  ],
  'ES': [
    'Centro',
    'Casco Antiguo',
    'Norte',
    'Sur',
    'Este',
    'Oeste',
    'Poligono Industrial',
    'Zona Universitaria',
  ],
  'FR': [
    'Centre-ville',
    'Vieille Ville',
    'Quartier Nord',
    'Quartier Sud',
    'Quartier Est',
    'Quartier Ouest',
    'Zone Industrielle',
    'Quartier Gare',
  ],
  'GB': [
    'City Centre',
    'Old Town',
    'High Street',
    'North End',
    'South End',
    'East End',
    'West End',
    'Industrial Estate',
  ],
  'IN': [
    'Central',
    'Old City',
    'New Town',
    'Market Area',
    'Railway Station Area',
    'Industrial Area',
    'Civil Lines',
    'University Area',
  ],
  'IT': [
    'Centro Storico',
    'Centro',
    'Stazione',
    'Zona Industriale',
    'Quartiere Nord',
    'Quartiere Sud',
    'Quartiere Est',
    'Quartiere Ovest',
  ],
  'JP': [
    'Central Ward',
    'Station Area',
    'Old Town',
    'New Town',
    'Shopping District',
    'Industrial Area',
    'University Area',
    'Waterfront',
  ],
  'KE': [
    'Central',
    'Town Centre',
    'Market Area',
    'Industrial Area',
    'Estate',
    'Upper Area',
    'Lower Area',
    'Airport Area',
  ],
  'MX': [
    'Centro',
    'Zona Norte',
    'Zona Sur',
    'Zona Este',
    'Zona Oeste',
    'Colonia Centro',
    'Parque Industrial',
    'Zona Universitaria',
  ],
  'ZA': [
    'Central',
    'CBD',
    'Old Town',
    'Township',
    'Industrial Area',
    'Suburbs',
    'North',
    'South',
  ],
  'US': [
    'Downtown',
    'Uptown',
    'Midtown',
    'Old Town',
    'North Side',
    'South Side',
    'East Side',
    'West Side',
    'Industrial District',
    'University District',
  ],
};

List<String> townsForLocation({
  required String countryCode,
  required String stateName,
  required String cityName,
}) {
  final country = kTownNeighborhoodsByCountryStateCity[countryCode];
  final state = country == null
      ? null
      : country[stateName] ?? _findMatchingMap(country, stateName);
  final towns = state == null
      ? null
      : state[cityName] ?? _findMatchingList(state, cityName);
  if (towns == null || towns.isEmpty) {
    return _fallbackTownsForCountry(countryCode);
  }
  return List<String>.unmodifiable(['Any', ...towns]);
}

List<String> _fallbackTownsForCountry(String countryCode) {
  final fallback = kTownNeighborhoodsByCountry[countryCode] ??
      kGlobalTownNeighborhoodFallback;
  return List<String>.unmodifiable(['Any', ...fallback]);
}

bool _sameName(String left, String right) =>
    left.trim().toLowerCase() == right.trim().toLowerCase();

Map<String, List<String>>? _findMatchingMap(
  Map<String, Map<String, List<String>>> values,
  String name,
) {
  for (final entry in values.entries) {
    if (_sameName(entry.key, name)) return entry.value;
  }
  return null;
}

List<String>? _findMatchingList(Map<String, List<String>> values, String name) {
  for (final entry in values.entries) {
    if (_sameName(entry.key, name)) return entry.value;
  }
  return null;
}
