import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cineconnect/app/theme.dart';
import 'package:cineconnect/core/auth/password_recovery_client.dart';
import 'package:cineconnect/core/network/api_client.dart';
import 'package:cineconnect/core/network/api_endpoints.dart';
import 'package:cineconnect/core/utils/web_tab_sync.dart';
import 'package:cineconnect/features/talent/presentation/talent_portal_screen.dart';
import 'package:cineconnect/features/production_house/dashboard/dashboard_screen.dart';
import 'forgot_password_screen.dart';
import 'role_selection_screen.dart';

/// Normalized application roles supported by CineConnect.
enum AuthRole {
  talent,
  productionHouse,
  unrecognized,
}

/// Normalizes Supabase user metadata into canonical CineConnect roles.
///
/// Priority:
/// 1. `account_type` canonical claim ('talent', 'production_house')
/// 2. `role` legacy claim ('talent', 'user', 'production', 'production_house', 'production_hub')
/// Returns [AuthRole.unrecognized] if the role is missing or unknown.
AuthRole resolveUserAuthRole(Map<String, dynamic>? metadata) {
  if (metadata == null) return AuthRole.unrecognized;

  final rawRole =
      (metadata['account_type'] as String?) ?? (metadata['role'] as String?);
  if (rawRole == null) return AuthRole.unrecognized;

  final normalized = rawRole.toLowerCase().trim();
  switch (normalized) {
    case 'talent':
    case 'user':
      return AuthRole.talent;
    case 'production':
    case 'production_house':
    case 'production_hub':
      return AuthRole.productionHouse;
    default:
      return AuthRole.unrecognized;
  }
}

class AuthGate extends StatefulWidget {
  final Stream<AuthState>? authStream;
  final Session? initialSession;
  final PasswordRecoveryClient? recoveryClient;
  final bool autoCheckHealth;
  final ApiClient? apiClient;
  final Future<String?> Function(Session session)? profileFetcher;

