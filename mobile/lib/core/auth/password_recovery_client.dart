import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cineconnect/core/config/env_config.dart';

/// Client abstraction for CineConnect password recovery operations.
///
/// Decouples authentication logic from UI presentation to allow
/// deterministic unit and widget testing with fakes or mocks.
abstract class PasswordRecoveryClient {
  /// Requests a password reset email/code for [email].
  Future<void> resetPasswordForEmail(String email);

  /// Verifies the 6-digit recovery code using [OtpType.recovery].
  Future<AuthResponse> verifyRecoveryOtp({
    required String email,
    required String token,
  });

  /// Updates the authenticated user's password.
  Future<UserResponse> updatePassword(String newPassword);

  /// Signs out the active recovery session.
  Future<void> signOut();
}

/// Production implementation backed by Supabase Auth.
class SupabasePasswordRecoveryClient implements PasswordRecoveryClient {
  final GoTrueClient _auth;

  static GoTrueClient _resolveDefaultClient() {
    try {
      return Supabase.instance.client.auth;
    } catch (_) {
      // Fallback for test environments without Supabase.initialize()
      return GoTrueClient();
    }
  }

  SupabasePasswordRecoveryClient([GoTrueClient? auth])
      : _auth = auth ?? _resolveDefaultClient();

  @override
  Future<void> resetPasswordForEmail(String email) {
    return _auth.resetPasswordForEmail(
      email,
      redirectTo: EnvConfig.authCallbackUrl(isRecovery: true),
    );
  }

  @override
  Future<AuthResponse> verifyRecoveryOtp({
    required String email,
    required String token,
  }) {
    return _auth.verifyOTP(
      type: OtpType.recovery,
      email: email,
      token: token,
    );
  }

  @override
  Future<UserResponse> updatePassword(String newPassword) {
    return _auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  @override
  Future<void> signOut() {
    return _auth.signOut();
  }
}
