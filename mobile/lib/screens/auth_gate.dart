import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cineconnect/app/theme.dart';
import 'package:cineconnect/core/utils/web_tab_sync.dart';
import 'package:cineconnect/features/home/presentation/screens/home_screen.dart';
import 'auth_screen.dart';
import 'forgot_password_screen.dart';
import 'role_selection_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _authSubscription;
  bool _handledConfirmation = false;
  bool _isPasswordRecovery = false;
  String _confirmedRole = 'user';
  String? _confirmedEmail;

  bool get _isConfirmedRedirect =>
      kIsWeb && Uri.base.queryParameters['confirmed'] == 'true';

  bool get _isRecoveryRedirect =>
      kIsWeb && Uri.base.queryParameters['recovery'] == 'true';

  @override
  void initState() {
    super.initState();
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        if (mounted) setState(() => _isPasswordRecovery = true);
      } else if (data.event == AuthChangeEvent.signedOut ||
          data.event == AuthChangeEvent.signedIn) {
        if (mounted && _isPasswordRecovery) {
          setState(() => _isPasswordRecovery = false);
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleConfirmedSession(Session session) async {
    if (_handledConfirmation) return;
    _handledConfirmation = true;

    final role = (session.user.userMetadata?['role'] as String?) ?? 'user';
    final email = session.user.email;

    setState(() {
      _confirmedRole = role;
      _confirmedEmail = email;
    });

    // 1. Signal original tab
    notifyEmailConfirmed();

    // 2. Immediately sign out temporary auto-login session
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint('Error signing out confirmation tab: $e');
    }
    setPendingEmailVerification(false);

    // 3. Try to close this tab
    tryCloseTab();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Show small standard spinner while Supabase checks authentication state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.gold,
                ),
              ),
            ),
          );
        }

        // Grab active session if one exists
        final session = snapshot.data?.session ??
            Supabase.instance.client.auth.currentSession;
        final event = snapshot.data?.event;

        // Check password recovery mode
        final isRecovery = _isPasswordRecovery ||
            event == AuthChangeEvent.passwordRecovery ||
            _isRecoveryRedirect;

        if (isRecovery) {
          // While in recovery redirect on web, wait briefly until Supabase parses token
          if (_isRecoveryRedirect && session == null) {
            return const Scaffold(
              backgroundColor: AppColors.background,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.gold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Opening password reset...',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final role =
              (session?.user.userMetadata?['role'] as String?) ?? 'user';
          final email = session?.user.email;
          return ForgotPasswordScreen(
            selectedRole: role,
            initialEmail: email,
            isRecoveryMode: true,
          );
        }

        // Special handling for the Gmail confirmation link tab (?confirmed=true)
        if (_isConfirmedRedirect) {
          if (session != null && !_handledConfirmation) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _handleConfirmedSession(session);
            });
          }

          if (_handledConfirmation) {
            return _EmailVerifiedTabFallback(
              role: _confirmedRole,
              email: _confirmedEmail,
            );
          }

          // Waiting for Supabase to finish parsing the confirmation token from the URL
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.gold,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Verifying your email...',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Normal app flow: if logged in and not pending verification, render real HomeScreen
        if (session != null && !isPendingEmailVerification()) {
          final role = session.user.userMetadata?['role'] as String?;
          return HomeScreen(roleType: role, userType: role);
        }

        // Normal app flow: if logged out (or pending verification), render RoleSelectionScreen
        return const RoleSelectionScreen();
      },
    );
  }
}

class _EmailVerifiedTabFallback extends StatelessWidget {
  final String role;
  final String? email;

  const _EmailVerifiedTabFallback({
    required this.role,
    this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.gold,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Verification Successful!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'You can close this tab and return to your CineConnect window, or log in below.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 36),
                ElevatedButton(
                  onPressed: () {
                    clearConfirmedQueryParam();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AuthScreen(
                          selectedRole: role,
                          initialIsLogin: true,
                          initialEmail: email,
                          successMessage:
                              'Verification successful! Please log in to continue.',
                        ),
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Go to Login',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
