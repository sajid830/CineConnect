import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../shared/models/health_status.dart';
import '../../../shared/services/health_service.dart';
import '../../../shared/widgets/cine_button.dart';

/// Diagnostic screen for verifying backend health, PostgreSQL connectivity,
/// and local environment network loopbacks.
class DiagnosticHomeScreen extends StatefulWidget {
  const DiagnosticHomeScreen({super.key});

  @override
  State<DiagnosticHomeScreen> createState() => _DiagnosticHomeScreenState();
}

class _DiagnosticHomeScreenState extends State<DiagnosticHomeScreen> {
  final HealthService _healthService = HealthService();

  HealthStatus? _apiHealth;
  HealthStatus? _dbHealth;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkHealth();
  }

  Future<void> _checkHealth() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiStatus = await _healthService.checkBackendHealth();
      final dbStatus = await _healthService.checkDatabaseHealth();

      setState(() {
        _apiHealth = apiStatus;
        _dbHealth = dbStatus;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Backend Diagnostics'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FastAPI Backend Status',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isLoading
                            ? 'Checking...'
                            : _apiHealth != null
                                ? 'Status: ${_apiHealth!.status.toUpperCase()}'
                                : 'Not Connected',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      const Divider(color: AppColors.border, height: 24),
                      const Text(
                        'PostgreSQL Database Status',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isLoading
                            ? 'Checking...'
                            : _dbHealth != null
                                ? 'Status: ${(_dbHealth!.databaseStatus ?? _dbHealth!.status).toUpperCase()}'
                                : 'Not Connected',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Error: $_errorMessage',
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Spacer(),
              CineButton(
                label: _isLoading ? 'Checking...' : 'Re-test Connectivity',
                onPressed: _isLoading ? null : _checkHealth,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
