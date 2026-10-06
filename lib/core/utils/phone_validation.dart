import 'location_data.dart';

/// Result of checking a phone number against the selected country.
class PhoneCheck {
  const PhoneCheck._({this.e164, this.error});

  /// Normalised number in E.164 form (`+233256122555`) when valid.
  final String? e164;

  /// User-facing reason the number was rejected.
  final String? error;

  bool get isValid => e164 != null;

  factory PhoneCheck.valid(String e164) => PhoneCheck._(e164: e164);
  factory PhoneCheck.invalid(String error) => PhoneCheck._(error: error);
}

/// National-significant-number rules for the countries we have checked.
/// Anything else falls back to a generic length check (see [_genericLength]).
class _NationalRule {
  const _NationalRule(this.pattern, this.hint);

  final RegExp pattern;
  final String hint;
}

final Map<String, _NationalRule> _rules = {
  // Ghana: 9 digits after +233; mobile and landline numbers start 2, 3 or 5.
  'GH': _NationalRule(RegExp(r'^[235]\d{8}$'), '9 digits, for example 256122555'),
  // Nigeria: 10 digits after +234, starting 7, 8 or 9.
  'NG': _NationalRule(RegExp(r'^[789]\d{9}$'), '10 digits, for example 8012345678'),
  // Kenya: 9 digits after +254, starting 1 or 7.
  'KE': _NationalRule(RegExp(r'^[17]\d{8}$'), '9 digits, for example 712345678'),
  // South Africa: 9 digits after +27, starting 6, 7 or 8.
  'ZA': _NationalRule(RegExp(r'^[678]\d{8}$'), '9 digits, for example 821234567'),
  // United States and Canada: 10 digits, area code cannot start with 0 or 1.
  'US': _NationalRule(RegExp(r'^[2-9]\d{9}$'), '10 digits, for example 2025550123'),
  'CA': _NationalRule(RegExp(r'^[2-9]\d{9}$'), '10 digits, for example 4165550123'),
  // United Kingdom: 10 digits after +44 (mobiles start 7).
  'GB': _NationalRule(RegExp(r'^\d{9,10}$'), '9 or 10 digits after +44'),
  // India: 10 digits starting 6 to 9.
  'IN': _NationalRule(RegExp(r'^[6-9]\d{9}$'), '10 digits, for example 9876543210'),
};

/// Checks [input] against [country] and returns the E.164 form.
///
/// Accepts `+<code>…`, `00<code>…`, `<code>…` without a plus, a national
/// number with a trunk `0`, or a bare national number. Anything that does not
/// match the selected country's dial code and digit rules is rejected with a
/// message that tells the user what is expected.
PhoneCheck checkPhoneForCountry(String input, CountryOption country) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return PhoneCheck.invalid('Enter a phone number.');
  }
  if (RegExp(r'[^0-9+\s()\-.]').hasMatch(trimmed)) {
    return PhoneCheck.invalid('Phone numbers can only contain digits, spaces, dashes and brackets.');
  }
  final compact = trimmed.replaceAll(RegExp(r'[\s()\-.]'), '');
  final dialDigits = country.dialCode.replaceAll(RegExp(r'\D'), '');
  if (dialDigits.isEmpty) {
    return PhoneCheck.invalid('Select a country with a valid dial code.');
  }

  String national;
  if (compact.startsWith('+') || compact.startsWith('00')) {
    final digits = compact.replaceFirst(RegExp(r'^(\+|00)'), '');
    if (!digits.startsWith(dialDigits)) {
      return PhoneCheck.invalid(
        'This number must start with ${country.dialCode} for ${country.name}.',
      );
    }
    national = digits.substring(dialDigits.length);
  } else {
    final digits = compact;
    if (RegExp(r'\+').hasMatch(digits)) {
      return PhoneCheck.invalid('The + sign must come first.');
    }
    if (digits.startsWith(dialDigits) && digits.length > dialDigits.length + 8) {
      national = digits.substring(dialDigits.length);
    } else {
      national = digits.startsWith('0') ? digits.substring(1) : digits;
    }
  }

  if (!RegExp(r'^\d+$').hasMatch(national)) {
    return PhoneCheck.invalid('Phone numbers can only contain digits.');
  }

  final rule = _rules[country.code.toUpperCase()];
  if (rule != null) {
    if (!rule.pattern.hasMatch(national)) {
      return PhoneCheck.invalid(
        'That is not a valid ${country.name} number. Use ${rule.hint}.',
      );
    }
  } else if (national.length < 6 || national.length > 12) {
    return PhoneCheck.invalid(
      'Enter a valid ${country.name} phone number with its country code.',
    );
  }

  final e164 = '+$dialDigits$national';
  if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(e164)) {
    return PhoneCheck.invalid('This phone number is too long or too short.');
  }
  return PhoneCheck.valid(e164);
}
