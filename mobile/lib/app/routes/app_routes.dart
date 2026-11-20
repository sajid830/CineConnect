import 'package:flutter/material.dart';
import '../../features/home/presentation/home_screen.dart';

/// Centralized route definitions and generator for CineConnect.
class AppRoutes {
  AppRoutes._();

  static const String home = '/';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
      default:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
          settings: settings,
        );
    }
  }
}
