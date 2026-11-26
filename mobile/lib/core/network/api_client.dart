import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_endpoints.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic details;

  ApiException({
    required this.statusCode,
    required this.message,
    this.details,
  });

  @override
  String toString() => 'ApiException [$statusCode]: $message';
}

class ApiClient {
  static String? _globalAuthToken;
  static String? Function()? _globalTokenProvider;

  final http.Client _httpClient;
  String? _instanceAuthToken;
  String? Function()? _instanceTokenProvider;

  ApiClient({
    http.Client? client,
    String? authToken,
    String? Function()? tokenProvider,
  })  : _httpClient = client ?? http.Client(),
        _instanceAuthToken = authToken,
        _instanceTokenProvider = tokenProvider;

  /// Sets the global authenticated Supabase access token for all ApiClient instances.
  static void setGlobalAuthToken(String? token) {
    _globalAuthToken = token;
  }

  /// Sets a global token provider function for dynamic token retrieval.
  static void setGlobalTokenProvider(String? Function()? provider) {
    _globalTokenProvider = provider;
  }

  /// Clears the global authentication token and provider.
  static void clearGlobalAuthToken() {
    _globalAuthToken = null;
    _globalTokenProvider = null;
  }

  /// Sets the authentication token for this specific ApiClient instance.
  void setAuthToken(String? token) {
    _instanceAuthToken = token;
  }

  /// Sets an instance-level token provider function.
  void setTokenProvider(String? Function()? provider) {
    _instanceTokenProvider = provider;
  }

  /// Clears the authentication token and provider on this instance.
  void clearAuthToken() {
    _instanceAuthToken = null;
    _instanceTokenProvider = null;
  }

  /// Resolves the current authenticated token.
  String? get currentAuthToken => _resolveAuthToken();

  /// Resolves the current authenticated user ID from Supabase if initialized.
  static String? get currentUserId {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  /// Resolves the active access token centrally:
  /// 1. Live Supabase authentication state (real-time session truth when initialized)
  ///    - If an active session exists, returns the valid access token.
  ///    - If Supabase is initialized and user is explicitly signed out, returns null
  ///      (prevents stale instance or global tokens from persisting across logout/account switching).
  /// 2. Test / Standalone fallbacks (active only when Supabase is uninitialized):
  ///    - Instance-level explicit token
  ///    - Instance-level token provider
  ///    - Global explicit token
  ///    - Global token provider
  String? _resolveAuthToken() {
    // 1. Authoritative check: Live Supabase authentication state when initialized
    try {
      final auth = Supabase.instance.client.auth;
      final session = auth.currentSession;
      if (session != null && session.accessToken.isNotEmpty) {
        return session.accessToken;
      }
      if (auth.currentUser == null) {
        // User is explicitly signed out in Supabase.
        // Under no circumstances should an old instance or global token be returned.
        return null;
      }
    } catch (_) {
      // Supabase is uninitialized (e.g. in standalone unit or widget tests).
      // Fall through to test-injected tokens below.
    }

    // 2. Standalone/test fallback: Instance-specific explicit token
    if (_instanceAuthToken != null && _instanceAuthToken!.isNotEmpty) {
      return _instanceAuthToken;
    }

    // 3. Standalone/test fallback: Instance-specific token provider
    if (_instanceTokenProvider != null) {
      final token = _instanceTokenProvider!();
      if (token != null && token.isNotEmpty) return token;
    }

    // 4. Standalone/test fallback: Global explicit token
    if (_globalAuthToken != null && _globalAuthToken!.isNotEmpty) {
      return _globalAuthToken;
    }

    // 5. Standalone/test fallback: Global token provider
    if (_globalTokenProvider != null) {
      final token = _globalTokenProvider!();
      if (token != null && token.isNotEmpty) return token;
    }

    return null;
  }

  String? get authToken => _resolveAuthToken();

  Map<String, String> _buildHeaders({Map<String, String>? extraHeaders}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };
    final token = _resolveAuthToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }

