import 'env_config.dart';

/// Legacy Supabase configuration accessor.
/// Delegated directly to [EnvConfig] to maintain a single authoritative configuration source.
class SupabaseConfig {
  SupabaseConfig._();

  static String get url => EnvConfig.fromEnvironment().supabaseUrl;
  static String get publishableKey => EnvConfig.fromEnvironment().supabasePublishableKey;
  static String get anonKey => publishableKey;
  static String get key => publishableKey;
}
