import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cineconnect/app/theme.dart';
import 'package:cineconnect/core/config/env_config.dart';
import 'package:cineconnect/core/network/dio_client.dart';
import 'package:cineconnect/screens/role_selection_screen.dart';

/// Landing screen validating foundation health and framework readiness.
class HomeScreen extends ConsumerStatefulWidget {
  final String? roleType;
  final String? userType;

  const HomeScreen({super.key, this.roleType, this.userType});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isCheckingHealth = false;
  String? _healthStatusMessage;

  Future<void> _checkBackendConnectivity() async {
    setState(() {
      _isCheckingHealth = true;
      _healthStatusMessage = null;
    });

    final dio = ref.read(dioClientProvider);
    final env = ref.read(envConfigProvider);

    try {
      final response = await dio.get('/health');
      if (mounted) {
        setState(() {
          _healthStatusMessage =
              'Connected! Status: ${response.data['status']}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(
              'Backend reachable at ${env.apiBaseUrl} (status: ${response.data['status']})',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _healthStatusMessage = 'Connection failed: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(
              'Failed to reach ${env.apiBaseUrl}. Ensure Docker is running.',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingHealth = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final env = ref.watch(envConfigProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'CC',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'CineConnect',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.gold),
            tooltip: 'Log Out',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const RoleSelectionScreen()),
                  (route) => false,
                );
              }
            },
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              (widget.roleType ?? widget.userType ?? env.environment.name)
                  .toUpperCase(),
              style: const TextStyle(
                color: AppColors.goldLight,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Status Card: "Foundation Initialized"
              Card(
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified,
                              color: AppColors.gold,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Foundation Initialized',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Clean Architecture • Riverpod • GoRouter • Dio',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'The core structure of CineConnect mobile client is configured and verified. '
                        'Ready for domain features and custom UI components.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                      if (_healthStatusMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.darkest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            _healthStatusMessage!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Section: "Core Technology Stack"
              const Text(
                'Core Technology Stack',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 12),

              const _TechStackRow(
                icon: Icons.flutter_dash,
                title: 'Flutter SDK & Material 3',
                subtitle: 'Cinema Dark Theme with CineConnect Gold accents',
              ),
              const SizedBox(height: 10),
              const _TechStackRow(
                icon: Icons.layers_outlined,
                title: 'State Management: Riverpod',
                subtitle: 'Declarative, compile-safe dependency injection',
              ),
              const SizedBox(height: 10),
              const _TechStackRow(
                icon: Icons.alt_route,
                title: 'Routing: GoRouter',
                subtitle: 'URL-driven declarative routing & deep linking',
              ),
              const SizedBox(height: 10),
              _TechStackRow(
                icon: Icons.http,
                title: 'Networking: Dio',
                subtitle: 'Base URL: ${env.apiBaseUrl}',
              ),

              const SizedBox(height: 24),

              // Section: Curved Dual-Wheel Navigation Scaffold Preview
              Card(
                color: AppColors.surfaceElevated,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.donut_large,
                              color: AppColors.gold, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Next Feature: Curved Dual-Wheel Nav',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Slot prepared for the upcoming interactive dual-wheel radial menu '
                        'connecting Talent, Crew, Productions, and Vendors.',
                        style:
                            TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Diagnostics Button: "Test Backend Connectivity"
              ElevatedButton.icon(
                onPressed: _isCheckingHealth ? null : _checkBackendConnectivity,
                icon: _isCheckingHealth
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.bolt, color: Colors.black),
                label: const Text('Test Backend Connectivity'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TechStackRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _TechStackRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.star_outline,
                color: AppColors.goldLight, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
