/// Application-wide constants for CineConnect.
class AppConstants {
  AppConstants._();

  static const String appName = 'CineConnect';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Core Architecture & Foundation';

  // Network timeouts
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);

  // Storage / Preferences keys
  static const String keyAppEnvironment = 'cineconnect_env';
}
