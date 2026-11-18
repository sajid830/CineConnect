class AppConstants {
  AppConstants._();

  static const String appName = 'CineConnect';
  static const String appTagline = 'Cinema & Creative Media Collaboration Platform';

  // API Endpoints
  static const String apiV1Prefix = '/api/v1';
  static const String healthEndpoint = '/health';
  static const String usersMeEndpoint = '$apiV1Prefix/users/me';
  static const String opportunitiesEndpoint = '$apiV1Prefix/opportunities';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  // Storage keys
  static const String tokenKey = 'cineconnect_jwt_token';
  static const String userKey = 'cineconnect_user_profile';
}

