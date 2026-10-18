import 'package:flutter_test/flutter_test.dart';
import 'package:campusfix/features/users/models/user_profile.dart';
import 'package:campusfix/features/users/models/user_role.dart';

void main() {
  test('Preserves profile data through a round trip', () {
    const original = UserProfile(
      id: 'user-1',
      fullName: 'Test User',
      email: 'user@example.com',
      role: UserRole.technician,
    );

    final restored = UserProfile.fromMap(
      id: original.id,
      data: original.toMap(),
    );

    expect(restored.id, original.id);
    expect(restored.fullName, original.fullName);
    expect(restored.email, original.email);
    expect(restored.role, original.role);
  });

  test('Rejects an unsupported role', () {
    expect(
      () => UserProfile.fromMap(
        id: 'user-1',
        data: {
          'fullName': 'Test User',
          'email': 'user@example.com',
          'role': 'superuser',
        },
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('Rejects a profile without an email', () {
    expect(
      () => UserProfile.fromMap(
        id: 'user-1',
        data: {
          'fullName': 'Test User',
          'role': 'reporter',
        },
      ),
      throwsA(isA<FormatException>()),
    );
  });
}