import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kRecoveryInProgressKey = 'cineconnect_recovery_in_progress';
const String _kRecoveryUserIdKey = 'cineconnect_recovery_user_id';

void notifyEmailConfirmed([String? refreshToken]) {}

VoidCallback listenForEmailConfirmed(void Function() onConfirmed) {
  return () {};
}

void tryCloseTab() {}

void clearConfirmedFlag() {}

bool _pendingVerification = false;

void setPendingEmailVerification(bool value) {
  _pendingVerification = value;
}

bool isPendingEmailVerification() => _pendingVerification;

bool _passwordRecoveryInProgress = false;
String? _confirmedRecoveryUserId;

Future<void> initPasswordRecoveryState() async {
  try {
    final sp = await SharedPreferences.getInstance();
    _passwordRecoveryInProgress =
        sp.getBool(_kRecoveryInProgressKey) ?? false;
    _confirmedRecoveryUserId = sp.getString(_kRecoveryUserIdKey);
  } catch (_) {
    // Gracefully ignore during unit tests
  }
}

Future<void> setPasswordRecoveryInProgress(bool value) async {
  _passwordRecoveryInProgress = value;
  try {
    final sp = await SharedPreferences.getInstance();
    if (value) {
      await sp.setBool(_kRecoveryInProgressKey, true);
    } else {
      await sp.remove(_kRecoveryInProgressKey);
    }
  } catch (e) {
    debugPrint('setPasswordRecoveryInProgress storage error: $e');
  }
}

bool isPasswordRecoveryInProgress() => _passwordRecoveryInProgress;

Future<void> setConfirmedRecoveryUserId(String? userId) async {
  _confirmedRecoveryUserId = userId;
  try {
    final sp = await SharedPreferences.getInstance();
    if (userId != null && userId.isNotEmpty) {
      await sp.setString(_kRecoveryUserIdKey, userId);
    } else {
      await sp.remove(_kRecoveryUserIdKey);
    }
  } catch (e) {
    debugPrint('setConfirmedRecoveryUserId storage error: $e');
  }
}

String? getConfirmedRecoveryUserId() => _confirmedRecoveryUserId;

Future<void> clearRecoveryState() async {
  _passwordRecoveryInProgress = false;
  _confirmedRecoveryUserId = null;
  try {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kRecoveryInProgressKey);
    await sp.remove(_kRecoveryUserIdKey);
  } catch (e) {
    debugPrint('clearRecoveryState storage error: $e');
  }
}

void clearConfirmedQueryParam() {}

void clearUrlParams() {}

void notifyPasswordUpdated() {}

VoidCallback listenForPasswordUpdated(void Function() onUpdated) {
  return () {};
}

void clearPasswordUpdatedFlag() {}
