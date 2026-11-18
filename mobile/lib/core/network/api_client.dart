import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';
import '../../features/auth/services/auth_service.dart';

/// HTTP Client that communicates with the CineConnect FastAPI backend.
/// Automatically injects the Supabase JWT access token into the Authorization header.
class ApiClient {
  final http.Client _httpClient;
  final String baseUrl;

  ApiClient({http.Client? httpClient, String? baseUrl})
      : _httpClient = httpClient ?? http.Client(),
        baseUrl = baseUrl ?? EnvConfig.apiBaseUrl;

  /// Default headers, attaching Supabase JWT Bearer token if available.
  Map<String, String> _buildHeaders([Map<String, String>? customHeaders]) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final token = AuthService.instance.accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }
    return headers;
  }

  /// Sends a GET request to the CineConnect FastAPI backend.
  Future<http.Response> get(String path, {Map<String, String>? headers}) async {
    final url = Uri.parse('$baseUrl$path');
    debugPrint('[ApiClient] GET $url');
    return await _httpClient.get(url, headers: _buildHeaders(headers));
  }

  /// Sends a POST request to the CineConnect FastAPI backend.
  Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('$baseUrl$path');
    debugPrint('[ApiClient] POST $url');
    return await _httpClient.post(
      url,
      headers: _buildHeaders(headers),
      body: body != null ? jsonEncode(body) : null,
    );
  }

  /// Sends a PUT request to the CineConnect FastAPI backend.
  Future<http.Response> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('$baseUrl$path');
    debugPrint('[ApiClient] PUT $url');
    return await _httpClient.put(
      url,
      headers: _buildHeaders(headers),
      body: body != null ? jsonEncode(body) : null,
    );
  }

  /// Performs a health check against the FastAPI backend service.
  Future<Map<String, dynamic>> checkBackendHealth() async {
    try {
      final response = await get('/health');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {
        'status': 'error',
        'code': response.statusCode,
        'detail': response.body,
      };
    } catch (e) {
      return {
        'status': 'unreachable',
        'error': e.toString(),
      };
    }
  }

  /// Fetches the authenticated user profile from our PostgreSQL database via FastAPI.
  Future<Map<String, dynamic>?> fetchMyProfile() async {
    final response = await get('/api/v1/users/me');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }
}

