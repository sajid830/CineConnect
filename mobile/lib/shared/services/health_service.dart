import '../../core/network/api_client.dart';
import '../../core/utils/logger.dart';
import '../models/health_status.dart';

/// Service for monitoring backend and database availability.
class HealthService {
  final ApiClient _client;

  HealthService({ApiClient? client}) : _client = client ?? ApiClient();

  /// Checks the root backend health endpoint: GET /health
  Future<HealthStatus> checkBackendHealth() async {
    try {
      final data = await _client.get('/health');
      if (data is Map<String, dynamic>) {
        return HealthStatus.fromJson(data);
      }
      return const HealthStatus(status: 'unhealthy', service: 'cineconnect-backend');
    } catch (e, stack) {
      AppLogger.warning('Backend health check failed: $e');
      AppLogger.debug('Stack: $stack');
      return HealthStatus(status: 'unreachable', service: 'cineconnect-backend');
    }
  }

  /// Checks the database health endpoint: GET /api/v1/health/db
  Future<HealthStatus> checkDatabaseHealth() async {
    try {
      final data = await _client.get('/api/v1/health/db');
      if (data is Map<String, dynamic>) {
        return HealthStatus.fromJson(data);
      }
      return const HealthStatus(status: 'unhealthy', service: 'cineconnect-backend', databaseStatus: 'disconnected');
    } catch (e) {
      AppLogger.warning('Database health check failed: $e');
      return const HealthStatus(status: 'unreachable', service: 'cineconnect-backend', databaseStatus: 'unreachable');
    }
  }
}
