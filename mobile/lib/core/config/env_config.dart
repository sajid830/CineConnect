import 'package:flutter/foundation.dart';

/// Configuration loaded from environment variables or `--dart-define` parameters.
class EnvConfig {
  EnvConfig._();

  /// Application environment (local, development, staging, production).
  static const String appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'local',
  );

  /// Supabase Project URL.
  /// Pass securely via build parameter: `--dart-define=SUPABASE_URL=https://...`
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://your-project-id.supabase.co',
  );

  /// Supabase Anon / Publishable Key.
  /// Pass securely via build parameter: `--dart-define=SUPABASE_ANON_KEY=...`
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'your-supabase-anon-or-publishable-key',
  );

  /// FastAPI Backend base URL.
  /// Automatically resolves to 10.0.2.2 for Android Emulator if not specified.
  static String get apiBaseUrl {
    const definedUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (definedUrl.isNotEmpty) {
      return definedUrl;
    }
    // In debug mode, default to Android emulator loopback or localhost
    if (kIsWeb) {
      return 'http://localhost:8000';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    } else {
      return 'http://127.0.0.1:8000';
    }
  }

  /// Whether the app is running in production.
  static bool get isProduction => appEnv.toLowerCase() == 'production';
}

