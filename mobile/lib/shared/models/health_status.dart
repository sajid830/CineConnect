/// Model representing health response from CineConnect backend.
class HealthStatus {
  final String status;
  final String service;
  final String? environment;
  final String? version;
  final String? databaseStatus;
  final double? latencyMs;

  const HealthStatus({
    required this.status,
    required this.service,
    this.environment,
    this.version,
    this.databaseStatus,
    this.latencyMs,
  });

  factory HealthStatus.fromJson(Map<String, dynamic> json) {
    return HealthStatus(
      status: json['status'] as String? ?? 'unknown',
      service: json['service'] as String? ?? 'cineconnect-backend',
      environment: json['environment'] as String?,
      version: json['version'] as String?,
      databaseStatus: json['database'] as String?,
      latencyMs: (json['latency_ms'] as num?)?.toDouble(),
    );
  }

  bool get isHealthy => status.toLowerCase() == 'healthy';
  bool get isDbHealthy => databaseStatus?.toLowerCase() == 'connected';
}
