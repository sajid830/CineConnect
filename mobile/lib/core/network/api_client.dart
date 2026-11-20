import 'dart:convert';
import 'package:http/http.dart' as http;
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
  final http.Client _httpClient;
  String? _authToken;

  ApiClient({http.Client? client}) : _httpClient = client ?? http.Client();

  void setAuthToken(String? token) {
    _authToken = token;
  }

  String? get authToken => _authToken;

  Map<String, String> _buildHeaders({Map<String, String>? extraHeaders}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }

  Uri _buildUri(String path, [Map<String, dynamic>? queryParams]) {
    final base = ApiEndpoints.baseUrl;
    final fullUrl = '$base$path';
    final uri = Uri.parse(fullUrl);
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams.map((k, v) => MapEntry(k, v.toString())));
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

    if (statusCode >= 200 && statusCode < 300) {
      return jsonBody;
    } else if (statusCode == 401) {
      throw ApiException(statusCode: 401, message: 'Authentication required or token expired.', details: jsonBody);
    } else if (statusCode == 403) {
      throw ApiException(statusCode: 403, message: 'Access forbidden. Talent permissions required.', details: jsonBody);
    } else if (statusCode == 404) {
      throw ApiException(statusCode: 404, message: 'Requested resource not found.', details: jsonBody);
    } else if (statusCode == 422) {
      throw ApiException(statusCode: 422, message: 'Validation error from API.', details: jsonBody);
    } else {
      throw ApiException(statusCode: statusCode, message: 'HTTP Error $statusCode', details: jsonBody);
    }
  }
}
