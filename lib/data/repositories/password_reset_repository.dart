import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class PasswordResetRepository {
  /// Sends a reset link to [email]. Same result whether or not the
  /// account exists, so we never reveal who is registered.
  Future<void> sendResetLink(String email);
}

class MockPasswordResetRepository implements PasswordResetRepository {
  @override
  Future<void> sendResetLink(String email) async {
    await Future.delayed(const Duration(milliseconds: 700));
  }
}

final passwordResetRepositoryProvider = Provider<PasswordResetRepository>(
  (ref) => MockPasswordResetRepository(),
);