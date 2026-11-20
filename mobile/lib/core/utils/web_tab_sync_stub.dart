import 'package:flutter/foundation.dart';

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

void clearConfirmedQueryParam() {}

void clearUrlParams() {}

void notifyPasswordUpdated() {}

VoidCallback listenForPasswordUpdated(void Function() onUpdated) {
  return () {};
}

void clearPasswordUpdatedFlag() {}
