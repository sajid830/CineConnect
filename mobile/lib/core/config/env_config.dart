import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Available application deployment environments.
enum Environment {
  local,
  development,
  staging,
  production,
}

/// Central environment configuration loaded via --dart-define.
class EnvConfig {
  final Environment environment;
  final String apiBaseUrl;
  final String appName;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final int connectTimeoutMs;
  final int receiveTimeoutMs;

  const EnvConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.appName,
    this.supabaseUrl = 'https://nwdzdyrdwdneottrszhc.supabase.co',
    this.supabaseAnonKey = 'sb_publishable_mSCgNDJiH5o-xZEzK3KXrg_F4Zn7hgH',
    this.connectTimeoutMs = 15000,
    this.receiveTimeoutMs = 15000,
  });

  /// Factory to construct configuration from compile-time environment variables.
  static EnvConfig fromEnvironment() {
    const rawEnv = String.fromEnvironment('APP_ENV', defaultValue: 'local');
    const rawApiUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    const appName = String.fromEnvironment('APP_NAME', defaultValue: 'CineConnect');
    const rawSupabaseUrl = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://nwdzdyrdwdneottrszhc.supabase.co',
    );
    const rawSupabaseAnonKey = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'sb_publishable_mSCgNDJiH5o-xZEzK3KXrg_F4Zn7hgH',
    );

    final environment = _parseEnvironment(rawEnv);
    final apiBaseUrl = rawApiUrl.isNotEmpty
        ? rawApiUrl
        : _resolveDefaultApiUrl(environment);

    return EnvConfig(
      environment: environment,
      apiBaseUrl: apiBaseUrl,
      appName: appName,
      supabaseUrl: rawSupabaseUrl,
      supabaseAnonKey: rawSupabaseAnonKey,
    );
  }

  static Environment _parseEnvironment(String env) {
    switch (env.toLowerCase()) {
      case 'prod':
      case 'production':
        return Environment.production;
      case 'staging':
        return Environment.staging;
      case 'dev':
      case 'development':
        return Environment.development;
      case 'local':
      default:
        return Environment.local;
    }
  }

  static String _resolveDefaultApiUrl(Environment env) {
    if (env == Environment.production) {
      return 'https://api.cineconnect.app';
    } else if (env == Environment.staging) {
      return 'https://staging-api.cineconnect.app';
    }

    // Local / Dev host routing
    if (kIsWeb) {
      return 'http://localhost:8000';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android emulator loops back to host machine via 10.0.2.2
        return 'http://10.0.2.2:8000';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      default:
        return 'http://127.0.0.1:8000';
    }
  }

  bool get isProduction => environment == Environment.production;
  bool get isDevelopment => environment == Environment.development || environment == Environment.local;
}

/// Riverpod provider exposing the immutable application environment configuration.
final envConfigProvider = Provider<EnvConfig>((ref) {
  return EnvConfig.fromEnvironment();
});

