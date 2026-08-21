import 'package:flutter_test/flutter_test.dart';
import 'package:prosme/config/constants.dart';

void main() {
  test('release fallback connects to the production Supabase project', () {
    expect(kSupabaseUrl, 'https://wbnvifrzckjttyxhmlcf.supabase.co');
    expect(kSupabaseAnonKey, isNot(kSupabaseAnonKeyPlaceholder));
    expect(kSupabaseAnonKey, startsWith('sb_publishable_'));
  });
}
