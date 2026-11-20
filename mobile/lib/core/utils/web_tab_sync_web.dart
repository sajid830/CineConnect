import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

void notifyEmailConfirmed([String? refreshToken]) {
  try {
    final payload = jsonEncode({
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'refreshToken': refreshToken,
    });
    web.window.localStorage.setItem('cineconnect_email_confirmed', payload);
  } catch (e) {
    debugPrint('notifyEmailConfirmed failed: $e');
  }
}

VoidCallback listenForEmailConfirmed(void Function() onConfirmed) {
  void checkStorage(web.Event _) {
    try {
      final value =
          web.window.localStorage.getItem('cineconnect_email_confirmed');
      if (value != null && value.isNotEmpty) {
        onConfirmed();
      }
    } catch (e) {
      debugPrint('checkStorage error: $e');
    }
  }

  final storageListener = checkStorage.toJS;
  web.window.addEventListener('storage', storageListener);

  void handleVisibility(web.Event e) {
    try {
      if (web.document.visibilityState == 'visible') {
        checkStorage(e);
      }
    } catch (err) {
      debugPrint('handleVisibility error: $err');
    }
  }

  final visListener = handleVisibility.toJS;
  web.document.addEventListener('visibilitychange', visListener);

  return () {
    try {
      web.window.removeEventListener('storage', storageListener);
      web.document.removeEventListener('visibilitychange', visListener);
    } catch (_) {}
  };
}

void tryCloseTab() {
  try {
    web.window.close();
  } catch (e) {
    debugPrint('tryCloseTab failed: $e');
  }
}

void clearConfirmedFlag() {
  try {
    web.window.localStorage.removeItem('cineconnect_email_confirmed');
  } catch (e) {
    debugPrint('clearConfirmedFlag failed: $e');
  }
}

void setPendingEmailVerification(bool value) {
  try {
    if (value) {
      web.window.localStorage
          .setItem('cineconnect_pending_verification', 'true');
    } else {
      web.window.localStorage.removeItem('cineconnect_pending_verification');
    }
  } catch (e) {
    debugPrint('setPendingEmailVerification error: $e');
  }
}

bool isPendingEmailVerification() {
  try {
    final val =
        web.window.localStorage.getItem('cineconnect_pending_verification');
    return val == 'true';
  } catch (e) {
    return false;
  }
}

void clearUrlParams() {
  try {
    web.window.history.replaceState(null, '', web.window.location.pathname);
  } catch (e) {
    debugPrint('clearUrlParams error: $e');
  }
}

void clearConfirmedQueryParam() {
  clearUrlParams();
}

void notifyPasswordUpdated() {
  try {
    final payload = jsonEncode({
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    web.window.localStorage.setItem('cineconnect_password_updated', payload);
  } catch (e) {
    debugPrint('notifyPasswordUpdated failed: $e');
  }
}

VoidCallback listenForPasswordUpdated(void Function() onUpdated) {
  void checkStorage(web.Event _) {
    try {
      final value =
          web.window.localStorage.getItem('cineconnect_password_updated');
      if (value != null && value.isNotEmpty) {
        onUpdated();
      }
    } catch (e) {
      debugPrint('listenForPasswordUpdated error: $e');
    }
  }

  final storageListener = checkStorage.toJS;
  web.window.addEventListener('storage', storageListener);

  void handleVisibility(web.Event e) {
    try {
      if (web.document.visibilityState == 'visible') {
        checkStorage(e);
      }
    } catch (err) {
      debugPrint('handleVisibility error: $err');
    }
  }

  final visListener = handleVisibility.toJS;
  web.document.addEventListener('visibilitychange', visListener);

  return () {
    try {
      web.window.removeEventListener('storage', storageListener);
      web.document.removeEventListener('visibilitychange', visListener);
    } catch (_) {}
  };
}

void clearPasswordUpdatedFlag() {
  try {
    web.window.localStorage.removeItem('cineconnect_password_updated');
  } catch (e) {
    debugPrint('clearPasswordUpdatedFlag failed: $e');
  }
}
