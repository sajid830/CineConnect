/// Application failure representations for UI consumption.
abstract class Failure {
  final String message;

  const Failure(this.message);

  @override
  String toString() => message;
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Unable to reach the server.']);
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Server encountered an issue.']);
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'An unexpected error occurred.']);
}
