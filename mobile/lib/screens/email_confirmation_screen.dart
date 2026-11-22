import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cineconnect/app/theme.dart';
import 'package:cineconnect/core/config/env_config.dart';
import 'package:cineconnect/core/utils/web_tab_sync.dart';
import 'auth_screen.dart';

class EmailConfirmationScreen extends StatefulWidget {
  final String email;
  final String selectedRole;

  const EmailConfirmationScreen({
    super.key,
    required this.email,
    required this.selectedRole,
  });

  @override
  State<EmailConfirmationScreen> createState() =>
      _EmailConfirmationScreenState();
}

class _EmailConfirmationScreenState extends State<EmailConfirmationScreen> {
  StreamSubscription<AuthState>? _authSubscription;
  VoidCallback? _cancelWebSync;
  bool _isResending = false;
  bool _isVerified = false;
  bool _isHandlingSuccess = false;

  @override
  void initState() {
    super.initState();

    // 1. Check existing session if already confirmed
    final existingSession = Supabase.instance.client.auth.currentSession;
    if (existingSession != null &&
        existingSession.user.emailConfirmedAt != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleVerificationSuccess();
      });
    }

    // 2. Listen to Supabase auth state change (fallback on same page)
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        _handleVerificationSuccess();
      }
    });

    // 3. Listen to web tab storage events triggered when Gmail confirmation link is clicked
    _cancelWebSync = listenForEmailConfirmed(() {
      _handleVerificationSuccess();
    });
  }

  Future<void> _handleVerificationSuccess() async {
    if (_isHandlingSuccess || !mounted) return;
    _isHandlingSuccess = true;

    clearConfirmedFlag();
    setPendingEmailVerification(false);

    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint('SignOut after verification error: $e');
    }

    if (!mounted) return;
    setState(() {
      _isVerified = true;
    });

    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => AuthScreen(
          selectedRole: widget.selectedRole,
          initialIsLogin: true,
          initialEmail: widget.email,
          successMessage: 'Verification successful! Please log in to continue.',
        ),
      ),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _cancelWebSync?.call();
    super.dispose();
  }

  Future<void> _resendEmail() async {
    setState(() => _isResending = true);
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
        emailRedirectTo: EnvConfig.authCallbackUrl(isRecovery: false),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Confirmation link resent! Please check your inbox.'),
            backgroundColor: AppColors.gold,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resend confirmation: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _navigateToLogin() {
    setPendingEmailVerification(false);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => AuthScreen(
          selectedRole: widget.selectedRole,
          initialIsLogin: true,
          initialEmail: widget.email,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _isVerified
            ? null
            : IconButton(
                icon:
                    const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: _navigateToLogin,
              ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _isVerified
                  ? _buildVerifiedContent()
                  : _buildUnverifiedContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerifiedContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
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
            size: 72,
            color: AppColors.gold,
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Verification Successful!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Your email has been verified. Redirecting to Login...',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.gold,
          ),
        ),
      ],
    );
  }

  Widget _buildUnverifiedContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
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
            Icons.mark_email_unread_rounded,
            size: 72,
            color: AppColors.gold,
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Verify Your Mail',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 16),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textMuted,
              height: 1.5,
            ),
            children: [
              const TextSpan(
                text: 'We sent a confirmation link to\n',
              ),
              TextSpan(
                text: widget.email,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const TextSpan(
                text:
                    '.\nClick the link in your email to verify your account — this page will automatically redirect you to Login once confirmed.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // Waiting indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.gold,
                ),
              ),
              SizedBox(width: 10),
              Text(
                'Waiting for email confirmation...',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        // Resend Confirmation Email Button
        ElevatedButton(
          onPressed: _isResending ? null : _resendEmail,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: Colors.black,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isResending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.black,
                  ),
                )
              : const Text(
                  'Resend Confirmation Email',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        const SizedBox(height: 14),
        // Back to Login Button
        OutlinedButton(
          onPressed: _navigateToLogin,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.border),
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Back to Login',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
