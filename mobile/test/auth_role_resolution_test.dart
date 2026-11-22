import 'package:flutter_test/flutter_test.dart';
import 'package:cineconnect/core/config/env_config.dart';
import 'package:cineconnect/screens/auth_gate.dart';

void main() {
  group('EnvConfig Supabase Validation', () {
    test('EnvConfig.fromEnvironment() without defines reports isSupabaseConfigured == false', () {
      final config = EnvConfig.fromEnvironment();
      expect(config.isSupabaseConfigured, isFalse);
    });

    test('missingSupabaseVariables lists SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY when both missing', () {
      final config = EnvConfig.fromEnvironment();
      final missing = config.missingSupabaseVariables;

      expect(missing, contains('SUPABASE_URL'));
      expect(missing, contains('SUPABASE_PUBLISHABLE_KEY'));
      expect(missing.length, equals(2));
    });

    test('isSupabaseConfigured returns false if only URL is supplied', () {
      const config = EnvConfig(
        environment: Environment.local,
        apiBaseUrl: 'http://127.0.0.1:8000',
        appName: 'CineConnect',
        supabaseUrl: 'https://xyzcompany.supabase.co',
        supabasePublishableKey: '',
      );

      expect(config.isSupabaseConfigured, isFalse);
      expect(config.missingSupabaseVariables, equals(['SUPABASE_PUBLISHABLE_KEY']));
    });

    test('isSupabaseConfigured returns false if only key is supplied', () {
      const config = EnvConfig(
        environment: Environment.local,
        apiBaseUrl: 'http://127.0.0.1:8000',
        appName: 'CineConnect',
        supabaseUrl: '',
        supabasePublishableKey: 'sb_publishable_token_123',
      );

      expect(config.isSupabaseConfigured, isFalse);
      expect(config.missingSupabaseVariables, equals(['SUPABASE_URL']));
    });

    test('isSupabaseConfigured returns true when both URL and key are supplied', () {
      const config = EnvConfig(
        environment: Environment.local,
        apiBaseUrl: 'http://127.0.0.1:8000',
        appName: 'CineConnect',
        supabaseUrl: 'https://xyzcompany.supabase.co',
        supabasePublishableKey: 'sb_publishable_token_123',
      );

      expect(config.isSupabaseConfigured, isTrue);
      expect(config.missingSupabaseVariables, isEmpty);
      expect(config.supabaseAnonKey, equals('sb_publishable_token_123'));
    });
  });

  group('AuthGate Role Resolution (resolveUserAuthRole)', () {
    test('Canonical metadata {"account_type": "talent"} resolves to AuthRole.talent', () {
      final role = resolveUserAuthRole({'account_type': 'talent'});
      expect(role, equals(AuthRole.talent));
    });

    test('Canonical metadata {"account_type": "production_house"} resolves to AuthRole.productionHouse', () {
      final role = resolveUserAuthRole({'account_type': 'production_house'});
      expect(role, equals(AuthRole.productionHouse));
    });

    test('Canonical account_type takes precedence over legacy role claim', () {
      final role = resolveUserAuthRole({
        'account_type': 'production_house',
        'role': 'user',
      });
      expect(role, equals(AuthRole.productionHouse));
    });

    test('Legacy metadata {"role": "user"} resolves to AuthRole.talent', () {
      final role = resolveUserAuthRole({'role': 'user'});
      expect(role, equals(AuthRole.talent));
    });

    test('Legacy metadata {"role": "production"} resolves to AuthRole.productionHouse', () {
      final role = resolveUserAuthRole({'role': 'production'});
      expect(role, equals(AuthRole.productionHouse));
    });

    test('Legacy metadata {"role": "production_hub"} resolves to AuthRole.productionHouse', () {
      final role = resolveUserAuthRole({'role': 'production_hub'});
      expect(role, equals(AuthRole.productionHouse));
    });

    test('Null metadata resolves to AuthRole.unrecognized', () {
      final role = resolveUserAuthRole(null);
      expect(role, equals(AuthRole.unrecognized));
    });

    test('Empty metadata resolves to AuthRole.unrecognized', () {
      final role = resolveUserAuthRole({});
      expect(role, equals(AuthRole.unrecognized));
    });

    test('Unrecognized role claim (e.g. "admin", "manager") resolves to AuthRole.unrecognized', () {
      expect(resolveUserAuthRole({'role': 'admin'}), equals(AuthRole.unrecognized));
      expect(resolveUserAuthRole({'role': 'manager'}), equals(AuthRole.unrecognized));
      expect(resolveUserAuthRole({'account_type': 'superadmin'}), equals(AuthRole.unrecognized));
    });

    test('Case and whitespace normalization works correctly', () {
      expect(resolveUserAuthRole({'account_type': '  TALENT  '}), equals(AuthRole.talent));
      expect(resolveUserAuthRole({'account_type': 'Production_House'}), equals(AuthRole.productionHouse));
      expect(resolveUserAuthRole({'role': ' USER '}), equals(AuthRole.talent));
      expect(resolveUserAuthRole({'role': ' Production '}), equals(AuthRole.productionHouse));
    });
  });
}
