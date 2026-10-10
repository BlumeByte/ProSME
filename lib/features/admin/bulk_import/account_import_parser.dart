import 'dart:convert';

import 'package:archive/archive.dart';
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

/// `.xlsx` is a zip archive (starts with `PK`). The most common reason the
/// `excel` package rejects a file that is genuinely named `.xlsx` is that it
/// is actually something else underneath — an old binary `.xls`, a CSV, or an
/// HTML/MHTML table that a spreadsheet tool saved with the wrong extension.
/// Catching that here gives a precise, actionable message instead of a bare
/// parser exception.
void _checkContainerFormat(List<int> bytes) {
  if (bytes.length < 8) {
    throw const FormatException('This file is empty or too small to be a workbook.');
  }
  final header = bytes.sublist(0, 8);
  final isZip = header[0] == 0x50 && header[1] == 0x4B; // "PK"
  if (isZip) return;
  final isOle2 = header[0] == 0xD0 &&
      header[1] == 0xCF &&
      header[2] == 0x11 &&
      header[3] == 0xE0;
  if (isOle2) {
    throw const FormatException(
      'This is an old .xls workbook, not .xlsx. Open it in Excel or Google '
      'Sheets, then use File > Save As / Download as Microsoft Excel (.xlsx).',
    );
  }
  final looksLikeText = header.every(
    (byte) => byte == 0x09 || byte == 0x0A || byte == 0x0D || (byte >= 0x20 && byte < 0x7F),
  );
  if (looksLikeText) {
    throw const FormatException(
      'This looks like a CSV or text file saved with an .xlsx name. Open it '
      'in Excel or Google Sheets and save/export it as a real .xlsx workbook.',
    );
  }
  throw const FormatException(
    'This does not look like an .xlsx workbook. Save it as .xlsx from Excel '
    'or Google Sheets and try again.',
  );
}

/// Some spreadsheet exporters write package-relationship targets as absolute
/// paths from the package root (`Target="/xl/worksheets/sheet1.xml"`), which
/// the OOXML spec allows but the `excel` package does not expect: it always
/// joins a target relative to `xl/`, so an absolute target resolves to a path
/// that is not in the zip and `Excel.decodeBytes` crashes with a null-check
/// error instead of a readable one. Rewrite any such targets to the relative
/// form it expects before handing the bytes over. A no-op, wrapped in its own
/// try/catch, for every file that does not have this quirk.
List<int> _normalizeRelationshipTargets(List<int> bytes) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes);
    var changed = false;
    for (final file in List<ArchiveFile>.from(archive.files)) {
      if (!file.isFile || !file.name.endsWith('.rels')) continue;
      final content = utf8.decode(file.content as List<int>);
      if (!content.contains('Target="/')) continue;
      final fixed = content.replaceAllMapped(
        RegExp(r'Target="(/[^"]*)"'),
        (match) {
          var target = match.group(1)!;
          target =
              target.startsWith('/xl/') ? target.substring(4) : target.substring(1);
          return 'Target="$target"';
        },
      );
      if (fixed == content) continue;
      changed = true;
      final data = utf8.encode(fixed);
      archive.addFile(ArchiveFile(file.name, data.length, data));
    }
    if (!changed) return bytes;
    return ZipEncoder().encode(archive) ?? bytes;
  } catch (_) {
    // Best-effort only: fall through to the original bytes and let
    // Excel.decodeBytes report its own error.
    return bytes;
  }
}

/// Reads the first sheet of an `.xlsx` file. Throws [FormatException] with a
/// message the admin can act on when the file is not a usable account list.
ImportAccountSheet parseAccountSheet(List<int> bytes) {
  _checkContainerFormat(bytes);
  final normalized = _normalizeRelationshipTargets(bytes);
  final Excel excel;
  try {
    excel = Excel.decodeBytes(normalized);
  } catch (error) {
    // The generic "could not be read" message hid what actually went wrong,
    // which made this impossible to diagnose without the file in hand. Keep
    // the underlying exception in the message the admin sees.
    throw FormatException(
      'This file could not be read ($error). '
      'Open it in Excel or Google Sheets, then use File > Save As / Download '
      'as Microsoft Excel (.xlsx) and try the new copy.',
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
