import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Lightweight logging utility with level filtering.
class AppLogger {
  AppLogger._();

  static void debug(String message, {String tag = 'DEBUG', Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      developer.log(
        message,
        name: tag,
        error: error,
        stackTrace: stackTrace,
        level: 500,
      );
    }
  }

  static void info(String message, {String tag = 'INFO'}) {
    developer.log(
      message,
      name: tag,
      level: 800,
    );
  }

  static void warning(String message, {String tag = 'WARN', Object? error}) {
    developer.log(
      message,
      name: tag,
      error: error,
      level: 900,
    );
  }

  static void error(String message, {String tag = 'ERROR', Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      name: tag,
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
  }
}
