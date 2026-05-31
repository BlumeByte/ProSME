import 'package:flutter_test/flutter_test.dart';
import 'package:prosme/config/constants.dart';
import 'package:prosme/services/auth_service.dart';

void main() {
  test('MockAuthService signs in and updates role', () async {
    final service = MockAuthService();
    final user = await service.signInWithEmail('demo@example.com', 'pass');

    expect(user.email, 'demo@example.com');

    await service.updateRole(UserRole.artisan);
    expect(service.currentUser?.role, UserRole.artisan);
  });

  test('MockAuthService enforces unique usernames and releases on change/delete', () async {
    final service = MockAuthService();

    final first = await service.signUpWithEmail(
      'first@example.com',
      'pass',
      username: 'first_user',
    );
    expect(first.name, 'first_user');

    expect(
      () => service.signUpWithEmail(
        'second@example.com',
        'pass',
        username: 'first_user',
      ),
      throwsA(isA<StateError>()),
    );

    await service.updateUsername('updated_user');
    await service.updatePhone('+233 54 111 2222');
    await service.updateEmail('updated@example.com');
    expect(service.currentUser?.phone, '+233 54 111 2222');
    expect(service.currentUser?.email, 'updated@example.com');

    final second = await service.signUpWithEmail(
      'second@example.com',
      'pass',
      username: 'first_user',
    );
    expect(second.email, 'second@example.com');

    await service.deleteAccount();

    final third = await service.signUpWithEmail(
      'third@example.com',
      'pass',
      username: 'first_user',
    );
    expect(third.email, 'third@example.com');
  });
}
