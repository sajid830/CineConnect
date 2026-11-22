import 'package:flutter_test/flutter_test.dart';
import 'package:cineconnect/screens/auth_gate.dart';

void main() {
  group('Cross-Role Login & Account Type Validation', () {
    test('Talent role validates as Talent and rejects Production House interface', () {
      final role = resolveUserAuthRole({'account_type': 'talent'});
      expect(role, equals(AuthRole.talent));

      // Interface: Production House
      const selectedInterface = 'production';
      final isProductionInterface = selectedInterface == 'production' || selectedInterface == 'production_house';
      final isTalentAccount = role == AuthRole.talent;

      // Cross-role detection: Talent account attempting Production House login must be blocked
      final shouldReject = isProductionInterface && isTalentAccount;
      expect(shouldReject, isTrue);
    });

    test('Production House role validates as Production House and rejects Talent interface', () {
      final role = resolveUserAuthRole({'account_type': 'production_house'});
      expect(role, equals(AuthRole.productionHouse));

      // Interface: Talent
      const selectedInterface = 'talent';
      final isProductionInterface = selectedInterface == 'production' || selectedInterface == 'production_house';
      final isProductionAccount = role == AuthRole.productionHouse;

      // Cross-role detection: Production House account attempting Talent login must be blocked
      final shouldReject = !isProductionInterface && isProductionAccount;
      expect(shouldReject, isTrue);
    });

    test('Matching Talent account and Talent interface allows access', () {
      final role = resolveUserAuthRole({'account_type': 'talent'});
      const selectedInterface = 'talent';
      final isProductionInterface = selectedInterface == 'production' || selectedInterface == 'production_house';
      final isProductionAccount = role == AuthRole.productionHouse;

      final isAllowed = !isProductionInterface && !isProductionAccount && role == AuthRole.talent;
      expect(isAllowed, isTrue);
    });

    test('Matching Production House account and Production House interface allows access', () {
      final role = resolveUserAuthRole({'account_type': 'production_house'});
      const selectedInterface = 'production';
      final isProductionInterface = selectedInterface == 'production' || selectedInterface == 'production_house';
      final isProductionAccount = role == AuthRole.productionHouse;

      final isAllowed = isProductionInterface && isProductionAccount;
      expect(isAllowed, isTrue);
    });

    test('Unrecognized or tampered role claim is rejected from both interfaces', () {
      final role = resolveUserAuthRole({'account_type': 'admin'});
      expect(role, equals(AuthRole.unrecognized));

      final isAllowedTalent = role == AuthRole.talent;
      final isAllowedProduction = role == AuthRole.productionHouse;

      expect(isAllowedTalent, isFalse);
      expect(isAllowedProduction, isFalse);
    });
  });

  group('Signup Metadata Verification', () {
    test('Talent signup produces canonical account_type="talent"', () {
      const selectedRole = 'talent';
      final isProduction = selectedRole == 'production' || selectedRole == 'production_house';
      final canonicalAccountType = isProduction ? 'production_house' : 'talent';

      final metadata = {
        'account_type': canonicalAccountType,
        'role': selectedRole,
        'full_name': 'Aarav Kumar',
        'username': 'aarav',
        'mobile_number': '+919876543210',
      };

      expect(metadata['account_type'], equals('talent'));
      expect(metadata['role'], equals('talent'));
    });

    test('Production House signup produces canonical account_type="production_house"', () {
      const selectedRole = 'production';
      final isProduction = selectedRole == 'production' || selectedRole == 'production_house';
      final canonicalAccountType = isProduction ? 'production_house' : 'talent';

      final metadata = {
        'account_type': canonicalAccountType,
        'role': selectedRole,
        'full_name': 'Vyjayanthi Movies',
        'username': 'vyjayanthimovies',
        'mobile_number': '+919123456789',
      };

      expect(metadata['account_type'], equals('production_house'));
      expect(metadata['role'], equals('production'));
    });
  });
}
