class CurrencyOption {
  const CurrencyOption({
    required this.code,
    required this.symbol,
    required this.name,
    this.rateFromGhs,
  });

  final String code;
  final String symbol;
  final String name;
  final double? rateFromGhs;
}

const kCurrencyOptions = <CurrencyOption>[
  CurrencyOption(
    code: 'GHS',
    symbol: 'GHS',
    name: 'Ghanaian cedi',
    rateFromGhs: 1,
  ),
  CurrencyOption(code: 'AED', symbol: 'AED', name: 'UAE dirham'),
  CurrencyOption(code: 'AFN', symbol: 'AFN', name: 'Afghan afghani'),
  CurrencyOption(code: 'ALL', symbol: 'ALL', name: 'Albanian lek'),
  CurrencyOption(code: 'AMD', symbol: 'AMD', name: 'Armenian dram'),
  CurrencyOption(
      code: 'ANG', symbol: 'ANG', name: 'Netherlands Antillean guilder'),
  CurrencyOption(code: 'AOA', symbol: 'AOA', name: 'Angolan kwanza'),
  CurrencyOption(code: 'ARS', symbol: 'ARS', name: 'Argentine peso'),
  CurrencyOption(code: 'AUD', symbol: r'A$', name: 'Australian dollar'),
  CurrencyOption(code: 'AWG', symbol: 'AWG', name: 'Aruban florin'),
  CurrencyOption(code: 'AZN', symbol: 'AZN', name: 'Azerbaijani manat'),
  CurrencyOption(
      code: 'BAM',
      symbol: 'BAM',
      name: 'Bosnia and Herzegovina convertible mark'),
  CurrencyOption(code: 'BBD', symbol: 'BBD', name: 'Barbadian dollar'),
  CurrencyOption(code: 'BDT', symbol: 'BDT', name: 'Bangladeshi taka'),
  CurrencyOption(code: 'BGN', symbol: 'BGN', name: 'Bulgarian lev'),
  CurrencyOption(code: 'BHD', symbol: 'BHD', name: 'Bahraini dinar'),
  CurrencyOption(code: 'BIF', symbol: 'BIF', name: 'Burundian franc'),
  CurrencyOption(code: 'BMD', symbol: 'BMD', name: 'Bermudian dollar'),
  CurrencyOption(code: 'BND', symbol: 'BND', name: 'Brunei dollar'),
  CurrencyOption(code: 'BOB', symbol: 'BOB', name: 'Bolivian boliviano'),
  CurrencyOption(code: 'BRL', symbol: r'R$', name: 'Brazilian real'),
  CurrencyOption(code: 'BSD', symbol: 'BSD', name: 'Bahamian dollar'),
  CurrencyOption(code: 'BTN', symbol: 'BTN', name: 'Bhutanese ngultrum'),
  CurrencyOption(code: 'BWP', symbol: 'BWP', name: 'Botswana pula'),
  CurrencyOption(code: 'BYN', symbol: 'BYN', name: 'Belarusian ruble'),
  CurrencyOption(code: 'BZD', symbol: 'BZD', name: 'Belize dollar'),
  CurrencyOption(code: 'CAD', symbol: r'C$', name: 'Canadian dollar'),
  CurrencyOption(code: 'CDF', symbol: 'CDF', name: 'Congolese franc'),
  CurrencyOption(code: 'CHF', symbol: 'CHF', name: 'Swiss franc'),
  CurrencyOption(code: 'CLP', symbol: 'CLP', name: 'Chilean peso'),
  CurrencyOption(code: 'CNY', symbol: 'CNY', name: 'Chinese yuan'),
  CurrencyOption(code: 'COP', symbol: 'COP', name: 'Colombian peso'),
  CurrencyOption(code: 'CRC', symbol: 'CRC', name: 'Costa Rican colon'),
  CurrencyOption(code: 'CUP', symbol: 'CUP', name: 'Cuban peso'),
  CurrencyOption(code: 'CVE', symbol: 'CVE', name: 'Cape Verdean escudo'),
  CurrencyOption(code: 'CZK', symbol: 'CZK', name: 'Czech koruna'),
  CurrencyOption(code: 'DJF', symbol: 'DJF', name: 'Djiboutian franc'),
  CurrencyOption(code: 'DKK', symbol: 'DKK', name: 'Danish krone'),
  CurrencyOption(code: 'DOP', symbol: 'DOP', name: 'Dominican peso'),
  CurrencyOption(code: 'DZD', symbol: 'DZD', name: 'Algerian dinar'),
  CurrencyOption(code: 'EGP', symbol: 'EGP', name: 'Egyptian pound'),
  CurrencyOption(code: 'ERN', symbol: 'ERN', name: 'Eritrean nakfa'),
  CurrencyOption(code: 'ETB', symbol: 'ETB', name: 'Ethiopian birr'),
  CurrencyOption(
      code: 'USD', symbol: r'$', name: 'US dollar', rateFromGhs: 0.08858),
  CurrencyOption(
      code: 'EUR', symbol: 'EUR', name: 'Euro', rateFromGhs: 0.07759),
  CurrencyOption(code: 'FJD', symbol: 'FJD', name: 'Fijian dollar'),
  CurrencyOption(code: 'FKP', symbol: 'FKP', name: 'Falkland Islands pound'),
  CurrencyOption(
    code: 'GBP',
    symbol: 'GBP',
    name: 'British pound',
    rateFromGhs: 0.06689,
  ),
  CurrencyOption(code: 'GEL', symbol: 'GEL', name: 'Georgian lari'),
  CurrencyOption(code: 'GGP', symbol: 'GGP', name: 'Guernsey pound'),
  CurrencyOption(code: 'GIP', symbol: 'GIP', name: 'Gibraltar pound'),
  CurrencyOption(code: 'GMD', symbol: 'GMD', name: 'Gambian dalasi'),
  CurrencyOption(code: 'GNF', symbol: 'GNF', name: 'Guinean franc'),
  CurrencyOption(code: 'GTQ', symbol: 'GTQ', name: 'Guatemalan quetzal'),
  CurrencyOption(code: 'GYD', symbol: 'GYD', name: 'Guyanese dollar'),
  CurrencyOption(code: 'HKD', symbol: r'HK$', name: 'Hong Kong dollar'),
  CurrencyOption(code: 'HNL', symbol: 'HNL', name: 'Honduran lempira'),
  CurrencyOption(code: 'HRK', symbol: 'HRK', name: 'Croatian kuna'),
  CurrencyOption(code: 'HTG', symbol: 'HTG', name: 'Haitian gourde'),
  CurrencyOption(code: 'HUF', symbol: 'HUF', name: 'Hungarian forint'),
  CurrencyOption(code: 'IDR', symbol: 'IDR', name: 'Indonesian rupiah'),
  CurrencyOption(code: 'ILS', symbol: 'ILS', name: 'Israeli new shekel'),
  CurrencyOption(code: 'IMP', symbol: 'IMP', name: 'Isle of Man pound'),
  CurrencyOption(code: 'INR', symbol: 'INR', name: 'Indian rupee'),
  CurrencyOption(code: 'IQD', symbol: 'IQD', name: 'Iraqi dinar'),
  CurrencyOption(code: 'IRR', symbol: 'IRR', name: 'Iranian rial'),
  CurrencyOption(code: 'ISK', symbol: 'ISK', name: 'Icelandic krona'),
  CurrencyOption(code: 'JEP', symbol: 'JEP', name: 'Jersey pound'),
  CurrencyOption(code: 'JMD', symbol: 'JMD', name: 'Jamaican dollar'),
  CurrencyOption(code: 'JOD', symbol: 'JOD', name: 'Jordanian dinar'),
  CurrencyOption(code: 'JPY', symbol: 'JPY', name: 'Japanese yen'),
  CurrencyOption(
    code: 'NGN',
    symbol: 'NGN',
    name: 'Nigerian naira',
    rateFromGhs: 121.94,
  ),
  CurrencyOption(code: 'KGS', symbol: 'KGS', name: 'Kyrgyzstani som'),
  CurrencyOption(code: 'KHR', symbol: 'KHR', name: 'Cambodian riel'),
  CurrencyOption(code: 'KID', symbol: 'KID', name: 'Kiribati dollar'),
  CurrencyOption(code: 'KMF', symbol: 'KMF', name: 'Comorian franc'),
  CurrencyOption(code: 'KRW', symbol: 'KRW', name: 'South Korean won'),
  CurrencyOption(code: 'KWD', symbol: 'KWD', name: 'Kuwaiti dinar'),
  CurrencyOption(code: 'KYD', symbol: 'KYD', name: 'Cayman Islands dollar'),
  CurrencyOption(code: 'KZT', symbol: 'KZT', name: 'Kazakhstani tenge'),
  CurrencyOption(code: 'LAK', symbol: 'LAK', name: 'Lao kip'),
  CurrencyOption(code: 'LBP', symbol: 'LBP', name: 'Lebanese pound'),
  CurrencyOption(code: 'LKR', symbol: 'LKR', name: 'Sri Lankan rupee'),
  CurrencyOption(code: 'LRD', symbol: 'LRD', name: 'Liberian dollar'),
  CurrencyOption(code: 'LSL', symbol: 'LSL', name: 'Lesotho loti'),
  CurrencyOption(code: 'LYD', symbol: 'LYD', name: 'Libyan dinar'),
  CurrencyOption(code: 'MAD', symbol: 'MAD', name: 'Moroccan dirham'),
  CurrencyOption(code: 'MDL', symbol: 'MDL', name: 'Moldovan leu'),
  CurrencyOption(code: 'MGA', symbol: 'MGA', name: 'Malagasy ariary'),
  CurrencyOption(code: 'MKD', symbol: 'MKD', name: 'Macedonian denar'),
  CurrencyOption(code: 'MMK', symbol: 'MMK', name: 'Myanmar kyat'),
  CurrencyOption(code: 'MNT', symbol: 'MNT', name: 'Mongolian togrog'),
  CurrencyOption(code: 'MOP', symbol: 'MOP', name: 'Macanese pataca'),
  CurrencyOption(code: 'MRU', symbol: 'MRU', name: 'Mauritanian ouguiya'),
  CurrencyOption(code: 'MUR', symbol: 'MUR', name: 'Mauritian rupee'),
  CurrencyOption(code: 'MVR', symbol: 'MVR', name: 'Maldivian rufiyaa'),
  CurrencyOption(code: 'MWK', symbol: 'MWK', name: 'Malawian kwacha'),
  CurrencyOption(code: 'MXN', symbol: r'MX$', name: 'Mexican peso'),
  CurrencyOption(code: 'MYR', symbol: 'MYR', name: 'Malaysian ringgit'),
  CurrencyOption(code: 'MZN', symbol: 'MZN', name: 'Mozambican metical'),
  CurrencyOption(code: 'NAD', symbol: 'NAD', name: 'Namibian dollar'),
  CurrencyOption(code: 'NIO', symbol: 'NIO', name: 'Nicaraguan cordoba'),
  CurrencyOption(code: 'NOK', symbol: 'NOK', name: 'Norwegian krone'),
  CurrencyOption(code: 'NPR', symbol: 'NPR', name: 'Nepalese rupee'),
  CurrencyOption(code: 'NZD', symbol: r'NZ$', name: 'New Zealand dollar'),
  CurrencyOption(code: 'OMR', symbol: 'OMR', name: 'Omani rial'),
  CurrencyOption(code: 'PAB', symbol: 'PAB', name: 'Panamanian balboa'),
  CurrencyOption(code: 'PEN', symbol: 'PEN', name: 'Peruvian sol'),
  CurrencyOption(code: 'PGK', symbol: 'PGK', name: 'Papua New Guinean kina'),
  CurrencyOption(code: 'PHP', symbol: 'PHP', name: 'Philippine peso'),
  CurrencyOption(code: 'PKR', symbol: 'PKR', name: 'Pakistani rupee'),
  CurrencyOption(code: 'PLN', symbol: 'PLN', name: 'Polish zloty'),
  CurrencyOption(code: 'PYG', symbol: 'PYG', name: 'Paraguayan guarani'),
  CurrencyOption(code: 'QAR', symbol: 'QAR', name: 'Qatari riyal'),
  CurrencyOption(code: 'RON', symbol: 'RON', name: 'Romanian leu'),
  CurrencyOption(code: 'RSD', symbol: 'RSD', name: 'Serbian dinar'),
  CurrencyOption(code: 'RUB', symbol: 'RUB', name: 'Russian ruble'),
  CurrencyOption(code: 'RWF', symbol: 'RWF', name: 'Rwandan franc'),
  CurrencyOption(code: 'SAR', symbol: 'SAR', name: 'Saudi riyal'),
  CurrencyOption(code: 'SBD', symbol: 'SBD', name: 'Solomon Islands dollar'),
  CurrencyOption(code: 'SCR', symbol: 'SCR', name: 'Seychellois rupee'),
  CurrencyOption(code: 'SDG', symbol: 'SDG', name: 'Sudanese pound'),
  CurrencyOption(code: 'SEK', symbol: 'SEK', name: 'Swedish krona'),
  CurrencyOption(code: 'SGD', symbol: 'SGD', name: 'Singapore dollar'),
  CurrencyOption(code: 'SHP', symbol: 'SHP', name: 'Saint Helena pound'),
  CurrencyOption(code: 'SLE', symbol: 'SLE', name: 'Sierra Leonean leone'),
  CurrencyOption(code: 'SLL', symbol: 'SLL', name: 'Sierra Leonean leone'),
  CurrencyOption(code: 'SOS', symbol: 'SOS', name: 'Somali shilling'),
  CurrencyOption(code: 'SRD', symbol: 'SRD', name: 'Surinamese dollar'),
  CurrencyOption(code: 'SSP', symbol: 'SSP', name: 'South Sudanese pound'),
  CurrencyOption(
      code: 'STN', symbol: 'STN', name: 'Sao Tome and Principe dobra'),
  CurrencyOption(code: 'SYP', symbol: 'SYP', name: 'Syrian pound'),
  CurrencyOption(code: 'SZL', symbol: 'SZL', name: 'Eswatini lilangeni'),
  CurrencyOption(code: 'THB', symbol: 'THB', name: 'Thai baht'),
  CurrencyOption(code: 'TJS', symbol: 'TJS', name: 'Tajikistani somoni'),
  CurrencyOption(code: 'TMT', symbol: 'TMT', name: 'Turkmenistan manat'),
  CurrencyOption(code: 'TND', symbol: 'TND', name: 'Tunisian dinar'),
  CurrencyOption(code: 'TOP', symbol: 'TOP', name: 'Tongan paanga'),
  CurrencyOption(code: 'TRY', symbol: 'TRY', name: 'Turkish lira'),
  CurrencyOption(
      code: 'TTD', symbol: 'TTD', name: 'Trinidad and Tobago dollar'),
  CurrencyOption(code: 'TVD', symbol: 'TVD', name: 'Tuvaluan dollar'),
  CurrencyOption(code: 'TWD', symbol: r'NT$', name: 'New Taiwan dollar'),
  CurrencyOption(code: 'TZS', symbol: 'TZS', name: 'Tanzanian shilling'),
  CurrencyOption(code: 'UAH', symbol: 'UAH', name: 'Ukrainian hryvnia'),
  CurrencyOption(code: 'UGX', symbol: 'UGX', name: 'Ugandan shilling'),
  CurrencyOption(code: 'UYU', symbol: 'UYU', name: 'Uruguayan peso'),
  CurrencyOption(code: 'UZS', symbol: 'UZS', name: 'Uzbekistani som'),
  CurrencyOption(code: 'VES', symbol: 'VES', name: 'Venezuelan bolivar'),
  CurrencyOption(code: 'VND', symbol: 'VND', name: 'Vietnamese dong'),
  CurrencyOption(code: 'VUV', symbol: 'VUV', name: 'Vanuatu vatu'),
  CurrencyOption(code: 'WST', symbol: 'WST', name: 'Samoan tala'),
  CurrencyOption(code: 'XAF', symbol: 'XAF', name: 'Central African CFA franc'),
  CurrencyOption(code: 'XCD', symbol: r'EC$', name: 'East Caribbean dollar'),
  CurrencyOption(
    code: 'ZAR',
    symbol: 'R',
    name: 'South African rand',
    rateFromGhs: 1.4546,
  ),
  CurrencyOption(
    code: 'XOF',
    symbol: 'XOF',
    name: 'West African CFA franc',
    rateFromGhs: 50.897,
  ),
  CurrencyOption(
    code: 'KES',
    symbol: 'KES',
    name: 'Kenyan shilling',
    rateFromGhs: 11.465,
  ),
  CurrencyOption(code: 'XPF', symbol: 'XPF', name: 'CFP franc'),
  CurrencyOption(code: 'YER', symbol: 'YER', name: 'Yemeni rial'),
  CurrencyOption(code: 'ZMW', symbol: 'ZMW', name: 'Zambian kwacha'),
  CurrencyOption(code: 'ZWL', symbol: 'ZWL', name: 'Zimbabwean dollar'),
];

final _runtimeRatesFromGhs = <String, double>{};

void setCurrencyRateFromGhs(String code, double rate) {
  if (rate > 0) _runtimeRatesFromGhs[code] = rate;
}

CurrencyOption currencyByCode(String code) {
  return kCurrencyOptions.firstWhere(
    (currency) => currency.code == code,
    orElse: () => kCurrencyOptions.first,
  );
}

double convertFromGhs(num amountGhs, String currencyCode) {
  final currency = currencyByCode(currencyCode);
  final rate = _runtimeRatesFromGhs[currency.code] ?? currency.rateFromGhs ?? 1;
  return amountGhs * rate;
}

double convertToGhs(num amount, String currencyCode) {
  final currency = currencyByCode(currencyCode);
  final rate = _runtimeRatesFromGhs[currency.code] ?? currency.rateFromGhs ?? 1;
  if (rate <= 0) return amount.toDouble();
  return amount / rate;
}

String formatMoney(num amountGhs, String currencyCode, {int decimals = 2}) {
  final currency = currencyByCode(currencyCode);
  final converted = convertFromGhs(amountGhs, currency.code);
  final value = converted.toStringAsFixed(decimals);
  return currency.code == 'GHS' ? 'GHS $value' : '${currency.symbol} $value';
}
