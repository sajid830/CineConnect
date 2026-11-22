import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/env_config.dart';

/// Dedicated API Service for the Landing / Onboarding Entry ONLY.
/// 
/// In accordance with CineConnect frontend architecture:
/// - Only Landing & Onboarding related routes are handled here.
/// - All remaining feature routes (Projects, Opportunities, Applications, Portfolio,
///   Social Posts, Interactions, Connections, Collaborations, Chat, Search, 
///   Notifications, and Dashboards) are kept separate and NOT merged here.
class LandingApiService {
  final Dio _dio;
  final String _baseUrl;

  LandingApiService({Dio? dio, String? baseUrl})
      : _dio = dio ?? Dio(),
        _baseUrl = (baseUrl ?? EnvConfig.fromEnvironment().apiBaseUrl).trim().replaceAll(RegExp(r'/+$'), '');

  /// Root health check: GET /health
  /// Verifies backend availability without requiring authentication.
  Future<bool> checkBackendHealth() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/health',
        options: Options(
          sendTimeout: const Duration(milliseconds: 3000),
          receiveTimeout: const Duration(milliseconds: 3000),
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Versioned API health check: GET /api/v1/health
  /// Checks service name, environment, and version info.
  Future<Map<String, dynamic>?> checkApiV1Health() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/api/v1/health',
        options: Options(
          sendTimeout: const Duration(milliseconds: 3000),
          receiveTimeout: const Duration(milliseconds: 3000),
        ),
      );
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
    } catch (_) {
      // Backend may be offline or unreachable during preview
    }
    return null;
  }

  /// Database connectivity health check: GET /api/v1/health/db
  Future<bool> checkDbHealth() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/api/v1/health/db',
        options: Options(
          sendTimeout: const Duration(milliseconds: 3000),
          receiveTimeout: const Duration(milliseconds: 3000),
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Check if a user is currently authenticated via Supabase session
  User? getCurrentSupabaseUser() {
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Get current session token for API authorization
  String? getCurrentAccessToken() {
    try {
      return Supabase.instance.client.auth.currentSession?.accessToken;
    } catch (_) {
      return null;
    }
  }

  /// Check current authenticated user profile: GET /api/v1/users/me
  Future<Map<String, dynamic>?> getAuthenticatedUserProfile() async {
    final token = getCurrentAccessToken();
    if (token == null) return null;

    try {
      final response = await _dio.get(
        '$_baseUrl/api/v1/users/me',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          sendTimeout: const Duration(milliseconds: 5000),
          receiveTimeout: const Duration(milliseconds: 5000),
        ),
      );
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
    } catch (_) {
      // User profile may not be created yet or server is unreachable
    }
    return null;
  }

  /// Check current authenticated Production House profile: GET /api/v1/production-houses/me
  Future<Map<String, dynamic>?> getAuthenticatedProductionHouseProfile() async {
    final token = getCurrentAccessToken();
    if (token == null) return null;

    try {
      final response = await _dio.get(
        '$_baseUrl/api/v1/production-houses/me',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          sendTimeout: const Duration(milliseconds: 5000),
          receiveTimeout: const Duration(milliseconds: 5000),
        ),
      );
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
    } catch (_) {
      // Production house profile may not be created yet or server is unreachable
    }
    return null;
  }
}
