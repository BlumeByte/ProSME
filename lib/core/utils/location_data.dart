class CountryOption {
  const CountryOption({
    required this.name,
    required this.code,
    required this.dialCode,
    required this.regions,
  });

  final String name;
  final String code;
  final String dialCode;
  final List<RegionOption> regions;
}

class RegionOption {
  const RegionOption({required this.name, required this.cities});

  final String name;
  final List<CityOption> cities;
}

class CityOption {
  const CityOption({required this.name, required this.towns});

  final String name;
  final List<String> towns;
}

const kCountries = <CountryOption>[
  CountryOption(
    name: 'Ghana',
    code: 'GH',
    dialCode: '+233',
    regions: [
      RegionOption(
        name: 'Greater Accra',
        cities: [
          CityOption(
              name: 'Accra', towns: ['Osu', 'Madina', 'Adenta', 'East Legon']),
          CityOption(
              name: 'Tema', towns: ['Community 1', 'Sakumono', 'Ashaiman']),
        ],
      ),
      RegionOption(
        name: 'Ashanti',
        cities: [
          CityOption(name: 'Kumasi', towns: ['Bantama', 'Asokwa', 'Suame']),
          CityOption(name: 'Obuasi', towns: ['Tutuka', 'Sansu']),
        ],
      ),
      RegionOption(
        name: 'Western',
        cities: [
          CityOption(
              name: 'Takoradi', towns: ['Market Circle', 'Effia', 'Anaji']),
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Nigeria',
    code: 'NG',
    dialCode: '+234',
    regions: [
      RegionOption(
        name: 'Lagos',
        cities: [
          CityOption(
              name: 'Lagos', towns: ['Ikeja', 'Lekki', 'Yaba', 'Surulere']),
        ],
      ),
      RegionOption(
        name: 'Federal Capital Territory',
        cities: [
          CityOption(name: 'Abuja', towns: ['Garki', 'Wuse', 'Maitama']),
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'United States',
    code: 'US',
    dialCode: '+1',
    regions: [
      RegionOption(
        name: 'California',
        cities: [
          CityOption(name: 'Los Angeles', towns: ['Hollywood', 'Venice']),
          CityOption(name: 'San Francisco', towns: ['Mission', 'SOMA']),
        ],
      ),
      RegionOption(
        name: 'New York',
        cities: [
          CityOption(
              name: 'New York City',
              towns: ['Brooklyn', 'Queens', 'Manhattan']),
        ],
      ),
    ],
  ),
];

CountryOption countryByName(String? name) {
  return kCountries.firstWhere(
    (country) => country.name == name,
    orElse: () => kCountries.first,
  );
}

bool isValidPhoneForCountry(String phone, CountryOption country) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  final codeDigits = country.dialCode.replaceAll(RegExp(r'\D'), '');
  final localDigits = digits.startsWith(codeDigits)
      ? digits.substring(codeDigits.length)
      : digits.startsWith('0')
          ? digits.substring(1)
          : digits;
  if (country.code == 'GH') return localDigits.length == 9;
  if (country.code == 'NG') return localDigits.length == 10;
  if (country.code == 'US') return localDigits.length == 10;
  return localDigits.length >= 7 && localDigits.length <= 12;
}

String formatPhoneForCountry(String phone, CountryOption country) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  final codeDigits = country.dialCode.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith(codeDigits)) return '+$digits';
  final localDigits = digits.startsWith('0') ? digits.substring(1) : digits;
  return '${country.dialCode}$localDigits';
}
