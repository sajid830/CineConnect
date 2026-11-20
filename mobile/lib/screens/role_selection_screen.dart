import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:cineconnect/features/auth/presentation/screens/login_screen.dart'
    as feature_auth;
import '../app/theme.dart';
import '../services/landing_api_service.dart';
import 'auth_screen.dart';
import 'package:cineconnect/features/home/presentation/screens/home_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final LandingApiService _landingApi = LandingApiService();
  bool _backendOnline = false;
  bool _checkedHealth = false;
  String? _existingUserEmail;
  String? _loadingRole;

  @override
  void initState() {
    super.initState();
    _checkLandingContext();
  }

  Future<void> _checkLandingContext() async {
    final isHealthy = await _landingApi.checkBackendHealth();
    final currentUser = _landingApi.getCurrentSupabaseUser();

    if (mounted) {
      setState(() {
        _backendOnline = isHealthy;
        _checkedHealth = true;
        _existingUserEmail = currentUser?.email;
      });
    }
  }

  Future<void> _selectRole(String roleType) async {
    if (_loadingRole != null) return;
    setState(() => _loadingRole = roleType);
    try {
      if (roleType == 'production') {
        // Connect landing page to the existing Production House authentication interface
        final goRouter = GoRouter.maybeOf(context);
        if (goRouter != null) {
          context.go('/login/production');
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const _ProductionHouseHost(),
            ),
          );
        }
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AuthScreen(selectedRole: 'user'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingRole = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // Top Bar with Brand & Backend Health Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.movie_creation,
                            color: AppColors.goldLight, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'CINECONNECT',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Health Status Pill
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _backendOnline
                                ? AppColors.gold
                                : AppColors.goldLight,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _checkedHealth
                              ? (_backendOnline ? 'API Online' : 'Cloud Ready')
                              : 'Connecting...',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              const Text(
                'Choose Your Type',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              const Text(
                'Select your profile type to continue to the CineConnect login and signup portal.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: AppColors.textMuted, height: 1.5),
              ),
              const SizedBox(height: 32),

              // Existing Active Session Banner (if logged in)
              if (_existingUserEmail != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_circle,
                          color: AppColors.gold, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Active Session Detected',
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                            Text(
                              _existingUserEmail!,
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _loadingRole == 'continue'
                            ? null
                            : () async {
                                setState(() => _loadingRole = 'continue');
                                try {
                                  await Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const HomeScreen(roleType: 'user')),
                                  );
                                } finally {
                                  if (mounted) {
                                    setState(() => _loadingRole = null);
                                  }
                                }
                              },
                        child: _loadingRole == 'continue'
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  color: AppColors.gold,
                                ),
                              )
                            : const Text('Continue',
                                style: TextStyle(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Talent Card
              _buildRoleCard(
                context: context,
                badgeText: 'FOR PERFORMERS & CREW',
                title: 'Talent',
                subtitle: 'Find roles, showcase your portfolio',
                icon: Icons.star_rounded,
                iconColor: AppColors.gold,
                tags: ['Auditions', 'Portfolio', 'Showreels'],
                roleType: 'user',
                isLoading: _loadingRole == 'user',
              ),
              const SizedBox(height: 20),

              // Production Card
              _buildRoleCard(
                context: context,
                badgeText: 'FOR STUDIOS & DIRECTORS',
                title: 'Production House',
                subtitle: 'Post jobs, hire top talent',
                icon: Icons.videocam_rounded,
                iconColor: AppColors.goldLight,
                tags: ['Casting Calls', 'Crew Search', 'Management'],
                roleType: 'production',
                isLoading: _loadingRole == 'production',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String badgeText,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required List<String> tags,
    required String roleType,
    required bool isLoading,
  }) {
    return GestureDetector(
      onTap: () => _selectRole(roleType),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge & Action / Spinner
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5),
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.gold,
                    ),
                  )
                else
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.gold,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Icon & Text
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: iconColor, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tags
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) => _buildTag(tag)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.gold,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

/// Dedicated host wrapper providing the GoRouter environment required by
/// the existing Production House [feature_auth.LoginScreen] and dashboard navigation.
class _ProductionHouseHost extends StatelessWidget {
  const _ProductionHouseHost();

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/login/production',
      routes: [
        GoRoute(
          path: '/login/:type',
          name: 'production_login',
          builder: (context, state) {
            final type = state.pathParameters['type'] ?? 'production';
            if (type == 'talent') {
              return const AuthScreen(selectedRole: 'user');
            }
            return feature_auth.LoginScreen(userType: type);
          },
        ),
        GoRoute(
          path: '/',
          name: 'landing',
          builder: (context, state) => const RoleSelectionScreen(),
        ),
        GoRoute(
          path: '/home',
          name: 'production_home',
          builder: (context, state) => const HomeScreen(
            roleType: 'production',
            userType: 'production',
          ),
        ),
      ],
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
