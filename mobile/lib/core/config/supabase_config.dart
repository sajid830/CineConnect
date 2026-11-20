/// Supabase project configuration credentials.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://nwdzdyrdwdneottrszhc.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_mSCgNDJiH5o-xZEzK3KXrg_F4Zn7hgH',
  );

  static const String key = anonKey;
}
