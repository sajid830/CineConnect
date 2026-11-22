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
  final String supabasePublishableKey;
  final int connectTimeoutMs;
  final int receiveTimeoutMs;

  const EnvConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.appName,
    this.supabaseUrl = '',
    this.supabasePublishableKey = '',
    this.connectTimeoutMs = 15000,
    this.receiveTimeoutMs = 15000,
  });

  /// Backward-compatibility alias for [supabasePublishableKey].
  String get supabaseAnonKey => supabasePublishableKey;

  /// Whether valid Supabase configuration has been provided via compile-time variables.
  bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  /// Returns missing Supabase configuration keys without exposing credentials.
  List<String> get missingSupabaseVariables {
    final missing = <String>[];
    if (supabaseUrl.isEmpty) missing.add('SUPABASE_URL');
    if (supabasePublishableKey.isEmpty) {
      missing.add('SUPABASE_PUBLISHABLE_KEY');
    }
    return missing;
  }

  /// Canonical mobile deep-link scheme and host for Supabase authentication callbacks.
  static const String mobileAuthCallbackScheme = 'cineconnect';
  static const String mobileAuthCallbackHost = 'auth-callback';
  static const String mobileAuthCallbackUri = 'cineconnect://auth-callback';

  /// Authoritative authentication callback URI.
  ///
  /// On mobile platforms (Android/iOS): returns [mobileAuthCallbackUri].
  /// On web: uses the browser origin with custom query parameters for tab sync.
  static String authCallbackUrl({bool isRecovery = false}) {
    if (kIsWeb) {
      final param = isRecovery ? 'recovery=true' : 'confirmed=true';
      return '${Uri.base.origin}/?$param';
    }
    return mobileAuthCallbackUri;
  }

  /// Validates whether an incoming URI is a trusted authentication callback for CineConnect.
  static bool isTrustedAuthCallback(Uri uri) {
    if (kIsWeb) return true;
    return uri.scheme.toLowerCase() == mobileAuthCallbackScheme &&
        uri.host.toLowerCase() == mobileAuthCallbackHost;
  }

  /// Factory to construct configuration from compile-time environment variables.
  static EnvConfig fromEnvironment() {
    const rawEnv = String.fromEnvironment('APP_ENV', defaultValue: 'local');
    const rawApiUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    const appName = String.fromEnvironment('APP_NAME', defaultValue: 'CineConnect');

    // Read SUPABASE_URL without any hardcoded fallback
    const rawSupabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');

    // Read SUPABASE_PUBLISHABLE_KEY with fallback to legacy SUPABASE_ANON_KEY define
    const rawSupabaseKey = String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: ''),
    );

    final environment = _parseEnvironment(rawEnv);
    final apiBaseUrl = rawApiUrl.isNotEmpty
        ? rawApiUrl
        : _resolveDefaultApiUrl(environment);

    return EnvConfig(
      environment: environment,
      apiBaseUrl: apiBaseUrl,
      appName: appName,
      supabaseUrl: rawSupabaseUrl.trim(),
      supabasePublishableKey: rawSupabaseKey.trim(),
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

