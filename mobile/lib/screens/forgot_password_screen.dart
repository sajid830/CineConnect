import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cineconnect/app/theme.dart';
import 'package:cineconnect/core/auth/password_recovery_client.dart';
import 'package:cineconnect/core/utils/web_tab_sync.dart';
import 'auth_screen.dart';

/// Available stages in the password recovery process.
enum PasswordRecoveryStep {
  requestOtp,
  verifyOtp,
  setNewPassword,
  success,
}

class ForgotPasswordScreen extends StatefulWidget {
  final String selectedRole;
  final String? initialEmail;
  final bool isRecoveryMode;
  final PasswordRecoveryClient? recoveryClient;

  const ForgotPasswordScreen({
    super.key,
    this.selectedRole = 'user',
    this.initialEmail,
    this.isRecoveryMode = false,
    this.recoveryClient,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  late PasswordRecoveryClient _recoveryClient;
  late PasswordRecoveryStep _currentStep;

  VoidCallback? _cancelPasswordUpdatedSync;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isResending = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  Timer? _autoRedirectTimer;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    _recoveryClient = widget.recoveryClient ?? SupabasePasswordRecoveryClient();

    String? currentEmail;
    try {
      currentEmail = Supabase.instance.client.auth.currentUser?.email;
    } catch (_) {
      currentEmail = null;
    }

    final email = widget.initialEmail ?? currentEmail;
    if (email != null && email.isNotEmpty) {
      _emailController.text = email;
    }

    if (widget.isRecoveryMode) {
      _currentStep = PasswordRecoveryStep.setNewPassword;
      setPasswordRecoveryInProgress(true);
    } else {
      _currentStep = PasswordRecoveryStep.requestOtp;
    }
  }

  @override
  void dispose() {
    _autoRedirectTimer?.cancel();
    _cooldownTimer?.cancel();
    _cancelPasswordUpdatedSync?.call();
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startCooldown([int seconds = 60]) {
    _cooldownTimer?.cancel();
    if (!mounted) return;
    setState(() => _resendCooldown = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  Future<void> _handleRequestOtp() async {
    final email = _emailController.text.trim().toLowerCase();
    setState(() {
      _errorMessage = null;
      _infoMessage = null;
    });

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email address.');
      return;
    }

    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _recoveryClient.resetPasswordForEmail(email);
      if (mounted) {
        _startCooldown(60);
        setState(() {
          _currentStep = PasswordRecoveryStep.verifyOtp;
          _infoMessage =
              'If an account exists for $email, a password reset link has been sent. Open the link from your email to set a new password.';
        });
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() =>
            _errorMessage = 'An unexpected error occurred. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVerifyOtp() async {
    final email = _emailController.text.trim().toLowerCase();
    final otp = _otpController.text.trim();
    setState(() {
      _errorMessage = null;
      _infoMessage = null;
    });

    if (otp.isEmpty) {
      setState(() => _errorMessage = 'Please enter the 6-digit recovery code.');
      return;
    }

    if (otp.length != 6 || !RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(
          () => _errorMessage = 'The recovery code must be exactly 6 digits.');
      return;
    }

    setState(() => _isLoading = true);

    // CRITICAL: Set recovery guard BEFORE awaiting verifyRecoveryOtp
    // so any authentication event emitted on the stream sees the guard active.
    setPasswordRecoveryInProgress(true);

    try {
      final response = await _recoveryClient.verifyRecoveryOtp(
        email: email,
        token: otp,
      );

      final verifiedUser = response.user;
      if (verifiedUser != null) {
        await setConfirmedRecoveryUserId(verifiedUser.id);
      }

      if (mounted) {
        // Success: guard is retained, advance to password stage
        setState(() {
          _currentStep = PasswordRecoveryStep.setNewPassword;
          _infoMessage = null;
        });
      }
    } on AuthException catch (e) {
      // Failure: safely clear the guard and any identity
      await clearRecoveryState();
      if (mounted) {
        setState(() =>
            _errorMessage = 'Invalid or expired recovery code: ${e.message}');
      }
    } catch (e) {
      // Failure: safely clear the guard and any identity
      await clearRecoveryState();
      if (mounted) {
        setState(() => _errorMessage =
            'Verification failed. Please check the code and try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResendOtp() async {
    if (_resendCooldown > 0 || _isResending || _isLoading) return;
    final email = _emailController.text.trim().toLowerCase();
    setState(() {
      _isResending = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      await _recoveryClient.resetPasswordForEmail(email);
      if (mounted) {
        _startCooldown(60);
        setState(() {
          _infoMessage =
              'A fresh 6-digit recovery code has been sent to $email.';
        });
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(
            () => _errorMessage = 'Failed to resend code. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _handleUpdatePassword() async {
    if (_isLoading) return; // Prevent repeated button taps / double submission

    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    setState(() {
      _errorMessage = null;
      _infoMessage = null;
    });

    if (newPassword.isEmpty) {
      setState(() => _errorMessage = 'Please enter a new password.');
      return;
    }

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
      // 1. Update password
      await _recoveryClient.updatePassword(newPassword);

      // 2. Attempt remote session revocation, but do not fail the user if remote sign-out reports error
      try {
        await _recoveryClient.signOut();
      } catch (signOutError) {
        debugPrint(
            'Warning: remote session sign-out failed after password update: $signOutError');
      }

      // 3. Clear all recovery markers safely regardless of remote revocation status
      await clearRecoveryState();
      notifyPasswordUpdated();

      if (mounted) {
        setState(() {
          _currentStep = PasswordRecoveryStep.success;
        });
      }

      _autoRedirectTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted && _currentStep == PasswordRecoveryStep.success) {
          _navigateToSignInWithSuccess();
        }
      });
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to update password: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToSignInWithSuccess() {
    clearUrlParams();
    clearRecoveryState();
    final email = _emailController.text.trim().toLowerCase();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => AuthScreen(
          selectedRole: widget.selectedRole,
          initialIsLogin: true,
          initialEmail: email,
          successMessage:
              'Password updated successfully! Please sign in with your new password.',
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _navigateToSignIn() async {
    clearUrlParams();
    await clearRecoveryState();
    try {
      await _recoveryClient.signOut();
    } catch (_) {}

    if (mounted) {
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
    switch (_currentStep) {
      case PasswordRecoveryStep.requestOtp:
        return _buildStep1RequestView();
      case PasswordRecoveryStep.verifyOtp:
        return _buildStep2VerifyOtpView();
      case PasswordRecoveryStep.setNewPassword:
        return _buildStep3SetPasswordView();
      case PasswordRecoveryStep.success:
        return _buildStep4SuccessView();
    }
  }

  Widget _buildHeader(
      {VoidCallback? onBack, String backLabel = 'Back to Sign In'}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: onBack ?? _navigateToSignIn,
          child: Row(
            children: [
              const Icon(Icons.arrow_back,
                  color: AppColors.textPrimary, size: 20),
              const SizedBox(width: 8),
              Text(
                backLabel,
                style: const TextStyle(
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

  Widget _buildBanners() {
    return Column(
      children: [
        if (_errorMessage != null)
          Padding(
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
          ),
        if (_infoMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.gold, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _infoMessage!,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // --- Step 1: Request Recovery OTP ---
  Widget _buildStep1RequestView() {
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
          "Enter your registered email address and we'll send you a password-reset link to choose a new password.",
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        _buildBanners(),
        _buildInputField(
          controller: _emailController,
          label: 'Email Address',
          hint: 'Enter your registered email',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleRequestOtp,
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
                      'Send Recovery Code',
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

  // --- Step 2: Enter Recovery OTP ---
  Widget _buildStep2VerifyOtpView() {
    final email = _emailController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(
          onBack: () => setState(() {
            _errorMessage = null;
            _currentStep = PasswordRecoveryStep.requestOtp;
          }),
          backLabel: 'Change Email',
        ),
        const SizedBox(height: 32),
        const Text(
          'Enter Recovery Code',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textMuted,
              height: 1.5,
            ),
            children: [
              const TextSpan(text: 'We sent a password reset link to '),
              TextSpan(
                text: email,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(
                text:
                    '. Open the link from your email to reset your password, or enter a 6-digit recovery code below if one was provided.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildBanners(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recovery Code',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                letterSpacing: 8.0,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                counterText: '',
                hintText: '000000',
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  letterSpacing: 8.0,
                ),
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
                  borderSide: const BorderSide(color: AppColors.gold),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleVerifyOtp,
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
              : const Text(
                  'Verify Code',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
        ),
        const SizedBox(height: 24),
        Center(
          child: _isResending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.gold,
                  ),
                )
              : _resendCooldown > 0
                  ? Text(
                      'Resend code in ${_resendCooldown}s',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                      ),
                    )
                  : TextButton(
                      onPressed: _isLoading ? null : _handleResendOtp,
                      child: const Text(
                        "Didn't receive code? Resend",
                        style: TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  // --- Step 3: Set New Password ---
  Widget _buildStep3SetPasswordView() {
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
        _buildBanners(),
        _buildInputField(
          controller: _emailController,
          label: 'Email Address',
          hint: 'Your account email',
          keyboardType: TextInputType.emailAddress,
          readOnly: true,
        ),
        const SizedBox(height: 20),
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
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () async {
              await clearRecoveryState();
              setState(() {
                _errorMessage = null;
                _infoMessage = null;
                _currentStep = PasswordRecoveryStep.requestOtp;
              });
            },
            child: const Text(
              'Session expired? Request fresh code',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Step 4: Success View ---
  Widget _buildStep4SuccessView() {
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
          onPressed: _navigateToSignInWithSuccess,
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
