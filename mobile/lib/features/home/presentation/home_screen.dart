import 'package:flutter/material.dart';
import '../../../core/config/env_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/models/health_status.dart';
import '../../../shared/services/health_service.dart';
import '../../../shared/widgets/cine_button.dart';

/// CineConnect Foundation Home Screen.
/// Demonstrates theme, environment configuration, responsive layout,
/// and backend connectivity diagnostics.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HealthService _healthService = HealthService();
  bool _isCheckingHealth = false;
  HealthStatus? _backendStatus;
  HealthStatus? _dbStatus;
  String? _lastCheckedMessage;

  Future<void> _runDiagnostics() async {
    setState(() {
      _isCheckingHealth = true;
      _lastCheckedMessage = null;
    });

    final backend = await _healthService.checkBackendHealth();
    final db = await _healthService.checkDatabaseHealth();

    if (mounted) {
      setState(() {
        _isCheckingHealth = false;
        _backendStatus = backend;
        _dbStatus = db;
        _lastCheckedMessage = 'Checked at ${TimeOfDay.now().format(context)}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'CC',
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(AppConstants.appName),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              EnvConfig.environmentName,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Hero Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Foundation Initialized',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                AppConstants.appTagline,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'CineConnect core architecture has been successfully configured. The project is ready for multi-developer feature branching.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Environment & Network Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'API Configuration',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Environment', EnvConfig.environmentName, context),
                    const Divider(height: 16),
                    _buildInfoRow('Base API URL', EnvConfig.apiBaseUrl, context),
                    const Divider(height: 16),
                    _buildInfoRow('API v1 Endpoint', EnvConfig.apiV1BaseUrl, context),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Architecture Stack Overview
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Core Technology Stack',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildPillarItem(
                      icon: Icons.phone_android_rounded,
                      title: 'Mobile Frontend',
                      subtitle: 'Flutter & Dart (Android / iOS support)',
                      context: context,
                    ),
                    const SizedBox(height: 12),
                    _buildPillarItem(
                      icon: Icons.bolt_rounded,
                      title: 'Async Backend',
                      subtitle: 'FastAPI, Pydantic, SQLAlchemy 2.x async',
                      context: context,
                    ),
                    const SizedBox(height: 12),
                    _buildPillarItem(
                      icon: Icons.storage_rounded,
                      title: 'Database Engine',
                      subtitle: 'PostgreSQL 16 with asyncpg & Alembic migrations',
                      context: context,
                    ),
                    const SizedBox(height: 12),
                    _buildPillarItem(
                      icon: Icons.layers_rounded,
                      title: 'Infrastructure',
                      subtitle: 'Docker Compose with isolated networks & volumes',
                      context: context,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Live Diagnostics Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Backend Diagnostics',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_lastCheckedMessage != null)
                          Text(
                            _lastCheckedMessage!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDiagnosticRow(
                      'FastAPI Service',
                      _backendStatus?.status ?? 'Not tested',
                      _backendStatus?.isHealthy ?? false,
                      context,
                    ),
                    const SizedBox(height: 10),
                    _buildDiagnosticRow(
                      'PostgreSQL Connectivity',
                      _dbStatus?.databaseStatus ?? 'Not tested',
                      _dbStatus?.isDbHealthy ?? false,
                      context,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: CineButton(
                        label: 'Test Backend Connectivity',
                        icon: Icons.sensors_rounded,
                        isLoading: _isCheckingHealth,
                        onPressed: _runDiagnostics,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildPillarItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required BuildContext context,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiagnosticRow(
    String label,
    String status,
    bool isPositive,
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color badgeColor;
    if (status == 'Not tested') {
      badgeColor = colorScheme.onSurfaceVariant;
    } else if (isPositive) {
      badgeColor = Colors.green;
    } else {
      badgeColor = colorScheme.error;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}
