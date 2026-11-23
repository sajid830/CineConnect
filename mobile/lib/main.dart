import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'app/theme.dart';
import 'core/config/env_config.dart';
import 'core/utils/web_tab_sync.dart';

// Re-export CineConnectApp, theme and colors for compatibility across screens
export 'app/app.dart' show CineConnectApp;
export 'app/theme.dart' show AppColors, AppTheme;

/// Global ProviderObserver for diagnosing Riverpod provider state changes and errors
class _AppProviderObserver extends ProviderObserver {
  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    debugPrint(
        '[Riverpod Error] ${provider.name ?? provider.runtimeType}: $error\n$stackTrace');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initPasswordRecoveryState();

  // Custom release-mode error widget replacing the default grey error box
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF0D0D0D),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              kReleaseMode
                  ? 'Something went wrong. Please restart the app.'
                  : details.exceptionAsString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  };

  final config = EnvConfig.fromEnvironment();

  if (!config.isSupabaseConfigured) {
    runApp(
      _SupabaseConfigMissingApp(missingVariables: config.missingSupabaseVariables),
    );
    return;
  }

  try {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabasePublishableKey,
      authOptions: const FlutterAuthClientOptions(
        detectSessionInUriPredicate: EnvConfig.isTrustedAuthCallback,
      ),
    );
  } catch (e) {
    debugPrint('Supabase initialization failed: $e');
    runApp(
      _SupabaseInitErrorApp(error: e.toString()),
    );
    return;
  }

  runApp(
    ProviderScope(
      observers: [_AppProviderObserver()],
      child: const CineConnectApp(),
    ),
  );
}

/// Fallback application shown when fresh Supabase credentials have not been configured yet.
class _SupabaseConfigMissingApp extends StatelessWidget {
  final List<String> missingVariables;

  const _SupabaseConfigMissingApp({required this.missingVariables});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.settings_suggest_rounded,
                    color: AppColors.gold,
                    size: 64,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Supabase Setup Required',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'The following compile-time environment variables are missing:\n${missingVariables.join(", ")}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text(
                      'Please run with your fresh Supabase project credentials:\n\n'
                      'flutter run \\\n'
                      '  --dart-define=SUPABASE_URL=https://<your-project>.supabase.co \\\n'
                      '  --dart-define=SUPABASE_PUBLISHABLE_KEY=<your-key> \\\n'
                      '  --dart-define=API_BASE_URL=http://localhost:8000',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: AppColors.goldLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fallback application shown if Supabase.initialize throws an exception.
class _SupabaseInitErrorApp extends StatelessWidget {
  final String error;

  const _SupabaseInitErrorApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                    size: 64,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Supabase Initialization Failed',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    error,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
