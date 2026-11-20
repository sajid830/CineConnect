import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cineconnect/app/theme.dart';
import 'package:cineconnect/core/utils/web_tab_sync.dart';
import 'auth_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String selectedRole;
  final String? initialEmail;
  final bool isRecoveryMode;

  const ForgotPasswordScreen({
    super.key,
    this.selectedRole = 'user',
    this.initialEmail,
    this.isRecoveryMode = false,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  VoidCallback? _cancelPasswordUpdatedSync;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _resetLinkSent = false;
  bool _passwordUpdated = false;
  bool _isNavigatingToSignIn = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final email =
        widget.initialEmail ?? Supabase.instance.client.auth.currentUser?.email;
    if (email != null && email.isNotEmpty) {
      _emailController.text = email;
    }
  }

  @override
  void dispose() {
    _cancelPasswordUpdatedSync?.call();
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startListeningForPasswordUpdate() {
    _cancelPasswordUpdatedSync?.call();
    _cancelPasswordUpdatedSync = listenForPasswordUpdated(() {
      _handlePasswordUpdatedSuccess();
    });
  }

  Future<void> _handlePasswordUpdatedSuccess() async {
    if (_isNavigatingToSignIn || !mounted) return;
    _isNavigatingToSignIn = true;

    clearPasswordUpdatedFlag();
    clearUrlParams();

    if (!mounted) return;
    setState(() {
      _passwordUpdated = true;
    });

    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => AuthScreen(
          selectedRole: widget.selectedRole,
          initialIsLogin: true,
          initialEmail: _emailController.text.trim().toLowerCase(),
          successMessage:
              'Password updated successfully! Please sign in with your new password.',
        ),
      ),
      (route) => false,
    );
  }

  void _navigateToSignIn() {
    clearUrlParams();
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => AuthScreen(
            selectedRole: widget.selectedRole,
            initialIsLogin: true,
            initialEmail: _emailController.text.trim().toLowerCase(),
          ),
        ),
        (route) => false,
      );
    }
  }

  Future<void> _handleSendResetLink() async {
    final email = _emailController.text.trim().toLowerCase();
    setState(() => _errorMessage = null);

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email address.');
      return;
    }

    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }

    clearPasswordUpdatedFlag();
    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb ? '${Uri.base.origin}/?recovery=true' : null,
      );

      // ONLY set _resetLinkSent = true when call succeeds without error
      if (mounted) {
        setState(() {
          _resetLinkSent = true;
        });
        _startListeningForPasswordUpdate();
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'An unexpected error occurred: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleUpdatePassword() async {
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    setState(() => _errorMessage = null);

    if (newPassword.length < 6) {
      setState(
          () => _errorMessage = 'New password must be at least 6 characters.');
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      await Supabase.instance.client.auth.signOut();
      notifyPasswordUpdated();

      if (mounted) {
        setState(() {
          _passwordUpdated = true;
        });
      }

      tryCloseTab();

      // If Chrome blocks closing the tab, auto-redirect after 1.5 seconds
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        clearUrlParams();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => AuthScreen(
              selectedRole: widget.selectedRole,
              initialIsLogin: true,
              initialEmail: _emailController.text.trim().toLowerCase(),
              successMessage:
                  'Password updated successfully! Please sign in with your new password.',
            ),
          ),
          (route) => false,
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to update password: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _buildBody(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_passwordUpdated) {
      return _buildSuccessView();
    }

    if (widget.isRecoveryMode) {
      return _buildStep2View();
    }

    if (_resetLinkSent) {
      return _buildResetLinkSentCard();
    }

    return _buildStep1View();
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: _navigateToSignIn,
          child: const Row(
            children: [
              Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 20),
              SizedBox(width: 8),
              Text(
                'Back to Sign In',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const Text(
          'CINECONNECT',
          style: TextStyle(
            color: AppColors.gold,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    if (_errorMessage == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1View() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        const SizedBox(height: 32),
        const Text(
          'Forgot Password',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Enter your email address and we'll send you a link to reset your password.",
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        _buildErrorBanner(),
        _buildInputField(
          controller: _emailController,
          label: 'Email Address',
          hint: 'Enter your registered email',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSendResetLink,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: AppColors.gold,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.black,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Send Reset Link',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded,
                        color: Colors.black, size: 20),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildResetLinkSentCard() {
    final email = _emailController.text.trim();

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
            Icons.mark_email_read_rounded,
            size: 64,
            color: AppColors.gold,
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Check Your Email',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textMuted,
              height: 1.5,
            ),
            children: [
              const TextSpan(text: 'Reset link sent to '),
              TextSpan(
                text: email,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const TextSpan(
                text:
                    '.\nOpen the link in your email to set your new password — this page will update automatically once your password is changed.',
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
                'Waiting for password update...',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),
        ElevatedButton(
          onPressed: _navigateToSignIn,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: Colors.black,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Back to Sign In',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2View() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        const SizedBox(height: 32),
        const Text(
          'Reset Password',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Create a new secure password for your CineConnect account.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        _buildErrorBanner(),
        // 1. Email Address (read-only)
        _buildInputField(
          controller: _emailController,
          label: 'Email Address',
          hint: 'Your account email',
          keyboardType: TextInputType.emailAddress,
          readOnly: true,
        ),
        const SizedBox(height: 20),
        // 2. New Password
        _buildInputField(
          controller: _newPasswordController,
          label: 'New Password',
          hint: 'At least 6 characters',
          isPassword: true,
          obscureText: _obscureNewPassword,
          onToggleVisibility: () =>
              setState(() => _obscureNewPassword = !_obscureNewPassword),
        ),
        const SizedBox(height: 20),
        // 3. Confirm Password
        _buildInputField(
          controller: _confirmPasswordController,
          label: 'Confirm Password',
          hint: 'Re-enter your new password',
          isPassword: true,
          obscureText: _obscureConfirmPassword,
          onToggleVisibility: () => setState(
              () => _obscureConfirmPassword = !_obscureConfirmPassword),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleUpdatePassword,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: AppColors.gold,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.black,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Update Password',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded,
                        color: Colors.black, size: 20),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
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
            size: 64,
            color: AppColors.gold,
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Password updated successfully',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Redirecting you to Sign In...',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 36),
        ElevatedButton(
          onPressed: () {
            clearUrlParams();
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => AuthScreen(
                  selectedRole: widget.selectedRole,
                  initialIsLogin: true,
                  initialEmail: _emailController.text.trim().toLowerCase(),
                  successMessage:
                      'Password updated successfully! Please sign in with your new password.',
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
                'Back to Sign In',
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
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool isPassword = false,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    VoidCallback? onToggleVisibility,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          readOnly: readOnly,
          obscureText: isPassword && obscureText,
          keyboardType: keyboardType,
          style: TextStyle(
            color: readOnly ? AppColors.textMuted : AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: readOnly ? AppColors.border : AppColors.gold,
              ),
            ),
            suffixIcon: readOnly
                ? const Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.textMuted,
                    size: 20,
                  )
                : isPassword
                    ? IconButton(
                        icon: Icon(
                          obscureText
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                        onPressed: onToggleVisibility,
                      )
                    : null,
          ),
        ),
      ],
    );
  }
}