  const AuthGate({
    super.key,
    this.authStream,
    this.initialSession,
    this.recoveryClient,
    this.autoCheckHealth = true,
    this.apiClient,
    this.profileFetcher,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _authSubscription;
  bool _handledConfirmation = false;
  bool _isPasswordRecovery = false;
  String _confirmedRole = 'talent';
  String? _confirmedEmail;

  // Authoritative Backend Profile State
  String? _resolvedUserId;
  String? _fetchingUserId;
  AuthRole? _authoritativeRole;
  String? _rawBackendRole;
  bool _isLoadingProfile = false;
  String? _profileError;

  bool get _isConfirmedRedirect =>
      kIsWeb && Uri.base.queryParameters['confirmed'] == 'true';

  bool get _isRecoveryRedirect =>
      kIsWeb && Uri.base.queryParameters['recovery'] == 'true';

  @override
  void initState() {
    super.initState();
    initPasswordRecoveryState().then((_) {
      if (mounted) setState(() {});
    });

    _subscribeToAuthStream();

    final initialSession = widget.initialSession ??
        () {
          try {
            return Supabase.instance.client.auth.currentSession;
          } catch (_) {
            return null;
          }
        }();
    if (initialSession != null &&
        !isPendingEmailVerification() &&
        !isPasswordRecoveryInProgress()) {
      _fetchAuthoritativeProfile(initialSession);
    }
  }

  void _subscribeToAuthStream() {
    _authSubscription?.cancel();

    Stream<AuthState>? stream = widget.authStream;
    if (stream == null) {
      try {
        stream = Supabase.instance.client.auth.onAuthStateChange;
      } catch (_) {
        stream = null;
      }
    }

    // Synchronize current initial session token to ApiClient
    final initialSession = widget.initialSession ??
        () {
          try {
            return Supabase.instance.client.auth.currentSession;
          } catch (_) {
            return null;
          }
        }();
    if (initialSession != null && initialSession.accessToken.isNotEmpty) {
      ApiClient.setGlobalAuthToken(initialSession.accessToken);
    } else {
      ApiClient.setGlobalAuthToken(null);
    }

    if (stream != null) {
      _authSubscription = stream.listen((data) async {
        final session = data.session;
        final token = session?.accessToken;

        switch (data.event) {
          case AuthChangeEvent.signedIn:
          case AuthChangeEvent.initialSession:
          case AuthChangeEvent.tokenRefreshed:
          case AuthChangeEvent.userUpdated:
          case AuthChangeEvent.mfaChallengeVerified:
            if (token != null && token.isNotEmpty) {
              ApiClient.setGlobalAuthToken(token);
            }
            if (session != null &&
                !isPendingEmailVerification() &&
                !isPasswordRecoveryInProgress()) {
              if (session.user.id != _resolvedUserId) {
                _fetchAuthoritativeProfile(session);
              }
            }
            break;
          case AuthChangeEvent.signedOut:
            ApiClient.clearGlobalAuthToken();
            if (mounted) {
              setState(() {
                _isPasswordRecovery = false;
                _resolvedUserId = null;
                _fetchingUserId = null;
                _authoritativeRole = null;
                _rawBackendRole = null;
                _isLoadingProfile = false;
                _profileError = null;
              });
            }
            break;
          case AuthChangeEvent.passwordRecovery:
            if (token != null && token.isNotEmpty) {
              ApiClient.setGlobalAuthToken(token);
            }
            // 1. Immediately activate the in-memory recovery guard
            _isPasswordRecovery = true;
            if (mounted) setState(() => _isPasswordRecovery = true);

            // 2. Capture data.session?.user.id and update confirmed identity
            final recoveryUid = data.session?.user.id;
            if (recoveryUid != null && recoveryUid.isNotEmpty) {
              try {
                // 3. Awaited, error-handled persistence operation
                await setConfirmedRecoveryUserId(recoveryUid);
              } catch (e) {
                debugPrint('Failed to persist confirmed recovery user ID: $e');
              }
            } else {
              debugPrint(
                  'Warning: passwordRecovery event received with missing session user ID');
            }

            if (mounted) setState(() {});
            break;
          default:
            break;
        }
      }, onError: (error) {
        debugPrint('AuthGate auth subscription error: $error');
      });
    }
  }

  /// Fetches authoritative user profile from backend: GET /api/v1/users/me
  Future<void> _fetchAuthoritativeProfile(Session session, {bool force = false}) async {
    final userId = session.user.id;
    // Deduplication check: prevent redundant calls during in-flight fetch or after resolution
    if (!force && _fetchingUserId == userId && (_authoritativeRole != null || _isLoadingProfile)) {
      return;
    }
    _fetchingUserId = userId;
    if (mounted) {
      setState(() {
        _isLoadingProfile = true;
        _profileError = null;
      });
    }

    try {
      String? backendAccountType;

      if (widget.profileFetcher != null) {
        backendAccountType = await widget.profileFetcher!(session);
      } else {
        // Ensure token is synchronized to ApiClient before requesting profile
        final token = session.accessToken;
        if (token.isNotEmpty) {
          ApiClient.setGlobalAuthToken(token);
        }
        final client = widget.apiClient ?? ApiClient();
        final res = await client.get(ApiEndpoints.myProfile);
        if (res is Map<String, dynamic>) {
          backendAccountType = res['account_type'] as String?;
        }
      }

      if (!mounted || _fetchingUserId != userId) return;

      if (backendAccountType != null && backendAccountType.isNotEmpty) {
        final normalized = backendAccountType.trim().toLowerCase();
        AuthRole resolvedRole;
        if (normalized == 'production_house' ||
            normalized == 'production' ||
            normalized == 'production_hub') {
          resolvedRole = AuthRole.productionHouse;
        } else if (normalized == 'talent' || normalized == 'user') {
          resolvedRole = AuthRole.talent;
        } else {
          resolvedRole = AuthRole.unrecognized;
        }

        setState(() {
          _resolvedUserId = userId;
          _authoritativeRole = resolvedRole;
          _rawBackendRole = backendAccountType;
          _isLoadingProfile = false;
          _profileError = null;
        });
        return;
      }

      _handleProfileFetchFallback(session, 'Empty or null account_type in profile response.');
    } catch (e) {
      if (!mounted || _fetchingUserId != userId) return;

      if (e is ApiException && e.statusCode == 401) {
        debugPrint('AuthGate: Session rejected by backend (401 Unauthorized). Signing out.');
        try {
          await Supabase.instance.client.auth.signOut();
        } catch (_) {}
        ApiClient.clearGlobalAuthToken();
        setState(() {
          _resolvedUserId = null;
          _fetchingUserId = null;
          _authoritativeRole = null;
          _isLoadingProfile = false;
          _profileError = 'Session expired. Please sign in again.';
        });
        return;
      }

      _handleProfileFetchFallback(session, e.toString());
    }
  }

  void _handleProfileFetchFallback(Session session, String errorDetails) {
    debugPrint('AuthGate profile fetch error: $errorDetails');
    final fallbackRole = resolveUserAuthRole(session.user.userMetadata);
    setState(() {
      _resolvedUserId = session.user.id;
      _authoritativeRole =
          fallbackRole != AuthRole.unrecognized ? fallbackRole : null;
      _rawBackendRole = session.user.userMetadata?['account_type'] as String? ??
          session.user.userMetadata?['role'] as String?;
      _isLoadingProfile = false;
      _profileError = fallbackRole != AuthRole.unrecognized
          ? null
          : 'Unable to verify account credentials with the server. Please check your connection and try again.';
    });
  }

  @override
  void didUpdateWidget(AuthGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authStream != widget.authStream ||
        oldWidget.initialSession != widget.initialSession) {
      if (oldWidget.initialSession != widget.initialSession) {
        _resolvedUserId = null;
        _fetchingUserId = null;
        _authoritativeRole = null;
        _profileError = null;
      }
      _subscribeToAuthStream();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleConfirmedSession(Session session) async {
    if (_handledConfirmation) return;
    _handledConfirmation = true;

    final roleEnum = resolveUserAuthRole(session.user.userMetadata);
    final role = roleEnum == AuthRole.productionHouse ? 'production' : 'talent';
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
    Stream<AuthState>? authStream = widget.authStream;
    Session? activeSession = widget.initialSession;

    if (authStream == null) {
      try {
        authStream = Supabase.instance.client.auth.onAuthStateChange;
        activeSession = Supabase.instance.client.auth.currentSession;
      } catch (_) {
        authStream = null;
        activeSession = null;
      }
    }

    if (authStream == null) {
      // Supabase is uninitialized (e.g. in widget smoke tests)
      return RoleSelectionScreen(autoCheckHealth: widget.autoCheckHealth);
    }

    return StreamBuilder<AuthState>(
      stream: authStream,
      builder: (context, snapshot) {
        // Show small standard spinner while Supabase checks authentication state
        if (snapshot.connectionState == ConnectionState.waiting &&
            activeSession == null) {
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
        final event = snapshot.data?.event;
        final session = event == AuthChangeEvent.signedOut
            ? null
            : (snapshot.data?.session ?? activeSession);

        // Check password recovery mode
        final isEventPasswordRecovery =
            event == AuthChangeEvent.passwordRecovery;
        final hasRuntimeRecoveryEvent = _isPasswordRecovery ||
            isEventPasswordRecovery ||
            _isRecoveryRedirect;
        final hasPersistentRecoveryState = isPasswordRecoveryInProgress();

        if (hasRuntimeRecoveryEvent || hasPersistentRecoveryState) {
          if (session == null && _isRecoveryRedirect) {
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
                      'Validating recovery link...',
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

          if (session == null) {
            // Stale recovery state without session: safely clear and show role selection
            clearRecoveryState();
            return RoleSelectionScreen(autoCheckHealth: widget.autoCheckHealth);
          }

          // A session is present. Verify confirmed recovery session identity:
          final confirmedRecoveryUserId = getConfirmedRecoveryUserId();
          final isConfirmedRecoveryUser = hasRuntimeRecoveryEvent ||
              (confirmedRecoveryUserId != null &&
                  confirmedRecoveryUserId == session.user.id);

          if (!isConfirmedRecoveryUser) {
            // The restored session is a pre-existing normal session (or belongs to another user).
            // Do NOT enter password recovery! Safely clear stale recovery state and fall through to portal routing.
            clearRecoveryState();
          } else {
            final roleEnum = resolveUserAuthRole(session.user.userMetadata);
            final role =
                roleEnum == AuthRole.productionHouse ? 'production' : 'talent';
            final email = session.user.email;
            return ForgotPasswordScreen(
              selectedRole: role,
              initialEmail: email,
              isRecoveryMode: true,
              recoveryClient: widget.recoveryClient,
            );
          }
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

        // Normal app flow: if logged in and not pending verification and not in recovery, render appropriate portal
        if (session != null &&
            !isPendingEmailVerification() &&
            !isPasswordRecoveryInProgress()) {
          // 1. If profile has not been fetched yet or is currently loading for this session:
          if (_isLoadingProfile || (_authoritativeRole == null && _profileError == null)) {
            // Trigger fetch if not already in flight
            if (_fetchingUserId != session.user.id) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _fetchAuthoritativeProfile(session);
              });
            }
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

          // 2. If profile verification failed and cannot safely proceed:
          if (_profileError != null && _authoritativeRole == null) {
            return _ProfileErrorScreen(
              errorMessage: _profileError!,
              onRetry: () => _fetchAuthoritativeProfile(session, force: true),
              onSignOut: () async {
                try {
                  await Supabase.instance.client.auth.signOut();
                } catch (_) {}
                ApiClient.clearGlobalAuthToken();
                if (mounted) {
                  setState(() {
                    _resolvedUserId = null;
                    _fetchingUserId = null;
                    _authoritativeRole = null;
                    _rawBackendRole = null;
                    _profileError = null;
                  });
                }
              },
            );
          }

          // 3. Authoritative routing based on backend profile:
          switch (_authoritativeRole!) {
            case AuthRole.talent:
              return const TalentPortalScreen();
            case AuthRole.productionHouse:
              return const DashboardScreen();
            case AuthRole.unrecognized:
              return _UnrecognizedRoleScreen(
                rawRole: _rawBackendRole ?? 'Unknown',
              );
          }
        }

        // Normal app flow: if logged out (or pending verification), render RoleSelectionScreen
        return RoleSelectionScreen(autoCheckHealth: widget.autoCheckHealth);
      },
    );
  }
}

/// Controlled error screen displayed when a user logs in with an unrecognized role.
class _UnrecognizedRoleScreen extends StatelessWidget {
  final String rawRole;

  const _UnrecognizedRoleScreen({required this.rawRole});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.error,
                  size: 64,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Unrecognized Account Role',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your account has the role "$rawRole" which does not correspond to Talent or Production House access.\n\nPlease contact CineConnect support.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.gold,
                    side: const BorderSide(color: AppColors.gold),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Error screen displayed when the backend profile could not be verified
/// (e.g. during connection failure or server error).
class _ProfileErrorScreen extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  const _ProfileErrorScreen({
    required this.errorMessage,
    required this.onRetry,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  color: AppColors.error,
                  size: 64,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Profile Verification Failed',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  errorMessage,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: onSignOut,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Sign Out'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: onRetry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.gold,
                        side: const BorderSide(color: AppColors.gold),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
                    size: 56,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Email Verified Successfully!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your account ($email) has been verified. You can now return to your app window and sign in.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
