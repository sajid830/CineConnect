import 'package:flutter_test/flutter_test.dart';

/// Helper mirroring the exact metadata construction in AuthScreen._handleAuth
Map<String, dynamic> buildSignupMetadata({
  required String selectedRole,
  required String fullName,
  required String username,
  required String mobileNumber,
}) {
  final isProduction = selectedRole == 'production' ||
      selectedRole == 'production_house' ||
      selectedRole == 'production_hub';
  final canonicalAccountType = isProduction ? 'production_house' : 'talent';

  return {
    'account_type': canonicalAccountType,
    'role': selectedRole,
    'full_name': fullName.trim(),
    'username': username.trim().toLowerCase(),
    'mobile_number': mobileNumber.trim(),
  };
}

/// Helper mirroring the post-login role resolution in AuthScreen._handleAuth
String resolvePostLoginRole({
  Map<String, dynamic>? userMetadata,
  required String fallbackRole,
}) {
  final rawRole = (userMetadata?['account_type'] as String?) ??
      (userMetadata?['role'] as String?) ??
      fallbackRole;
  return rawRole.toLowerCase().trim();
}

void main() {
  group('AuthScreen Signup Metadata Mapping', () {
    test('Talent role creates account_type "talent" with preserved fields', () {
      final metadata = buildSignupMetadata(
        selectedRole: 'talent',
        fullName: 'Jane Doe',
        username: 'janedoe',
        mobileNumber: '+919876543210',
      );

      expect(metadata['account_type'], equals('talent'));
      expect(metadata['role'], equals('talent'));
      expect(metadata['full_name'], equals('Jane Doe'));
      expect(metadata['username'], equals('janedoe'));
      expect(metadata['mobile_number'], equals('+919876543210'));
    });

    test('Legacy "user" role maps to canonical account_type "talent"', () {
      final metadata = buildSignupMetadata(
        selectedRole: 'user',
        fullName: 'Actor Alex',
        username: 'alex_actor',
        mobileNumber: '1234567890',
      );

      expect(metadata['account_type'], equals('talent'));
      expect(metadata['role'], equals('user'));
    });

    test('Production role creates account_type "production_house" with preserved fields', () {
      final metadata = buildSignupMetadata(
        selectedRole: 'production',
        fullName: 'Studio One',
        username: 'studio_one',
        mobileNumber: '+919999988888',
      );

      expect(metadata['account_type'], equals('production_house'));
      expect(metadata['role'], equals('production'));
      expect(metadata['full_name'], equals('Studio One'));
      expect(metadata['username'], equals('studio_one'));
      expect(metadata['mobile_number'], equals('+919999988888'));
    });

    test('Canonical "production_house" role maps to account_type "production_house"', () {
      final metadata = buildSignupMetadata(
        selectedRole: 'production_house',
        fullName: 'Yash Raj Films',
        username: 'yrf_studios',
        mobileNumber: '9876543210',
      );

      expect(metadata['account_type'], equals('production_house'));
      expect(metadata['role'], equals('production_house'));
    });
  });

  group('Post-Login Role Resolution', () {
    test('Prefers canonical account_type when present', () {
      final role = resolvePostLoginRole(
        userMetadata: {
          'account_type': 'production_house',
          'role': 'production',
        },
        fallbackRole: 'talent',
      );
      expect(role, equals('production_house'));
    });

    test('Falls back to legacy role claim when account_type is omitted', () {
      final role = resolvePostLoginRole(
        userMetadata: {
          'role': 'production',
        },
        fallbackRole: 'talent',
      );
      expect(role, equals('production'));
    });

    test('Falls back to selectedRole when userMetadata is empty', () {
      final role = resolvePostLoginRole(
        userMetadata: null,
        fallbackRole: 'talent',
      );
      expect(role, equals('talent'));
    });
  });
}
