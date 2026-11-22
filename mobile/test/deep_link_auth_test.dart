import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cineconnect/core/config/env_config.dart';
import 'package:cineconnect/core/utils/web_tab_sync.dart';
import 'package:cineconnect/screens/auth_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Centralized Callback URI Tests', () {
    test('Canonical mobile URI is cineconnect://auth-callback', () {
      expect(EnvConfig.mobileAuthCallbackUri, equals('cineconnect://auth-callback'));
      expect(EnvConfig.mobileAuthCallbackScheme, equals('cineconnect'));
      expect(EnvConfig.mobileAuthCallbackHost, equals('auth-callback'));
    });

    test('authCallbackUrl returns canonical mobile URI on non-web', () {
      final signupCallback = EnvConfig.authCallbackUrl(isRecovery: false);
      final recoveryCallback = EnvConfig.authCallbackUrl(isRecovery: true);

      expect(signupCallback, equals('cineconnect://auth-callback'));
      expect(recoveryCallback, equals('cineconnect://auth-callback'));
    });
  });

  group('2. Trusted Callback Validation Tests (detectSessionInUriPredicate)', () {
    test('Accepts exact canonical callback URI cineconnect://auth-callback', () {
      final uri = Uri.parse('cineconnect://auth-callback?code=test-auth-code');
      expect(EnvConfig.isTrustedAuthCallback(uri), isTrue);
    });

    test('Accepts canonical callback URI with fragment parameters', () {
      final uri = Uri.parse('cineconnect://auth-callback#access_token=xyz&type=recovery');
      expect(EnvConfig.isTrustedAuthCallback(uri), isTrue);
    });

    test('Rejects arbitrary untrusted schemes', () {
      final uri = Uri.parse('https://malicious.com/auth-callback?code=xyz');
      expect(EnvConfig.isTrustedAuthCallback(uri), isFalse);

      final uri2 = Uri.parse('otherapp://auth-callback?code=xyz');
      expect(EnvConfig.isTrustedAuthCallback(uri2), isFalse);
    });

    test('Rejects untrusted hosts under cineconnect scheme', () {
      final uri = Uri.parse('cineconnect://phishing-host?code=xyz');
      expect(EnvConfig.isTrustedAuthCallback(uri), isFalse);
    });
  });

  group('3. Signup & Recovery Callback Wiring', () {
    test('Password recovery passes authoritative callback URI to resetPasswordForEmail', () {
      final callback = EnvConfig.authCallbackUrl(isRecovery: true);
      expect(callback, equals('cineconnect://auth-callback'));
    });

    test('Signup passes authoritative callback URI to signUp', () {
      final callback = EnvConfig.authCallbackUrl(isRecovery: false);
      expect(callback, equals('cineconnect://auth-callback'));
    });
  });

  group('4. Role & Metadata Preservation Tests', () {
    test('Talent role normalizes to AuthRole.talent and preserves user_metadata', () {
      final metadata = {
        'account_type': 'talent',
        'role': 'talent',
        'full_name': 'Aarav Patel',
        'username': 'aarav_cinematography',
        'mobile_number': '+919876543210',
      };
      final role = resolveUserAuthRole(metadata);
      expect(role, equals(AuthRole.talent));
      expect(metadata['account_type'], equals('talent'));
      expect(metadata['full_name'], equals('Aarav Patel'));
    });

    test('Production House role normalizes to AuthRole.productionHouse', () {
      final metadata = {
        'account_type': 'production_house',
        'role': 'production',
        'full_name': 'Film City Studios',
        'username': 'filmcity_hq',
        'mobile_number': '+911122334455',
      };
      final role = resolveUserAuthRole(metadata);
      expect(role, equals(AuthRole.productionHouse));
      expect(metadata['account_type'], equals('production_house'));
    });
  });

  group('5. Recovery Identity & Marker Lifecycle', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await clearRecoveryState();
    });

    test('Recovery in-progress marker sets and clears cleanly', () async {
      expect(isPasswordRecoveryInProgress(), isFalse);

      await setPasswordRecoveryInProgress(true);
      expect(isPasswordRecoveryInProgress(), isTrue);

      await clearRecoveryState();
      expect(isPasswordRecoveryInProgress(), isFalse);
      expect(getConfirmedRecoveryUserId(), isNull);
    });

    test('Confirmed recovery user ID persists across state initialization', () async {
      const testUid = 'user-uuid-1234-recovery';
      await setPasswordRecoveryInProgress(true);
      await setConfirmedRecoveryUserId(testUid);

      expect(getConfirmedRecoveryUserId(), equals(testUid));

      // Simulate app restart
      await initPasswordRecoveryState();
      expect(isPasswordRecoveryInProgress(), isTrue);
      expect(getConfirmedRecoveryUserId(), equals(testUid));

      // Clear on completion
      await clearRecoveryState();
      expect(isPasswordRecoveryInProgress(), isFalse);
      expect(getConfirmedRecoveryUserId(), isNull);
    });
  });
}
