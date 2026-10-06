import 'package:excel/excel.dart';

import '../../../core/utils/location_data.dart';
import '../../../core/utils/phone_validation.dart';

/// One spreadsheet row, checked on the device before anything is sent.
class ImportAccountRow {
  const ImportAccountRow({
    required this.line,
    required this.email,
    required this.fullName,
    required this.role,
    required this.country,
    required this.phone,
    required this.gender,
    required this.dateOfBirth,
    required this.location,
    required this.errors,
  });

  /// Spreadsheet row number (1-based, header is row 1).
  final int line;
  final String email;
  final String fullName;
  /// `customer` or `artisan`.
  final String role;
  final String country;
  /// E.164 phone number, or '' when none was given.
  final String phone;
  final String gender;
  /// `YYYY-MM-DD`.
  final String dateOfBirth;
  final String location;
  final List<String> errors;

  bool get isValid => errors.isEmpty;

  Map<String, dynamic> toPayload() => {
        'email': email,
        'full_name': fullName,
        'role': role,
        'country': country,
        'phone': phone,
        'gender': gender,
        'date_of_birth': dateOfBirth,
        'location': location,
      };
}

class ImportAccountSheet {
  const ImportAccountSheet({required this.rows});

  final List<ImportAccountRow> rows;

  List<ImportAccountRow> get valid =>
      rows.where((row) => row.isValid).toList(growable: false);
  List<ImportAccountRow> get invalid =>
      rows.where((row) => !row.isValid).toList(growable: false);
}

const _requiredColumns = ['email', 'full_name', 'role', 'country', 'date_of_birth'];
const _maxRows = 1000;

const _headerAliases = <String, String>{
  'name': 'full_name',
  'fullname': 'full_name',
  'user_type': 'role',
  'type': 'role',
  'dob': 'date_of_birth',
  'birth_date': 'date_of_birth',
  'birthdate': 'date_of_birth',
  'phone_number': 'phone',
  'mobile': 'phone',
  'region': 'location',
  'address': 'location',
};

const _allowedGenders = {'female', 'male', 'non_binary', 'prefer_not_to_say'};

/// Reads the first sheet of an `.xlsx` file. Throws [FormatException] with a
/// message the admin can act on when the file is not a usable account list.
ImportAccountSheet parseAccountSheet(List<int> bytes) {
  final Excel excel;
  try {
    excel = Excel.decodeBytes(bytes);
  } catch (_) {
    throw const FormatException(
      'This file could not be read. Save it as an .xlsx workbook and try again.',
    );
  }
  if (excel.tables.isEmpty) {
    throw const FormatException('The workbook has no sheets.');
  }
  final sheet = excel.tables.values.first;
  final rows = sheet.rows;
  if (rows.length < 2) {
    throw const FormatException(
      'The sheet needs a header row and at least one account row.',
    );
  }

  final headers = <String, int>{};
  for (var i = 0; i < rows.first.length; i++) {
    final raw = _cellText(rows.first[i]);
    if (raw.isEmpty) continue;
    final normalized = _normalizeHeader(raw);
    headers.putIfAbsent(_headerAliases[normalized] ?? normalized, () => i);
  }
  final missing = _requiredColumns.where((c) => !headers.containsKey(c)).toList();
  if (missing.isNotEmpty) {
    throw FormatException('Missing column(s): ${missing.join(', ')}.');
  }
  if (rows.length - 1 > _maxRows) {
    throw const FormatException('Import at most $_maxRows accounts at a time.');
  }

  String cell(List<Data?> row, String column) {
    final index = headers[column];
    if (index == null || index >= row.length) return '';
    return _cellText(row[index]);
  }

  final seenEmails = <String>{};
  final parsed = <ImportAccountRow>[];
  for (var r = 1; r < rows.length; r++) {
    final row = rows[r];
    final values = {
      for (final column in headers.keys) column: cell(row, column),
    };
    if (values.values.every((v) => v.isEmpty)) continue;

    final errors = <String>[];
    final email = (values['email'] ?? '').toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(email)) {
      errors.add('Email is missing or not valid.');
    } else if (!seenEmails.add(email)) {
      errors.add('Email appears more than once in this sheet.');
    }

    final fullName = values['full_name'] ?? '';
    if (fullName.length < 2) errors.add('Full name is required.');

    final roleText = (values['role'] ?? '').toLowerCase();
    final role = switch (roleText) {
      'artisan' || 'artisans' => 'artisan',
      'customer' || 'customers' || 'user' || 'users' => 'customer',
      _ => '',
    };
    if (role.isEmpty) {
      errors.add('Role must be "artisan" or "user".');
    }

    final country = _matchCountry(values['country'] ?? '');
    if (country == null) {
      errors.add('Country is not in the list. Use the country name, for example Ghana.');
    }

    final dob = _parseDate(values['date_of_birth'] ?? '');
    String dateOfBirth = '';
    if (dob == null) {
      errors.add('Date of birth must be YYYY-MM-DD or DD/MM/YYYY.');
    } else if (!_isAdult(dob)) {
      errors.add('The account holder must be at least 18 years old.');
    } else {
      dateOfBirth = _iso(dob);
    }

    var phone = '';
    final phoneText = values['phone'] ?? '';
    if (phoneText.isNotEmpty && country != null) {
      final check = checkPhoneForCountry(phoneText, country);
      if (check.isValid) {
        phone = check.e164!;
      } else {
        errors.add('Phone: ${check.error}');
      }
    } else if (phoneText.isNotEmpty) {
      errors.add('Phone needs a valid country first.');
    }

    final genderText = (values['gender'] ?? '').toLowerCase().replaceAll(' ', '_');
    final gender = genderText.isEmpty ? 'prefer_not_to_say' : genderText;
    if (!_allowedGenders.contains(gender)) {
      errors.add('Gender must be female, male, non_binary or prefer_not_to_say.');
    }

    parsed.add(
      ImportAccountRow(
        line: r + 1,
        email: email,
        fullName: fullName,
        role: role,
        country: country?.name ?? (values['country'] ?? ''),
        phone: phone,
        gender: gender,
        dateOfBirth: dateOfBirth,
        location: values['location'] ?? '',
        errors: errors,
      ),
    );
  }

  if (parsed.isEmpty) {
    throw const FormatException('No account rows were found under the header.');
  }
  return ImportAccountSheet(rows: parsed);
}

String _cellText(Data? cell) {
  final value = cell?.value;
  if (value == null) return '';
  if (value is DateCellValue) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
  return value.toString().trim();
}

String _normalizeHeader(String raw) => raw
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

CountryOption? _matchCountry(String value) {
  final needle = value.trim().toLowerCase();
  if (needle.isEmpty) return null;
  for (final country in kCountries) {
    if (country.name.toLowerCase() == needle ||
        country.code.toLowerCase() == needle) {
      return country;
    }
  }
  return null;
}

DateTime? _parseDate(String value) {
  final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(value);
  final dmy = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(value);
  int year;
  int month;
  int day;
  if (iso != null) {
    year = int.parse(iso.group(1)!);
    month = int.parse(iso.group(2)!);
    day = int.parse(iso.group(3)!);
  } else if (dmy != null) {
    day = int.parse(dmy.group(1)!);
    month = int.parse(dmy.group(2)!);
    year = int.parse(dmy.group(3)!);
  } else {
    return null;
  }
  final date = DateTime.utc(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

bool _isAdult(DateTime dob) {
  final now = DateTime.now().toUtc();
  final cutoff = DateTime.utc(now.year - 18, now.month, now.day);
  return !dob.isAfter(cutoff);
}

String _iso(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
