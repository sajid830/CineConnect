import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'core/config/env_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase Auth using environment variables
  // ARCHITECTURE RULE: Supabase is used EXCLUSIVELY for Auth (not database).
  try {
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      anonKey: EnvConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    debugPrint('[CineConnect] Supabase Auth initialized with: ${EnvConfig.supabaseUrl}');
  } catch (e) {
    debugPrint('[CineConnect] Supabase initialization skipped or failed: $e');
  }

  runApp(const CineConnectApp());
}

