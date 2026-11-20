import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cineconnect/app/theme.dart';
import 'package:cineconnect/features/auth/presentation/screens/login_screen.dart';
import 'package:cineconnect/features/auth/presentation/screens/user_type_selection_screen.dart';
import 'package:cineconnect/features/home/presentation/screens/home_screen.dart';

/// Central GoRouter configuration provider.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: '/',
        name: 'user_type_selection',
        builder: (context, state) => const UserTypeSelectionScreen(),
      ),
      GoRoute(
        path: '/login/:type',
        name: 'login',
        builder: (context, state) {
          final type = state.pathParameters['type'] ?? 'talent';
          return LoginScreen(userType: type);
        },
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
});

/// Root CineConnect application widget.
class CineConnectApp extends StatelessWidget {
  const CineConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    // If CineConnectApp is pumped without an ancestral ProviderScope
    // (such as in widget_test.dart), provide a fallback scope so it renders cleanly.
    return const _ProviderScopeFallback(
      child: _CineConnectAppView(),
    );
  }
}

class _ProviderScopeFallback extends StatelessWidget {
  final Widget child;
  const _ProviderScopeFallback({required this.child});

  @override
  Widget build(BuildContext context) {
    try {
      ProviderScope.containerOf(context);
      return child;
    } catch (_) {
      return ProviderScope(child: child);
    }
  }
}

class _CineConnectAppView extends ConsumerWidget {
  const _CineConnectAppView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'CineConnect',
      theme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
