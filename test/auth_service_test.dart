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
}
