import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/production_house_user.dart';

/// The backend answered 409: this username already exists.
class UsernameTakenException implements Exception {
  const UsernameTakenException();
}

/// The account exists, but the email link has not been clicked yet.
class EmailNotConfirmedException implements Exception {
  const EmailNotConfirmedException();
}

abstract class AuthRepository {
  Future<ProductionHouseUser> login({
    required String email,
    required String password,
  });

  Future<ProductionHouseUser> signUp({
    required String companyName,
    required String email,
    required String password,
    String? username,
    String? phone,
  });

  /// Sends the "Confirm your email address" email again.
  Future<void> resendConfirmationEmail({required String email});

  /// Emits once, when the person has clicked the link in their email and
  /// the account is signed in. The real version listens to Supabase's
  /// auth state changes (the link opens the app through a deep link).
  Stream<ProductionHouseUser> watchEmailConfirmation({required String email});
}

class MockAuthRepository implements AuthRepository {
  // Pretend these usernames already exist, so you can test the error.
  static const _taken = {'admin', 'cineconnect', 'sunrise_films'};

  final Map<String, ProductionHouseUser> _pending = {};
  final StreamController<String> _confirmed = StreamController.broadcast();

  @override
  Future<ProductionHouseUser> login({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    if (_pending.containsKey(email.toLowerCase())) {
      throw const EmailNotConfirmedException();
    }
    if (password.length < 6) {
      throw Exception('Invalid email or password');
    }
    return ProductionHouseUser.fromJson({
      'id': 'mock-123',
      'email': email,
      'company_name': 'Sunrise Films',
      'is_verified': true,
    });
  }

  @override
  Future<ProductionHouseUser> signUp({
    required String companyName,
    required String email,
    required String password,
    String? username,
    String? phone,
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    if (username != null && _taken.contains(username)) {
      throw const UsernameTakenException();
    }
    final user = ProductionHouseUser.fromJson({
      'id': 'mock-456',
      'email': email,
      'company_name': companyName,
      'is_verified': false,
    });
    final key = email.toLowerCase();
    _pending[key] = user;
    // Pretend the person clicks the link in their email after 12 seconds.
    Timer(const Duration(seconds: 12), () {
      if (_pending.remove(key) != null) _confirmed.add(key);
    });
    return user;
  }

  @override
  Future<void> resendConfirmationEmail({required String email}) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Stream<ProductionHouseUser> watchEmailConfirmation({required String email}) {
    final key = email.toLowerCase();
    return _confirmed.stream.where((e) => e == key).map(
          (_) => ProductionHouseUser.fromJson({
            'id': 'mock-456',
            'email': email,
            'company_name': 'Sunrise Films',
            'is_verified': true,
          }),
        );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return MockAuthRepository();
});