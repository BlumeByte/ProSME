import 'package:flutter_test/flutter_test.dart';
import 'package:prosme/core/utils/location_data.dart';
import 'package:prosme/core/utils/phone_validation.dart';

const _ghana = CountryOption(
  name: 'Ghana',
  code: 'GH',
  dialCode: '+233',
  regions: [],
);
const _nigeria = CountryOption(
  name: 'Nigeria',
  code: 'NG',
  dialCode: '+234',
  regions: [],
);
const _unlisted = CountryOption(
  name: 'Testland',
  code: 'TL',
  dialCode: '+999',
  regions: [],
);

void main() {
  group('checkPhoneForCountry', () {
    test('accepts local, trunk-zero, plus and 00 forms for Ghana', () {
      for (final input in [
        '256122555',
        '0256122555',
        '+233256122555',
        '00233256122555',
        '233256122555',
        '+233 25 612 2555',
        '(025) 612-2555',
      ]) {
        final check = checkPhoneForCountry(input, _ghana);
        expect(check.isValid, isTrue, reason: input);
        expect(check.e164, '+233256122555', reason: input);
      }
    });

    test('rejects a number from another country code', () {
      final check = checkPhoneForCountry('+2348012345678', _ghana);
      expect(check.isValid, isFalse);
      expect(check.error, contains('+233'));
    });

    test('rejects a Ghana number with the wrong length or prefix', () {
      expect(checkPhoneForCountry('12345', _ghana).isValid, isFalse);
      expect(checkPhoneForCountry('1256122555', _ghana).isValid, isFalse);
      expect(checkPhoneForCountry('2561225551', _ghana).isValid, isFalse);
    });

    test('checks Nigeria by its own length and prefix rules', () {
      final ok = checkPhoneForCountry('08012345678', _nigeria);
      expect(ok.e164, '+2348012345678');
      expect(checkPhoneForCountry('0601234567', _nigeria).isValid, isFalse);
    });

    test('falls back to a length check for unlisted countries', () {
      expect(checkPhoneForCountry('123456', _unlisted).isValid, isTrue);
      expect(checkPhoneForCountry('12345', _unlisted).isValid, isFalse);
    });

    test('rejects empty input and letters', () {
      expect(checkPhoneForCountry('', _ghana).error, 'Enter a phone number.');
      expect(checkPhoneForCountry('025abc2555', _ghana).isValid, isFalse);
    });

    test('rejects a plus sign that is not first', () {
      expect(checkPhoneForCountry('0256+122555', _ghana).isValid, isFalse);
    });
  });
}