  /// Builds a fully-qualified URI combining the base URL and endpoint path.
  /// 
  /// Guarantees:
  /// - Strips any trailing slash from base URL to prevent double slashes (e.g. "http://host:8000//api").
  /// - Ensures path starts with exactly one leading slash.
  /// - Strictly preserves intentional trailing slashes defined in endpoint paths (e.g. "/api/v1/applications/").
  /// - Strictly preserves endpoint paths defined without trailing slashes (e.g. "/api/v1/users/me").
  /// - Cleanly attaches query parameters while omitting null parameter values.
  Uri _buildUri(String path, [Map<String, dynamic>? queryParams]) {
    final rawBase = ApiEndpoints.baseUrl.trim();
    // Normalize base by removing trailing slash(es)
    final normalizedBase = rawBase.replaceAll(RegExp(r'/+$'), '');

    // Ensure path has leading slash while preserving any trailing slash
    final normalizedPath = path.startsWith('/') ? path : '/$path';

    final fullUrl = '$normalizedBase$normalizedPath';
    final uri = Uri.parse(fullUrl);

    if (queryParams != null && queryParams.isNotEmpty) {
      final cleanParams = <String, String>{};
      for (final entry in queryParams.entries) {
        if (entry.value != null) {
          cleanParams[entry.key] = entry.value.toString();
        }
      }
      if (cleanParams.isNotEmpty) {
        return uri.replace(queryParameters: cleanParams);
      }
    }
    return uri;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? queryParams}) async {
    try {
      final uri = _buildUri(path, queryParams);
      final response = await _httpClient.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 10));
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(statusCode: 0, message: 'Network or connection error: $e');
    }
  }

  Future<dynamic> post(String path, {dynamic body}) async {
    try {
      final uri = _buildUri(path);
      final response = await _httpClient
          .post(
            uri,
            headers: _buildHeaders(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 10));
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(statusCode: 0, message: 'Network or connection error: $e');
    }
  }

  Future<dynamic> put(String path, {dynamic body}) async {
    try {
      final uri = _buildUri(path);
      final response = await _httpClient
          .put(
            uri,
            headers: _buildHeaders(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 10));
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(statusCode: 0, message: 'Network or connection error: $e');
    }
  }

  Future<dynamic> patch(String path, {dynamic body}) async {
    try {
      final uri = _buildUri(path);
      final response = await _httpClient
          .patch(
            uri,
            headers: _buildHeaders(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 10));
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(statusCode: 0, message: 'Network or connection error: $e');
    }
  }

  Future<dynamic> delete(String path) async {
    try {
      final uri = _buildUri(path);
      final response = await _httpClient.delete(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 10));
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(statusCode: 0, message: 'Network or connection error: $e');
    }
  }

  dynamic _processResponse(http.Response response) {
    final statusCode = response.statusCode;
    dynamic jsonBody;
    if (response.body.isNotEmpty) {
      try {
        jsonBody = jsonDecode(response.body);
      } catch (_) {
        jsonBody = response.body;
      }
    }

    String? detailMsg;
    if (jsonBody is Map) {
      final d = jsonBody['detail'] ?? jsonBody['message'];
      if (d != null && d.toString().trim().isNotEmpty) {
        detailMsg = d.toString().trim();
      }
    }

    if (statusCode >= 200 && statusCode < 300) {
      return jsonBody;
    } else if (statusCode == 401) {
      throw ApiException(
        statusCode: 401,
        message: detailMsg ?? 'Authentication required or token expired.',
        details: jsonBody,
      );
    } else if (statusCode == 403) {
      throw ApiException(
        statusCode: 403,
        message: detailMsg ?? 'Access forbidden: You do not have permission for this action.',
        details: jsonBody,
      );
    } else if (statusCode == 404) {
      throw ApiException(
        statusCode: 404,
        message: detailMsg ?? 'Requested resource not found.',
        details: jsonBody,
      );
    } else if (statusCode == 422) {
      throw ApiException(
        statusCode: 422,
        message: detailMsg ?? 'Validation error from API.',
        details: jsonBody,
      );
    } else {
      throw ApiException(
        statusCode: statusCode,
        message: detailMsg ?? 'HTTP Error $statusCode',
        details: jsonBody,
      );
    }
  }
}
