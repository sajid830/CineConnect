import 'package:flutter/material.dart';
import '../../../../app/routes.dart';
import '../../../../app/theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/models/user_profile.dart';
import '../../../auth/services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiClient _apiClient = ApiClient();
  bool _isTestingBackend = false;
  String? _backendStatus;
  UserProfile? _userProfile;

  @override
  void initState() {
    super.initState();
    _fetchProfileIfLoggedIn();
  }

  Future<void> _fetchProfileIfLoggedIn() async {
    if (AuthService.instance.isAuthenticated) {
      try {
        final profileData = await _apiClient.fetchMyProfile();
        if (profileData != null && mounted) {
          setState(() {
            _userProfile = UserProfile.fromJson(profileData);
          });
        }
      } catch (e) {
        debugPrint('[HomeScreen] Failed to fetch profile: $e');
      }
    }
  }

  Future<void> _testBackendConnectivity() async {
    setState(() {
      _isTestingBackend = true;
      _backendStatus = null;
    });

    try {
      final health = await _apiClient.checkBackendHealth();
      if (mounted) {
        setState(() {
          _backendStatus = 'Backend Status: ${health['status'] ?? 'Connected'} (Service: ${health['service'] ?? 'FastAPI'})';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _backendStatus = 'Connection Error: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTestingBackend = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    await AuthService.instance.signOut();
    if (mounted) {
      setState(() {
        _userProfile = null;
      });
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final token = AuthService.instance.accessToken;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CineConnect'),
        actions: [
          if (AuthService.instance.isAuthenticated)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign Out (Supabase)',
              onPressed: _handleLogout,
            )
          else
            TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.login);
              },
              child: const Text(
                'Sign In',
                style: TextStyle(color: CinemaTheme.primaryAmber),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Foundation Initialized Card (Required for Smoke Test)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.verified_rounded, color: CinemaTheme.primaryAmber),
                        SizedBox(width: 8),
                        Text(
                          'Foundation Initialized',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'CineConnect core foundation is operational with Flutter client, Supabase Authentication, and FastAPI + PostgreSQL backend services.',
                      style: TextStyle(color: CinemaTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Authentication & Identity Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Supabase Auth Status',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (user != null ? CinemaTheme.successGreen : CinemaTheme.primaryAmber).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            user != null ? 'AUTHENTICATED' : 'ANONYMOUS',
                            style: TextStyle(
                              color: user != null ? CinemaTheme.successGreen : CinemaTheme.primaryAmber,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (user != null) ...[
                      Text('User UUID: ${user.id}', style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('Email: ${user.email ?? 'N/A'}', style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(
                        'Account Type: ${user.userMetadata?['account_type'] ?? 'talent'}',
                        style: const TextStyle(fontSize: 13, color: CinemaTheme.primaryAmber),
                      ),
                      if (token != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'JWT: ${token.substring(0, token.length > 20 ? 20 : token.length)}...',
                          style: const TextStyle(fontSize: 11, color: CinemaTheme.textSecondary),
                        ),
                      ],
                    ] else ...[
                      const Text(
                        'No active Supabase Auth session. Sign in to issue a JWT access token for FastAPI backend access.',
                        style: TextStyle(color: CinemaTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushNamed(AppRoutes.login);
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(40),
                        ),
                        child: const Text('Open Supabase Auth Login'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Core Technology Stack Card (Required for Smoke Test)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Core Technology Stack',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text('• Frontend: Flutter (Material 3 Cinema Theme)', style: TextStyle(fontSize: 13)),
                    SizedBox(height: 4),
                    Text('• Auth: Supabase Auth (Signup, Login, JWT tokens)', style: TextStyle(fontSize: 13)),
                    SizedBox(height: 4),
                    Text('• Backend: FastAPI (Python 3.12+ ASGI, JWT verification)', style: TextStyle(fontSize: 13)),
                    SizedBox(height: 4),
                    Text('• Database: PostgreSQL 16 (Relational business data & models)', style: TextStyle(fontSize: 13)),
                    SizedBox(height: 4),
                    Text('• Storage: MinIO / S3 Object Storage', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Diagnostics & Backend Connectivity (Required for Smoke Test)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'System Diagnostics',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: _isTestingBackend
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.network_check),
                      label: const Text('Test Backend Connectivity'),
                      onPressed: _isTestingBackend ? null : _testBackendConnectivity,
                    ),
                    if (_backendStatus != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: CinemaTheme.darkSurface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: CinemaTheme.borderGrey),
                        ),
                        child: Text(
                          _backendStatus!,
                          style: const TextStyle(fontSize: 13, color: CinemaTheme.primaryAmber),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

