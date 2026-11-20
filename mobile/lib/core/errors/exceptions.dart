/// Base class for application exceptions.
abstract class AppException implements Exception {
  final String message;
  final int? statusCode;

  const AppException(this.message, [this.statusCode]);

  @override
  String toString() => 'AppException: $message (statusCode: $statusCode)';
}

/// Thrown when a network / connectivity issue occurs.
class NetworkException extends AppException {
  const NetworkException([super.message = 'Network connection failed. Please check your connectivity.']);
}

/// Thrown when the server returns a 5xx response.
class ServerException extends AppException {
  const ServerException([super.message = 'Server error encountered.', super.statusCode]);
}

/// Thrown when the request times out.
class TimeoutException extends AppException {
  const TimeoutException([super.message = 'The request timed out. Please try again.']);
}

/// Thrown when an unexpected error occurs during data parsing.
class ParseException extends AppException {
  const ParseException([super.message = 'Failed to parse response data.']);
}
