import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service managing Supabase Authentication for CineConnect.
///
/// ARCHITECTURE CONSTRAINT:
/// Supabase is utilized EXCLUSIVELY for authentication (signup, login,
/// logout, password reset, and access token issuance).
/// Application data, tables, and schemas are NEVER created or stored in Supabase.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  SupabaseClient? _client;

  /// Internal reference to the initialized Supabase client.
  SupabaseClient get client {
    _client ??= Supabase.instance.client;
    return _client!;
  }

  /// Whether Supabase has been initialized.
  bool get isInitialized {
    try {
      final _ = Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Current authenticated user from Supabase Auth.
  User? get currentUser {
    if (!isInitialized) return null;
    return client.auth.currentUser;
  }

  /// Current active Supabase Auth session.
  Session? get currentSession {
    if (!isInitialized) return null;
    return client.auth.currentSession;
  }

  /// JWT access token issued by Supabase Auth for backend authorization.
  String? get accessToken {
    if (!isInitialized) return null;
    return client.auth.currentSession?.accessToken;
  }

  /// Authenticated Supabase user UUID (used as primary key in PostgreSQL).
  String? get userId {
    if (!isInitialized) return null;
    return client.auth.currentUser?.id;
  }

  /// True if user is currently logged in.
  bool get isAuthenticated => currentSession != null;

  /// Stream of authentication state changes.
  Stream<AuthState> get authStateChanges {
    if (!isInitialized) return const Stream.empty();
    return client.auth.onAuthStateChange;
  }

  /// Sign up a new user using Supabase Auth.
  /// Passes [fullName] and [accountType] in `user_metadata` so our
  /// FastAPI backend can synchronize the PostgreSQL `users` record.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String accountType,
  }) async {
    try {
      final response = await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'account_type': accountType.toLowerCase(),
        },
      );
      debugPrint('[AuthService] Supabase sign up successful: ${response.user?.id}');
      return response;
    } catch (e) {
      debugPrint('[AuthService] Supabase sign up failed: $e');
      rethrow;
    }
  }

  /// Authenticate an existing user using email and password.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      debugPrint('[AuthService] Supabase sign in successful: ${response.user?.id}');
      return response;
    } catch (e) {
      debugPrint('[AuthService] Supabase sign in failed: $e');
      rethrow;
    }
  }

  /// Sign out the current user and invalidate the local session.
  Future<void> signOut() async {
    try {
      if (isInitialized) {
        await client.auth.signOut();
        debugPrint('[AuthService] Supabase sign out complete');
      }
    } catch (e) {
      debugPrint('[AuthService] Supabase sign out failed: $e');
      rethrow;
    }
  }

  /// Trigger password recovery email through Supabase Auth.
  Future<void> resetPassword({required String email}) async {
    try {
      await client.auth.resetPasswordForEmail(email.trim());
      debugPrint('[AuthService] Password reset email requested for: $email');
    } catch (e) {
      debugPrint('[AuthService] Password reset failed: $e');
      rethrow;
    }
  }
}

