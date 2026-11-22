import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'router/app_router.dart';
import 'theme.dart';

/// Central GoRouter provider.
final routerProvider = Provider<GoRouter>((ref) => appRouter);

/// Root CineConnect application widget.
class CineConnectApp extends StatelessWidget {
  const CineConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
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
