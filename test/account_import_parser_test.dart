import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prosme/features/admin/bulk_import/account_import_parser.dart';

List<int> _workbook(List<List<String>> rows) {
  final excel = Excel.createExcel();
  final sheet = excel[excel.getDefaultSheet()!];
  for (final row in rows) {
    sheet.appendRow(row.map((value) => TextCellValue(value)).toList());
  }
  return excel.encode()!;
}

const _header = [
  'email',
  'full_name',
  'role',
  'country',
  'phone',
  'date_of_birth',
  'gender',
];

void main() {
  test('accepts valid rows, maps role aliases and normalises phones', () {
    final sheet = parseAccountSheet(_workbook([
      _header,
      ['Ama@Example.com', 'Ama Mensah', 'artisan', 'Ghana', '0256122555', '1990-05-01', ''],
      ['kofi@example.com', 'Kofi Asante', 'user', 'Ghana', '', '01/02/1985', 'male'],
    ]));

    expect(sheet.rows, hasLength(2));
    expect(sheet.invalid, isEmpty);

    final ama = sheet.rows[0];
    expect(ama.email, 'ama@example.com');
    expect(ama.role, 'artisan');
    expect(ama.phone, '+233256122555');
    expect(ama.dateOfBirth, '1990-05-01');
    expect(ama.gender, 'prefer_not_to_say');

    final kofi = sheet.rows[1];
    expect(kofi.role, 'customer');
    expect(kofi.phone, '');
    expect(kofi.dateOfBirth, '1985-02-01');
    expect(kofi.gender, 'male');
  });

  test('flags bad rows with reasons and keeps good rows', () {
    final sheet = parseAccountSheet(_workbook([
      _header,
      ['not-an-email', 'Bad Email', 'artisan', 'Ghana', '', '1990-05-01', ''],
      ['child@example.com', 'Too Young', 'user', 'Ghana', '', '2015-01-01', ''],
      ['role@example.com', 'Wrong Role', 'admin', 'Ghana', '', '1990-05-01', ''],
      ['phone@example.com', 'Wrong Phone', 'user', 'Ghana', '+2348012345678', '1990-05-01', ''],
      ['dup@example.com', 'First', 'user', 'Ghana', '', '1990-05-01', ''],
      ['dup@example.com', 'Second', 'user', 'Ghana', '', '1990-05-01', ''],
      ['good@example.com', 'Good Person', 'user', 'Ghana', '', '1990-05-01', ''],
    ]));

    expect(sheet.valid.map((row) => row.email), ['dup@example.com', 'good@example.com']);
    expect(sheet.invalid, hasLength(5));
    expect(sheet.rows[0].errors.single, contains('Email'));
    expect(sheet.rows[1].errors.single, contains('18'));
    expect(sheet.rows[2].errors.single, contains('Role'));
    expect(sheet.rows[3].errors.single, contains('+233'));
    expect(sheet.rows[5].errors.single, contains('more than once'));
  });

  test('reports a missing required column by name', () {
    expect(
      () => parseAccountSheet(_workbook([
        ['email', 'full_name', 'role', 'country'],
        ['a@example.com', 'A Person', 'user', 'Ghana'],
      ])),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('date_of_birth'),
        ),
      ),
    );
  });

  test('rejects a sheet with no account rows', () {
    expect(
      () => parseAccountSheet(_workbook([_header])),
      throwsA(isA<FormatException>()),
    );
  });
}
