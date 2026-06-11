import 'package:country_state_city/country_state_city.dart' as csc;

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
  const RegionOption({required this.name, required this.cities, this.code});

  final String name;
  final List<CityOption> cities;
  final String? code;
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
      RegionOption(
        name: 'Ahafo',
        cities: [
          CityOption(name: 'Goaso', towns: ['Any'])
        ],
      ),
      RegionOption(
        name: 'Bono',
        cities: [
          CityOption(name: 'Sunyani', towns: ['Any'])
        ],
      ),
      RegionOption(
        name: 'Bono East',
        cities: [
          CityOption(name: 'Techiman', towns: ['Any'])
        ],
      ),
      RegionOption(
        name: 'Central',
        cities: [
          CityOption(name: 'Cape Coast', towns: ['Any'])
        ],
      ),
      RegionOption(
        name: 'Eastern',
        cities: [
          CityOption(name: 'Koforidua', towns: ['Any'])
        ],
      ),
      RegionOption(
        name: 'North East',
        cities: [
          CityOption(name: 'Nalerigu', towns: ['Any'])
        ],
      ),
      RegionOption(
        name: 'Northern',
        cities: [
          CityOption(name: 'Tamale', towns: ['Any'])
        ],
      ),
      RegionOption(
        name: 'Oti',
        cities: [
          CityOption(name: 'Dambai', towns: ['Any'])
        ],
      ),
      RegionOption(
        name: 'Savannah',
        cities: [
          CityOption(name: 'Damongo', towns: ['Any'])
        ],
      ),
      RegionOption(
        name: 'Upper East',
        cities: [
          CityOption(name: 'Bolgatanga', towns: ['Any'])
        ],
      ),
      RegionOption(
        name: 'Upper West',
        cities: [
          CityOption(name: 'Wa', towns: ['Any'])
        ],
      ),
      RegionOption(
        name: 'Volta',
        cities: [
          CityOption(name: 'Ho', towns: ['Any'])
        ],
      ),
      RegionOption(
        name: 'Western North',
        cities: [
          CityOption(name: 'Sefwi Wiawso', towns: ['Any'])
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
  CountryOption(
    name: 'Afghanistan',
    code: 'AF',
    dialCode: '+93',
    regions: [
      RegionOption(
        name: 'Southern Asia',
        cities: [
          CityOption(name: 'Kabul', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Åland Islands',
    code: 'AX',
    dialCode: '+35818',
    regions: [
      RegionOption(
        name: 'Northern Europe',
        cities: [
          CityOption(name: 'Mariehamn', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Albania',
    code: 'AL',
    dialCode: '+355',
    regions: [
      RegionOption(
        name: 'Southeast Europe',
        cities: [
          CityOption(name: 'Tirana', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Algeria',
    code: 'DZ',
    dialCode: '+213',
    regions: [
      RegionOption(
        name: 'Northern Africa',
        cities: [
          CityOption(name: 'Algiers', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'American Samoa',
    code: 'AS',
    dialCode: '+1684',
    regions: [
      RegionOption(
        name: 'Polynesia',
        cities: [
          CityOption(name: 'Pago Pago', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Andorra',
    code: 'AD',
    dialCode: '+376',
    regions: [
      RegionOption(
        name: 'Southern Europe',
        cities: [
          CityOption(name: 'Andorra la Vella', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Angola',
    code: 'AO',
    dialCode: '+244',
    regions: [
      RegionOption(
        name: 'Middle Africa',
        cities: [
          CityOption(name: 'Luanda', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Anguilla',
    code: 'AI',
    dialCode: '+1264',
    regions: [
      RegionOption(
        name: 'Caribbean',
        cities: [
          CityOption(name: 'The Valley', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Antarctica',
    code: 'AQ',
    dialCode: '+000',
    regions: [
      RegionOption(
        name: 'Antarctic',
        cities: [
          CityOption(name: 'Any', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Antigua and Barbuda',
    code: 'AG',
    dialCode: '+1268',
    regions: [
      RegionOption(
        name: 'Caribbean',
        cities: [
          CityOption(name: 'Saint John\'s', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Argentina',
    code: 'AR',
    dialCode: '+54',
    regions: [
      RegionOption(
        name: 'South America',
        cities: [
          CityOption(name: 'Buenos Aires', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Armenia',
    code: 'AM',
    dialCode: '+374',
    regions: [
      RegionOption(
        name: 'Western Asia',
        cities: [
          CityOption(name: 'Yerevan', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Aruba',
    code: 'AW',
    dialCode: '+297',
    regions: [
      RegionOption(
        name: 'Caribbean',
        cities: [
          CityOption(name: 'Oranjestad', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Australia',
    code: 'AU',
    dialCode: '+61',
    regions: [
      RegionOption(
        name: 'Australia and New Zealand',
        cities: [
          CityOption(name: 'Canberra', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Austria',
    code: 'AT',
    dialCode: '+43',
    regions: [
      RegionOption(
        name: 'Central Europe',
        cities: [
          CityOption(name: 'Vienna', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Azerbaijan',
    code: 'AZ',
    dialCode: '+994',
    regions: [
      RegionOption(
        name: 'Western Asia',
        cities: [
          CityOption(name: 'Baku', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Bahamas',
    code: 'BS',
    dialCode: '+1242',
    regions: [
      RegionOption(
        name: 'Caribbean',
        cities: [
          CityOption(name: 'Nassau', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Bahrain',
    code: 'BH',
    dialCode: '+973',
    regions: [
      RegionOption(
        name: 'Western Asia',
        cities: [
          CityOption(name: 'Manama', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Bangladesh',
    code: 'BD',
    dialCode: '+880',
    regions: [
      RegionOption(
        name: 'Southern Asia',
        cities: [
          CityOption(name: 'Dhaka', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Barbados',
    code: 'BB',
    dialCode: '+1246',
    regions: [
      RegionOption(
        name: 'Caribbean',
        cities: [
          CityOption(name: 'Bridgetown', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Belarus',
    code: 'BY',
    dialCode: '+375',
    regions: [
      RegionOption(
        name: 'Eastern Europe',
        cities: [
          CityOption(name: 'Minsk', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Belgium',
    code: 'BE',
    dialCode: '+32',
    regions: [
      RegionOption(
        name: 'Western Europe',
        cities: [
          CityOption(name: 'Brussels', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Belize',
    code: 'BZ',
    dialCode: '+501',
    regions: [
      RegionOption(
        name: 'Central America',
        cities: [
          CityOption(name: 'Belmopan', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Benin',
    code: 'BJ',
    dialCode: '+229',
    regions: [
      RegionOption(
        name: 'Western Africa',
        cities: [
          CityOption(name: 'Porto-Novo', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Bermuda',
    code: 'BM',
    dialCode: '+1441',
    regions: [
      RegionOption(
        name: 'North America',
        cities: [
          CityOption(name: 'Hamilton', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Bhutan',
    code: 'BT',
    dialCode: '+975',
    regions: [
      RegionOption(
        name: 'Southern Asia',
        cities: [
          CityOption(name: 'Thimphu', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Bolivia',
    code: 'BO',
    dialCode: '+591',
    regions: [
      RegionOption(
        name: 'South America',
        cities: [
          CityOption(name: 'Sucre', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Bosnia and Herzegovina',
    code: 'BA',
    dialCode: '+387',
    regions: [
      RegionOption(
        name: 'Southeast Europe',
        cities: [
          CityOption(name: 'Sarajevo', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Botswana',
    code: 'BW',
    dialCode: '+267',
    regions: [
      RegionOption(
        name: 'Southern Africa',
        cities: [
          CityOption(name: 'Gaborone', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Bouvet Island',
    code: 'BV',
    dialCode: '+47',
    regions: [
      RegionOption(
        name: 'Antarctic',
        cities: [
          CityOption(name: 'Any', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Brazil',
    code: 'BR',
    dialCode: '+55',
    regions: [
      RegionOption(
        name: 'South America',
        cities: [
          CityOption(name: 'Brasília', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'British Indian Ocean Territory',
    code: 'IO',
    dialCode: '+246',
    regions: [
      RegionOption(
        name: 'Eastern Africa',
        cities: [
          CityOption(name: 'Diego Garcia', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'British Virgin Islands',
    code: 'VG',
    dialCode: '+1284',
    regions: [
      RegionOption(
        name: 'Caribbean',
        cities: [
          CityOption(name: 'Road Town', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Brunei',
    code: 'BN',
    dialCode: '+673',
    regions: [
      RegionOption(
        name: 'South-Eastern Asia',
        cities: [
          CityOption(name: 'Bandar Seri Begawan', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Bulgaria',
    code: 'BG',
    dialCode: '+359',
    regions: [
      RegionOption(
        name: 'Southeast Europe',
        cities: [
          CityOption(name: 'Sofia', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Burkina Faso',
    code: 'BF',
    dialCode: '+226',
    regions: [
      RegionOption(
        name: 'Western Africa',
        cities: [
          CityOption(name: 'Ouagadougou', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Burundi',
    code: 'BI',
    dialCode: '+257',
    regions: [
      RegionOption(
        name: 'Eastern Africa',
        cities: [
          CityOption(name: 'Gitega', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Cambodia',
    code: 'KH',
    dialCode: '+855',
    regions: [
      RegionOption(
        name: 'South-Eastern Asia',
        cities: [
          CityOption(name: 'Phnom Penh', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Cameroon',
    code: 'CM',
    dialCode: '+237',
    regions: [
      RegionOption(
        name: 'Middle Africa',
        cities: [
          CityOption(name: 'Yaoundé', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Canada',
    code: 'CA',
    dialCode: '+1',
    regions: [
      RegionOption(
        name: 'North America',
        cities: [
          CityOption(name: 'Ottawa', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Cape Verde',
    code: 'CV',
    dialCode: '+238',
    regions: [
      RegionOption(
        name: 'Western Africa',
        cities: [
          CityOption(name: 'Praia', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Caribbean Netherlands',
    code: 'BQ',
    dialCode: '+599',
    regions: [
      RegionOption(
        name: 'Caribbean',
        cities: [
          CityOption(name: 'Kralendijk', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Cayman Islands',
    code: 'KY',
    dialCode: '+1345',
    regions: [
      RegionOption(
        name: 'Caribbean',
        cities: [
          CityOption(name: 'George Town', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Central African Republic',
    code: 'CF',
    dialCode: '+236',
    regions: [
      RegionOption(
        name: 'Middle Africa',
        cities: [
          CityOption(name: 'Bangui', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Chad',
    code: 'TD',
    dialCode: '+235',
    regions: [
      RegionOption(
        name: 'Middle Africa',
        cities: [
          CityOption(name: 'N\'Djamena', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Chile',
    code: 'CL',
    dialCode: '+56',
    regions: [
      RegionOption(
        name: 'South America',
        cities: [
          CityOption(name: 'Santiago', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'China',
    code: 'CN',
    dialCode: '+86',
    regions: [
      RegionOption(
        name: 'Eastern Asia',
        cities: [
          CityOption(name: 'Beijing', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Christmas Island',
    code: 'CX',
    dialCode: '+61',
    regions: [
      RegionOption(
        name: 'Australia and New Zealand',
        cities: [
          CityOption(name: 'Flying Fish Cove', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Cocos (Keeling) Islands',
    code: 'CC',
    dialCode: '+61',
    regions: [
      RegionOption(
        name: 'Australia and New Zealand',
        cities: [
          CityOption(name: 'West Island', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Colombia',
    code: 'CO',
    dialCode: '+57',
    regions: [
      RegionOption(
        name: 'South America',
        cities: [
          CityOption(name: 'Bogotá', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Comoros',
    code: 'KM',
    dialCode: '+269',
    regions: [
      RegionOption(
        name: 'Eastern Africa',
        cities: [
          CityOption(name: 'Moroni', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Cook Islands',
    code: 'CK',
    dialCode: '+682',
    regions: [
      RegionOption(
        name: 'Polynesia',
        cities: [
          CityOption(name: 'Avarua', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Costa Rica',
    code: 'CR',
    dialCode: '+506',
    regions: [
      RegionOption(
        name: 'Central America',
        cities: [
          CityOption(name: 'San José', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Croatia',
    code: 'HR',
    dialCode: '+385',
    regions: [
      RegionOption(
        name: 'Southeast Europe',
        cities: [
          CityOption(name: 'Zagreb', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Cuba',
    code: 'CU',
    dialCode: '+53',
    regions: [
      RegionOption(
        name: 'Caribbean',
        cities: [
          CityOption(name: 'Havana', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Curaçao',
    code: 'CW',
    dialCode: '+599',
    regions: [
      RegionOption(
        name: 'Caribbean',
        cities: [
          CityOption(name: 'Willemstad', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Cyprus',
    code: 'CY',
    dialCode: '+357',
    regions: [
      RegionOption(
        name: 'Southern Europe',
        cities: [
          CityOption(name: 'Nicosia', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Czechia',
    code: 'CZ',
    dialCode: '+420',
    regions: [
      RegionOption(
        name: 'Central Europe',
        cities: [
          CityOption(name: 'Prague', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Denmark',
    code: 'DK',
    dialCode: '+45',
    regions: [
      RegionOption(
        name: 'Northern Europe',
        cities: [
          CityOption(name: 'Copenhagen', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Djibouti',
    code: 'DJ',
    dialCode: '+253',
    regions: [
      RegionOption(
        name: 'Eastern Africa',
        cities: [
          CityOption(name: 'Djibouti', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Dominica',
    code: 'DM',
    dialCode: '+1767',
    regions: [
      RegionOption(
        name: 'Caribbean',
        cities: [
          CityOption(name: 'Roseau', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Dominican Republic',
    code: 'DO',
    dialCode: '+1809',
    regions: [
      RegionOption(
        name: 'Caribbean',
        cities: [
          CityOption(name: 'Santo Domingo', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'DR Congo',
    code: 'CD',
    dialCode: '+243',
    regions: [
      RegionOption(
        name: 'Middle Africa',
        cities: [
          CityOption(name: 'Kinshasa', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Ecuador',
    code: 'EC',
    dialCode: '+593',
    regions: [
      RegionOption(
        name: 'South America',
        cities: [
          CityOption(name: 'Quito', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Egypt',
    code: 'EG',
    dialCode: '+20',
    regions: [
      RegionOption(
        name: 'Northern Africa',
        cities: [
          CityOption(name: 'Cairo', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'El Salvador',
    code: 'SV',
    dialCode: '+503',
    regions: [
      RegionOption(
        name: 'Central America',
        cities: [
          CityOption(name: 'San Salvador', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Equatorial Guinea',
    code: 'GQ',
    dialCode: '+240',
    regions: [
      RegionOption(
        name: 'Middle Africa',
        cities: [
          CityOption(name: 'Ciudad de la Paz', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Eritrea',
    code: 'ER',
    dialCode: '+291',
    regions: [
      RegionOption(
        name: 'Eastern Africa',
        cities: [
          CityOption(name: 'Asmara', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Estonia',
    code: 'EE',
    dialCode: '+372',
    regions: [
      RegionOption(
        name: 'Northern Europe',
        cities: [
          CityOption(name: 'Tallinn', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Eswatini',
    code: 'SZ',
    dialCode: '+268',
    regions: [
      RegionOption(
        name: 'Southern Africa',
        cities: [
          CityOption(name: 'Mbabane', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Ethiopia',
    code: 'ET',
    dialCode: '+251',
    regions: [
      RegionOption(
        name: 'Eastern Africa',
        cities: [
          CityOption(name: 'Addis Ababa', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Falkland Islands',
    code: 'FK',
    dialCode: '+500',
    regions: [
      RegionOption(
        name: 'South America',
        cities: [
          CityOption(name: 'Stanley', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Faroe Islands',
    code: 'FO',
    dialCode: '+298',
    regions: [
      RegionOption(
        name: 'Northern Europe',
        cities: [
          CityOption(name: 'Tórshavn', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Fiji',
    code: 'FJ',
    dialCode: '+679',
    regions: [
      RegionOption(
        name: 'Melanesia',
        cities: [
          CityOption(name: 'Suva', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Finland',
    code: 'FI',
    dialCode: '+358',
    regions: [
      RegionOption(
        name: 'Northern Europe',
        cities: [
          CityOption(name: 'Helsinki', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'France',
    code: 'FR',
    dialCode: '+33',
    regions: [
      RegionOption(
        name: 'Western Europe',
        cities: [
          CityOption(name: 'Paris', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'French Guiana',
    code: 'GF',
    dialCode: '+594',
    regions: [
      RegionOption(
        name: 'South America',
        cities: [
          CityOption(name: 'Cayenne', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'French Polynesia',
    code: 'PF',
    dialCode: '+689',
    regions: [
      RegionOption(
        name: 'Polynesia',
        cities: [
          CityOption(name: 'Papeetē', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'French Southern and Antarctic Lands',
    code: 'TF',
    dialCode: '+262',
    regions: [
      RegionOption(
        name: 'Antarctic',
        cities: [
          CityOption(name: 'Port-aux-Français', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Gabon',
    code: 'GA',
    dialCode: '+241',
    regions: [
      RegionOption(
        name: 'Middle Africa',
        cities: [
          CityOption(name: 'Libreville', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Gambia',
    code: 'GM',
    dialCode: '+220',
    regions: [
      RegionOption(
        name: 'Western Africa',
        cities: [
          CityOption(name: 'Banjul', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Georgia',
    code: 'GE',
    dialCode: '+995',
    regions: [
      RegionOption(
        name: 'Western Asia',
        cities: [
          CityOption(name: 'Tbilisi', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Germany',
    code: 'DE',
    dialCode: '+49',
    regions: [
      RegionOption(
        name: 'Western Europe',
        cities: [
          CityOption(name: 'Berlin', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Gibraltar',
    code: 'GI',
    dialCode: '+350',
    regions: [
      RegionOption(
        name: 'Southern Europe',
        cities: [
          CityOption(name: 'Gibraltar', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Greece',
    code: 'GR',
    dialCode: '+30',
    regions: [
      RegionOption(
        name: 'Southern Europe',
        cities: [
          CityOption(name: 'Athens', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Greenland',
    code: 'GL',
    dialCode: '+299',
    regions: [
      RegionOption(
        name: 'North America',
        cities: [
          CityOption(name: 'Nuuk', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Grenada',
    code: 'GD',
    dialCode: '+1473',
    regions: [
      RegionOption(
        name: 'Caribbean',
        cities: [
          CityOption(name: 'St. George\'s', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Guadeloupe',
    code: 'GP',
    dialCode: '+590',
    regions: [
      RegionOption(
        name: 'Caribbean',
        cities: [
          CityOption(name: 'Basse-Terre', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Guam',
    code: 'GU',
    dialCode: '+1671',
    regions: [
      RegionOption(
        name: 'Micronesia',
        cities: [
          CityOption(name: 'Hagåtña', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Guatemala',
    code: 'GT',
    dialCode: '+502',
    regions: [
      RegionOption(
        name: 'Central America',
        cities: [
          CityOption(name: 'Guatemala City', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Guernsey',
    code: 'GG',
    dialCode: '+44',
    regions: [
      RegionOption(
        name: 'Northern Europe',
        cities: [
          CityOption(name: 'St. Peter Port', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Guinea',
    code: 'GN',
    dialCode: '+224',
    regions: [
      RegionOption(
        name: 'Western Africa',
        cities: [
          CityOption(name: 'Conakry', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Guinea-Bissau',
    code: 'GW',
    dialCode: '+245',
    regions: [
      RegionOption(
        name: 'Western Africa',
        cities: [
          CityOption(name: 'Bissau', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Guyana',
    code: 'GY',
    dialCode: '+592',
    regions: [
      RegionOption(
        name: 'South America',
        cities: [
          CityOption(name: 'Georgetown', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Haiti',
    code: 'HT',
    dialCode: '+509',
    regions: [
      RegionOption(
        name: 'Caribbean',
        cities: [
          CityOption(name: 'Port-au-Prince', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Heard Island and McDonald Islands',
    code: 'HM',
    dialCode: '+000',
    regions: [
      RegionOption(
        name: 'Antarctic',
        cities: [
          CityOption(name: 'Any', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Honduras',
    code: 'HN',
    dialCode: '+504',
    regions: [
      RegionOption(
        name: 'Central America',
        cities: [
          CityOption(name: 'Tegucigalpa', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Hong Kong',
    code: 'HK',
    dialCode: '+852',
    regions: [
      RegionOption(
        name: 'Eastern Asia',
        cities: [
          CityOption(name: 'City of Victoria', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Hungary',
    code: 'HU',
    dialCode: '+36',
    regions: [
      RegionOption(
        name: 'Central Europe',
        cities: [
          CityOption(name: 'Budapest', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Iceland',
    code: 'IS',
    dialCode: '+354',
    regions: [
      RegionOption(
        name: 'Northern Europe',
        cities: [
          CityOption(name: 'Reykjavik', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'India',
    code: 'IN',
    dialCode: '+91',
    regions: [
      RegionOption(
        name: 'Southern Asia',
        cities: [
          CityOption(name: 'New Delhi', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Indonesia',
    code: 'ID',
    dialCode: '+62',
    regions: [
      RegionOption(
        name: 'South-Eastern Asia',
        cities: [
          CityOption(name: 'Jakarta', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Iran',
    code: 'IR',
    dialCode: '+98',
    regions: [
      RegionOption(
        name: 'Southern Asia',
        cities: [
          CityOption(name: 'Tehran', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Iraq',
    code: 'IQ',
    dialCode: '+964',
    regions: [
      RegionOption(
        name: 'Western Asia',
        cities: [
          CityOption(name: 'Baghdad', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Ireland',
    code: 'IE',
    dialCode: '+353',
    regions: [
      RegionOption(
        name: 'Northern Europe',
        cities: [
          CityOption(name: 'Dublin', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Isle of Man',
    code: 'IM',
    dialCode: '+44',
    regions: [
      RegionOption(
        name: 'Northern Europe',
        cities: [
          CityOption(name: 'Douglas', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Israel',
    code: 'IL',
    dialCode: '+972',
    regions: [
      RegionOption(
        name: 'Western Asia',
        cities: [
          CityOption(name: 'Jerusalem', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Italy',
    code: 'IT',
    dialCode: '+39',
    regions: [
      RegionOption(
        name: 'Southern Europe',
        cities: [
          CityOption(name: 'Rome', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Ivory Coast',
    code: 'CI',
    dialCode: '+225',
    regions: [
      RegionOption(
        name: 'Western Africa',
        cities: [
          CityOption(name: 'Yamoussoukro', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Jamaica',
    code: 'JM',
    dialCode: '+1876',
    regions: [
      RegionOption(
        name: 'Caribbean',
        cities: [
          CityOption(name: 'Kingston', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Japan',
    code: 'JP',
    dialCode: '+81',
    regions: [
      RegionOption(
        name: 'Eastern Asia',
        cities: [
          CityOption(name: 'Tokyo', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Jersey',
    code: 'JE',
    dialCode: '+44',
    regions: [
      RegionOption(
        name: 'Northern Europe',
        cities: [
          CityOption(name: 'Saint Helier', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Jordan',
    code: 'JO',
    dialCode: '+962',
    regions: [
      RegionOption(
        name: 'Western Asia',
        cities: [
          CityOption(name: 'Amman', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Kazakhstan',
    code: 'KZ',
    dialCode: '+76',
    regions: [
      RegionOption(
        name: 'Central Asia',
        cities: [
          CityOption(name: 'Astana', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Kenya',
    code: 'KE',
    dialCode: '+254',
    regions: [
      RegionOption(
        name: 'Eastern Africa',
        cities: [
          CityOption(name: 'Nairobi', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Kiribati',
    code: 'KI',
    dialCode: '+686',
    regions: [
      RegionOption(
        name: 'Micronesia',
        cities: [
          CityOption(name: 'South Tarawa', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Kosovo',
    code: 'XK',
    dialCode: '+383',
    regions: [
      RegionOption(
        name: 'Southeast Europe',
        cities: [
          CityOption(name: 'Pristina', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Kuwait',
    code: 'KW',
    dialCode: '+965',
    regions: [
      RegionOption(
        name: 'Western Asia',
        cities: [
          CityOption(name: 'Kuwait City', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Kyrgyzstan',
    code: 'KG',
    dialCode: '+996',
    regions: [
      RegionOption(
        name: 'Central Asia',
        cities: [
          CityOption(name: 'Bishkek', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Laos',
    code: 'LA',
    dialCode: '+856',
    regions: [
      RegionOption(
        name: 'South-Eastern Asia',
        cities: [
          CityOption(name: 'Vientiane', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Latvia',
    code: 'LV',
    dialCode: '+371',
    regions: [
      RegionOption(
        name: 'Northern Europe',
        cities: [
          CityOption(name: 'Riga', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Lebanon',
    code: 'LB',
    dialCode: '+961',
    regions: [
      RegionOption(
        name: 'Western Asia',
        cities: [
          CityOption(name: 'Beirut', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Lesotho',
    code: 'LS',
    dialCode: '+266',
    regions: [
      RegionOption(
        name: 'Southern Africa',
        cities: [
          CityOption(name: 'Maseru', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Liberia',
    code: 'LR',
    dialCode: '+231',
    regions: [
      RegionOption(
        name: 'Western Africa',
        cities: [
          CityOption(name: 'Monrovia', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Libya',
    code: 'LY',
    dialCode: '+218',
    regions: [
      RegionOption(
        name: 'Northern Africa',
        cities: [
          CityOption(name: 'Tripoli', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Liechtenstein',
    code: 'LI',
    dialCode: '+423',
    regions: [
      RegionOption(
        name: 'Western Europe',
        cities: [
          CityOption(name: 'Vaduz', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Lithuania',
    code: 'LT',
    dialCode: '+370',
    regions: [
      RegionOption(
        name: 'Northern Europe',
        cities: [
          CityOption(name: 'Vilnius', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Luxembourg',
    code: 'LU',
    dialCode: '+352',
    regions: [
      RegionOption(
        name: 'Western Europe',
        cities: [
          CityOption(name: 'Luxembourg', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Macau',
    code: 'MO',
    dialCode: '+853',
    regions: [
      RegionOption(
        name: 'Eastern Asia',
        cities: [
          CityOption(name: 'Any', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Madagascar',
    code: 'MG',
    dialCode: '+261',
    regions: [
      RegionOption(
        name: 'Eastern Africa',
        cities: [
          CityOption(name: 'Antananarivo', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Malawi',
    code: 'MW',
    dialCode: '+265',
    regions: [
      RegionOption(
        name: 'Eastern Africa',
        cities: [
          CityOption(name: 'Lilongwe', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Malaysia',
    code: 'MY',
    dialCode: '+60',
    regions: [
      RegionOption(
        name: 'South-Eastern Asia',
        cities: [
          CityOption(name: 'Kuala Lumpur', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Maldives',
    code: 'MV',
    dialCode: '+960',
    regions: [
      RegionOption(
        name: 'Southern Asia',
        cities: [
          CityOption(name: 'Malé', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Mali',
    code: 'ML',
    dialCode: '+223',
    regions: [
      RegionOption(
        name: 'Western Africa',
        cities: [
          CityOption(name: 'Bamako', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Malta',
    code: 'MT',
    dialCode: '+356',
    regions: [
      RegionOption(
        name: 'Southern Europe',
        cities: [
          CityOption(name: 'Valletta', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Marshall Islands',
    code: 'MH',
    dialCode: '+692',
    regions: [
      RegionOption(
        name: 'Micronesia',
        cities: [
          CityOption(name: 'Majuro', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Martinique',
    code: 'MQ',
    dialCode: '+596',
    regions: [
      RegionOption(
        name: 'Caribbean',
        cities: [
          CityOption(name: 'Fort-de-France', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Mauritania',
    code: 'MR',
    dialCode: '+222',
    regions: [
      RegionOption(
        name: 'Western Africa',
        cities: [
          CityOption(name: 'Nouakchott', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Mauritius',
    code: 'MU',
    dialCode: '+230',
    regions: [
      RegionOption(
        name: 'Eastern Africa',
        cities: [
          CityOption(name: 'Port Louis', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Mayotte',
    code: 'YT',
    dialCode: '+262',
    regions: [
      RegionOption(
        name: 'Eastern Africa',
        cities: [
          CityOption(name: 'Mamoudzou', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Mexico',
    code: 'MX',
    dialCode: '+52',
    regions: [
      RegionOption(
        name: 'North America',
        cities: [
          CityOption(name: 'Mexico City', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Micronesia',
    code: 'FM',
    dialCode: '+691',
    regions: [
      RegionOption(
        name: 'Micronesia',
        cities: [
          CityOption(name: 'Palikir', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Moldova',
    code: 'MD',
    dialCode: '+373',
    regions: [
      RegionOption(
        name: 'Eastern Europe',
        cities: [
          CityOption(name: 'Chișinău', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Monaco',
    code: 'MC',
    dialCode: '+377',
    regions: [
      RegionOption(
        name: 'Western Europe',
        cities: [
          CityOption(name: 'Monaco', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Mongolia',
    code: 'MN',
    dialCode: '+976',
    regions: [
      RegionOption(
        name: 'Eastern Asia',
        cities: [
          CityOption(name: 'Ulan Bator', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Montenegro',
    code: 'ME',
    dialCode: '+382',
    regions: [
      RegionOption(
        name: 'Southeast Europe',
        cities: [
          CityOption(name: 'Podgorica', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Montserrat',
    code: 'MS',
    dialCode: '+1664',
    regions: [
      RegionOption(
        name: 'Caribbean',
        cities: [
          CityOption(name: 'Plymouth', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Morocco',
    code: 'MA',
    dialCode: '+212',
    regions: [
      RegionOption(
        name: 'Northern Africa',
        cities: [
          CityOption(name: 'Rabat', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Mozambique',
    code: 'MZ',
    dialCode: '+258',
    regions: [
      RegionOption(
        name: 'Eastern Africa',
        cities: [
          CityOption(name: 'Maputo', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Myanmar',
    code: 'MM',
    dialCode: '+95',
    regions: [
      RegionOption(
        name: 'South-Eastern Asia',
        cities: [
          CityOption(name: 'Naypyidaw', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Namibia',
    code: 'NA',
    dialCode: '+264',
    regions: [
      RegionOption(
        name: 'Southern Africa',
        cities: [
          CityOption(name: 'Windhoek', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Nauru',
    code: 'NR',
    dialCode: '+674',
    regions: [
      RegionOption(
        name: 'Micronesia',
        cities: [
          CityOption(name: 'Yaren', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Nepal',
    code: 'NP',
    dialCode: '+977',
    regions: [
      RegionOption(
        name: 'Southern Asia',
        cities: [
          CityOption(name: 'Kathmandu', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Netherlands',
    code: 'NL',
    dialCode: '+31',
    regions: [
      RegionOption(
        name: 'Western Europe',
        cities: [
          CityOption(name: 'Amsterdam', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'New Caledonia',
    code: 'NC',
    dialCode: '+687',
    regions: [
      RegionOption(
        name: 'Melanesia',
        cities: [
          CityOption(name: 'Nouméa', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'New Zealand',
    code: 'NZ',
    dialCode: '+64',
    regions: [
      RegionOption(
        name: 'Australia and New Zealand',
        cities: [
          CityOption(name: 'Wellington', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Nicaragua',
    code: 'NI',
    dialCode: '+505',
    regions: [
      RegionOption(
        name: 'Central America',
        cities: [
          CityOption(name: 'Managua', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Niger',
    code: 'NE',
    dialCode: '+227',
    regions: [
      RegionOption(
        name: 'Western Africa',
        cities: [
          CityOption(name: 'Niamey', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Niue',
    code: 'NU',
    dialCode: '+683',
    regions: [
      RegionOption(
        name: 'Polynesia',
        cities: [
          CityOption(name: 'Alofi', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Norfolk Island',
    code: 'NF',
    dialCode: '+672',
    regions: [
      RegionOption(
        name: 'Australia and New Zealand',
        cities: [
          CityOption(name: 'Kingston', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'North Korea',
    code: 'KP',
    dialCode: '+850',
    regions: [
      RegionOption(
        name: 'Eastern Asia',
        cities: [
          CityOption(name: 'Pyongyang', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'North Macedonia',
    code: 'MK',
    dialCode: '+389',
    regions: [
      RegionOption(
        name: 'Southeast Europe',
        cities: [
          CityOption(name: 'Skopje', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Northern Mariana Islands',
    code: 'MP',
    dialCode: '+1670',
    regions: [
      RegionOption(
        name: 'Micronesia',
        cities: [
          CityOption(name: 'Saipan', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Norway',
    code: 'NO',
    dialCode: '+47',
    regions: [
      RegionOption(
        name: 'Northern Europe',
        cities: [
          CityOption(name: 'Oslo', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Oman',
    code: 'OM',
    dialCode: '+968',
    regions: [
      RegionOption(
        name: 'Western Asia',
        cities: [
          CityOption(name: 'Muscat', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Pakistan',
    code: 'PK',
    dialCode: '+92',
    regions: [
      RegionOption(
        name: 'Southern Asia',
        cities: [
          CityOption(name: 'Islamabad', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Palau',
    code: 'PW',
    dialCode: '+680',
    regions: [
      RegionOption(
        name: 'Micronesia',
        cities: [
          CityOption(name: 'Ngerulmud', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Palestine',
    code: 'PS',
    dialCode: '+970',
    regions: [
      RegionOption(
        name: 'Western Asia',
        cities: [
          CityOption(name: 'Ramallah', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Panama',
    code: 'PA',
    dialCode: '+507',
    regions: [
      RegionOption(
        name: 'Central America',
        cities: [
          CityOption(name: 'Panama City', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Papua New Guinea',
    code: 'PG',
    dialCode: '+675',
    regions: [
      RegionOption(
        name: 'Melanesia',
        cities: [
          CityOption(name: 'Port Moresby', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Paraguay',
    code: 'PY',
    dialCode: '+595',
    regions: [
      RegionOption(
        name: 'South America',
        cities: [
          CityOption(name: 'Asunción', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Peru',
    code: 'PE',
    dialCode: '+51',
    regions: [
      RegionOption(
        name: 'South America',
        cities: [
          CityOption(name: 'Lima', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Philippines',
    code: 'PH',
    dialCode: '+63',
    regions: [
      RegionOption(
        name: 'South-Eastern Asia',
        cities: [
          CityOption(name: 'Manila', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Pitcairn Islands',
    code: 'PN',
    dialCode: '+64',
    regions: [
      RegionOption(
        name: 'Polynesia',
        cities: [
          CityOption(name: 'Adamstown', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Poland',
    code: 'PL',
    dialCode: '+48',
    regions: [
      RegionOption(
        name: 'Central Europe',
        cities: [
          CityOption(name: 'Warsaw', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Portugal',
    code: 'PT',
    dialCode: '+351',
    regions: [
      RegionOption(
        name: 'Southern Europe',
        cities: [
          CityOption(name: 'Lisbon', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Puerto Rico',
    code: 'PR',
    dialCode: '+1787',
    regions: [
      RegionOption(
        name: 'Caribbean',
        cities: [
          CityOption(name: 'San Juan', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Qatar',
    code: 'QA',
    dialCode: '+974',
    regions: [
      RegionOption(
        name: 'Western Asia',
        cities: [
          CityOption(name: 'Doha', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Republic of the Congo',
    code: 'CG',
    dialCode: '+242',
    regions: [
      RegionOption(
        name: 'Middle Africa',
        cities: [
          CityOption(name: 'Brazzaville', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Réunion',
    code: 'RE',
    dialCode: '+262',
    regions: [
      RegionOption(
        name: 'Eastern Africa',
        cities: [
          CityOption(name: 'Saint-Denis', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Romania',
    code: 'RO',
    dialCode: '+40',
    regions: [
      RegionOption(
        name: 'Southeast Europe',
        cities: [
          CityOption(name: 'Bucharest', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Russia',
    code: 'RU',
    dialCode: '+73',
    regions: [
      RegionOption(
        name: 'Eastern Europe',
        cities: [
          CityOption(name: 'Moscow', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Rwanda',
    code: 'RW',
    dialCode: '+250',
    regions: [
      RegionOption(
        name: 'Eastern Africa',
        cities: [
          CityOption(name: 'Kigali', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Saint Barthélemy',
    code: 'BL',
    dialCode: '+590',
    regions: [
      RegionOption(
        name: 'Caribbean',
        cities: [
          CityOption(name: 'Gustavia', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Saint Helena, Ascension and Tristan da Cunha',
    code: 'SH',
    dialCode: '+290',
    regions: [
      RegionOption(
        name: 'Western Africa',
        cities: [
          CityOption(name: 'Jamestown', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Saint Kitts and Nevis',
    code: 'KN',
    dialCode: '+1869',
    regions: [
      RegionOption(
        name: 'Caribbean',
        cities: [
          CityOption(name: 'Basseterre', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Saint Lucia',
    code: 'LC',
    dialCode: '+1758',
    regions: [
      RegionOption(
        name: 'Caribbean',
        cities: [
          CityOption(name: 'Castries', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Saint Martin',
    code: 'MF',
    dialCode: '+590',
    regions: [
      RegionOption(
        name: 'Caribbean',
        cities: [
          CityOption(name: 'Marigot', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Saint Pierre and Miquelon',
    code: 'PM',
    dialCode: '+508',
    regions: [
      RegionOption(
        name: 'North America',
        cities: [
          CityOption(name: 'Saint-Pierre', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Saint Vincent and the Grenadines',
    code: 'VC',
    dialCode: '+1784',
    regions: [
      RegionOption(
        name: 'Caribbean',
        cities: [
          CityOption(name: 'Kingstown', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Samoa',
    code: 'WS',
    dialCode: '+685',
    regions: [
      RegionOption(
        name: 'Polynesia',
        cities: [
          CityOption(name: 'Apia', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'San Marino',
    code: 'SM',
    dialCode: '+378',
    regions: [
      RegionOption(
        name: 'Southern Europe',
        cities: [
          CityOption(name: 'City of San Marino', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'São Tomé and Príncipe',
    code: 'ST',
    dialCode: '+239',
    regions: [
      RegionOption(
        name: 'Middle Africa',
        cities: [
          CityOption(name: 'São Tomé', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Saudi Arabia',
    code: 'SA',
    dialCode: '+966',
    regions: [
      RegionOption(
        name: 'Western Asia',
        cities: [
          CityOption(name: 'Riyadh', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Senegal',
    code: 'SN',
    dialCode: '+221',
    regions: [
      RegionOption(
        name: 'Western Africa',
        cities: [
          CityOption(name: 'Dakar', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Serbia',
    code: 'RS',
    dialCode: '+381',
    regions: [
      RegionOption(
        name: 'Southeast Europe',
        cities: [
          CityOption(name: 'Belgrade', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Seychelles',
    code: 'SC',
    dialCode: '+248',
    regions: [
      RegionOption(
        name: 'Eastern Africa',
        cities: [
          CityOption(name: 'Victoria', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Sierra Leone',
    code: 'SL',
    dialCode: '+232',
    regions: [
      RegionOption(
        name: 'Western Africa',
        cities: [
          CityOption(name: 'Freetown', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Singapore',
    code: 'SG',
    dialCode: '+65',
    regions: [
      RegionOption(
        name: 'South-Eastern Asia',
        cities: [
          CityOption(name: 'Singapore', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Sint Maarten',
    code: 'SX',
    dialCode: '+1721',
    regions: [
      RegionOption(
        name: 'Caribbean',
        cities: [
          CityOption(name: 'Philipsburg', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Slovakia',
    code: 'SK',
    dialCode: '+421',
    regions: [
      RegionOption(
        name: 'Central Europe',
        cities: [
          CityOption(name: 'Bratislava', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Slovenia',
    code: 'SI',
    dialCode: '+386',
    regions: [
      RegionOption(
        name: 'Central Europe',
        cities: [
          CityOption(name: 'Ljubljana', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Solomon Islands',
    code: 'SB',
    dialCode: '+677',
    regions: [
      RegionOption(
        name: 'Melanesia',
        cities: [
          CityOption(name: 'Honiara', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Somalia',
    code: 'SO',
    dialCode: '+252',
    regions: [
      RegionOption(
        name: 'Eastern Africa',
        cities: [
          CityOption(name: 'Mogadishu', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'South Africa',
    code: 'ZA',
    dialCode: '+27',
    regions: [
      RegionOption(
        name: 'Southern Africa',
        cities: [
          CityOption(name: 'Pretoria', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'South Georgia',
    code: 'GS',
    dialCode: '+500',
    regions: [
      RegionOption(
        name: 'Antarctic',
        cities: [
          CityOption(name: 'King Edward Point', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'South Korea',
    code: 'KR',
    dialCode: '+82',
    regions: [
      RegionOption(
        name: 'Eastern Asia',
        cities: [
          CityOption(name: 'Seoul', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'South Sudan',
    code: 'SS',
    dialCode: '+211',
    regions: [
      RegionOption(
        name: 'Middle Africa',
        cities: [
          CityOption(name: 'Juba', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Spain',
    code: 'ES',
    dialCode: '+34',
    regions: [
      RegionOption(
        name: 'Southern Europe',
        cities: [
          CityOption(name: 'Madrid', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Sri Lanka',
    code: 'LK',
    dialCode: '+94',
    regions: [
      RegionOption(
        name: 'Southern Asia',
        cities: [
          CityOption(name: 'Sri Jayawardenepura Kotte', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Sudan',
    code: 'SD',
    dialCode: '+249',
    regions: [
      RegionOption(
        name: 'Northern Africa',
        cities: [
          CityOption(name: 'Khartoum', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Suriname',
    code: 'SR',
    dialCode: '+597',
    regions: [
      RegionOption(
        name: 'South America',
        cities: [
          CityOption(name: 'Paramaribo', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Svalbard and Jan Mayen',
    code: 'SJ',
    dialCode: '+4779',
    regions: [
      RegionOption(
        name: 'Northern Europe',
        cities: [
          CityOption(name: 'Longyearbyen', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Sweden',
    code: 'SE',
    dialCode: '+46',
    regions: [
      RegionOption(
        name: 'Northern Europe',
        cities: [
          CityOption(name: 'Stockholm', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Switzerland',
    code: 'CH',
    dialCode: '+41',
    regions: [
      RegionOption(
        name: 'Western Europe',
        cities: [
          CityOption(name: 'Bern', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Syria',
    code: 'SY',
    dialCode: '+963',
    regions: [
      RegionOption(
        name: 'Western Asia',
        cities: [
          CityOption(name: 'Damascus', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Taiwan',
    code: 'TW',
    dialCode: '+886',
    regions: [
      RegionOption(
        name: 'Eastern Asia',
        cities: [
          CityOption(name: 'Taipei', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Tajikistan',
    code: 'TJ',
    dialCode: '+992',
    regions: [
      RegionOption(
        name: 'Central Asia',
        cities: [
          CityOption(name: 'Dushanbe', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Tanzania',
    code: 'TZ',
    dialCode: '+255',
    regions: [
      RegionOption(
        name: 'Eastern Africa',
        cities: [
          CityOption(name: 'Dodoma', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Thailand',
    code: 'TH',
    dialCode: '+66',
    regions: [
      RegionOption(
        name: 'South-Eastern Asia',
        cities: [
          CityOption(name: 'Bangkok', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Timor-Leste',
    code: 'TL',
    dialCode: '+670',
    regions: [
      RegionOption(
        name: 'South-Eastern Asia',
        cities: [
          CityOption(name: 'Dili', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Togo',
    code: 'TG',
    dialCode: '+228',
    regions: [
      RegionOption(
        name: 'Western Africa',
        cities: [
          CityOption(name: 'Lomé', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Tokelau',
    code: 'TK',
    dialCode: '+690',
    regions: [
      RegionOption(
        name: 'Polynesia',
        cities: [
          CityOption(name: 'Fakaofo', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Tonga',
    code: 'TO',
    dialCode: '+676',
    regions: [
      RegionOption(
        name: 'Polynesia',
        cities: [
          CityOption(name: 'Nuku\'alofa', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Trinidad and Tobago',
    code: 'TT',
    dialCode: '+1868',
    regions: [
      RegionOption(
        name: 'Caribbean',
        cities: [
          CityOption(name: 'Port of Spain', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Tunisia',
    code: 'TN',
    dialCode: '+216',
    regions: [
      RegionOption(
        name: 'Northern Africa',
        cities: [
          CityOption(name: 'Tunis', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Turkey',
    code: 'TR',
    dialCode: '+90',
    regions: [
      RegionOption(
        name: 'Western Asia',
        cities: [
          CityOption(name: 'Ankara', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Turkmenistan',
    code: 'TM',
    dialCode: '+993',
    regions: [
      RegionOption(
        name: 'Central Asia',
        cities: [
          CityOption(name: 'Ashgabat', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Turks and Caicos Islands',
    code: 'TC',
    dialCode: '+1649',
    regions: [
      RegionOption(
        name: 'Caribbean',
        cities: [
          CityOption(name: 'Cockburn Town', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Tuvalu',
    code: 'TV',
    dialCode: '+688',
    regions: [
      RegionOption(
        name: 'Polynesia',
        cities: [
          CityOption(name: 'Funafuti', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Uganda',
    code: 'UG',
    dialCode: '+256',
    regions: [
      RegionOption(
        name: 'Eastern Africa',
        cities: [
          CityOption(name: 'Kampala', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Ukraine',
    code: 'UA',
    dialCode: '+380',
    regions: [
      RegionOption(
        name: 'Eastern Europe',
        cities: [
          CityOption(name: 'Kyiv', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'United Arab Emirates',
    code: 'AE',
    dialCode: '+971',
    regions: [
      RegionOption(
        name: 'Western Asia',
        cities: [
          CityOption(name: 'Abu Dhabi', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'United Kingdom',
    code: 'GB',
    dialCode: '+44',
    regions: [
      RegionOption(
        name: 'Northern Europe',
        cities: [
          CityOption(name: 'London', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'United States Minor Outlying Islands',
    code: 'UM',
    dialCode: '+268',
    regions: [
      RegionOption(
        name: 'North America',
        cities: [
          CityOption(name: 'Washington DC', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'United States Virgin Islands',
    code: 'VI',
    dialCode: '+1340',
    regions: [
      RegionOption(
        name: 'Caribbean',
        cities: [
          CityOption(name: 'Charlotte Amalie', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Uruguay',
    code: 'UY',
    dialCode: '+598',
    regions: [
      RegionOption(
        name: 'South America',
        cities: [
          CityOption(name: 'Montevideo', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Uzbekistan',
    code: 'UZ',
    dialCode: '+998',
    regions: [
      RegionOption(
        name: 'Central Asia',
        cities: [
          CityOption(name: 'Tashkent', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Vanuatu',
    code: 'VU',
    dialCode: '+678',
    regions: [
      RegionOption(
        name: 'Melanesia',
        cities: [
          CityOption(name: 'Port Vila', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Vatican City',
    code: 'VA',
    dialCode: '+3906698',
    regions: [
      RegionOption(
        name: 'Southern Europe',
        cities: [
          CityOption(name: 'Vatican City', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Venezuela',
    code: 'VE',
    dialCode: '+58',
    regions: [
      RegionOption(
        name: 'South America',
        cities: [
          CityOption(name: 'Caracas', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Vietnam',
    code: 'VN',
    dialCode: '+84',
    regions: [
      RegionOption(
        name: 'South-Eastern Asia',
        cities: [
          CityOption(name: 'Hanoi', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Wallis and Futuna',
    code: 'WF',
    dialCode: '+681',
    regions: [
      RegionOption(
        name: 'Polynesia',
        cities: [
          CityOption(name: 'Mata-Utu', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Western Sahara',
    code: 'EH',
    dialCode: '+2125288',
    regions: [
      RegionOption(
        name: 'Northern Africa',
        cities: [
          CityOption(name: 'El Aaiún', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Yemen',
    code: 'YE',
    dialCode: '+967',
    regions: [
      RegionOption(
        name: 'Western Asia',
        cities: [
          CityOption(name: 'Sana\'a', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Zambia',
    code: 'ZM',
    dialCode: '+260',
    regions: [
      RegionOption(
        name: 'Eastern Africa',
        cities: [
          CityOption(name: 'Lusaka', towns: ['Any'])
        ],
      ),
    ],
  ),
  CountryOption(
    name: 'Zimbabwe',
    code: 'ZW',
    dialCode: '+263',
    regions: [
      RegionOption(
        name: 'Southern Africa',
        cities: [
          CityOption(name: 'Harare', towns: ['Any'])
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

Future<List<CountryOption>> loadWorldCountries() async {
  try {
    final countries = await csc.getAllCountries();
    final options = countries
        .map(
          (country) => CountryOption(
            name: country.name,
            code: country.isoCode,
            dialCode: _formatDialCode(country.phoneCode),
            regions: const [],
          ),
        )
        .toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));
    return options.isEmpty ? kCountries : options;
  } catch (_) {
    return kCountries;
  }
}

Future<CountryOption> loadCountryRegions(CountryOption country) async {
  try {
    final states = await csc.getStatesOfCountry(country.code);
    if (states.isEmpty) {
      final cities = await csc.getCountryCities(country.code);
      return CountryOption(
        name: country.name,
        code: country.code,
        dialCode: country.dialCode,
        regions: [
          RegionOption(
            name: 'Any',
            cities: cities
                .map(
                    (city) => CityOption(name: city.name, towns: const ['Any']))
                .toList(growable: false),
          ),
        ],
      );
    }

    final regions = <RegionOption>[];
    for (final state in states) {
      final cities = await csc.getStateCities(country.code, state.isoCode);
      regions.add(
        RegionOption(
          name: state.name,
          code: state.isoCode,
          cities: cities
              .map((city) => CityOption(name: city.name, towns: const ['Any']))
              .toList(growable: false),
        ),
      );
    }
    regions.sort((a, b) => a.name.compareTo(b.name));
    return CountryOption(
      name: country.name,
      code: country.code,
      dialCode: country.dialCode,
      regions: regions,
    );
  } catch (_) {
    return country.regions.isNotEmpty ? country : countryByName(country.name);
  }
}

String _formatDialCode(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '+000';
  return trimmed.startsWith('+') ? trimmed : '+$trimmed';
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
