import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cineconnect/app/theme.dart';
import 'package:cineconnect/core/utils/web_tab_sync.dart';
import 'package:cineconnect/features/home/presentation/screens/home_screen.dart';
import 'email_confirmation_screen.dart';
import 'forgot_password_screen.dart';

class AuthScreen extends StatefulWidget {
  final String selectedRole;
  final bool initialIsLogin;
  final String? initialEmail;
  final String? successMessage;

  const AuthScreen({
    super.key,
    required this.selectedRole,
    this.initialIsLogin = true,
    this.initialEmail,
    this.successMessage,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool isLogin;
  bool isLoading = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    isLogin = widget.initialIsLogin;
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    setState(() => isLoading = true);
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    if (isLogin) {
      if (email.isEmpty || password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter both email and password.'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => isLoading = false);
        return;
      }
    } else {
      // Talent / User Sign Up validation
      final name = _nameController.text.trim();
      final username = _usernameController.text.trim().toLowerCase();
      final mobile = _mobileController.text.trim();
      final confirmPassword = _confirmPasswordController.text.trim();

      // 1. All 6 fields required
      if (name.isEmpty ||
          username.isEmpty ||
          email.isEmpty ||
          mobile.isEmpty ||
          password.isEmpty ||
          confirmPassword.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill in all fields.'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => isLoading = false);
        return;
      }

      // 2. Username cannot contain spaces
      if (username.contains(' ')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Username cannot contain spaces.'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => isLoading = false);
        return;
      }

      // 3. Email format validation
      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
      if (!emailRegex.hasMatch(email)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid email address.'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => isLoading = false);
        return;
      }

      // 4. Mobile number validation (at least 10 digits)
      final digitsOnly = mobile.replaceAll(RegExp(r'\D'), '');
      if (digitsOnly.length < 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Please enter a valid mobile number (at least 10 digits).'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => isLoading = false);
        return;
      }

      // 5. Password length check
      if (password.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password must be at least 6 characters.'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => isLoading = false);
        return;
      }

      // 6. Confirm password match
      if (password != confirmPassword) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passwords do not match.'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => isLoading = false);
        return;
      }
    }

    try {
      if (isLogin) {
        setPendingEmailVerification(false);
        // Sign In
        final response = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        if (response.session != null && mounted) {
          final role = (response.user?.userMetadata?['role'] as String?) ??
              widget.selectedRole;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => HomeScreen(roleType: role, userType: role),
            ),
            (route) => false,
          );
        }
      } else {
        // Sign Up (Talent)
        final Map<String, dynamic> metadata = {
          'role': widget.selectedRole,
          'full_name': _nameController.text.trim(),
          'username': _usernameController.text.trim().toLowerCase(),
          'mobile_number': _mobileController.text.trim(),
        };

        await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          data: metadata,
          emailRedirectTo:
              kIsWeb ? '${Uri.base.origin}/?confirmed=true' : null,
        );

        setPendingEmailVerification(true);

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EmailConfirmationScreen(
                email: email,
                selectedRole: widget.selectedRole,
              ),
            ),
          );
        }
      }
    } on AuthException catch (e) {
      String message = e.message;
      final lowerMsg = message.toLowerCase();
      if (lowerMsg.contains('email not confirmed') ||
          lowerMsg.contains('not confirmed') ||
          lowerMsg.contains('unconfirmed')) {
        message =
            'Your email has not been confirmed yet. Please check your inbox and click the confirmation link sent to $email.';
      } else if (lowerMsg.contains('invalid login credentials') ||
          lowerMsg.contains('invalid credentials')) {
        message = 'Invalid email or password. Please verify and try again.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message,
                style: const TextStyle(color: AppColors.textPrimary)),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: $e',
                style: const TextStyle(color: AppColors.textPrimary)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _buildAuthView(),
    );
  }

  /// Unified Auth View for Sign In, Talent Sign Up, and Production House Sign Up
  Widget _buildAuthView() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Row(
                        children: [
                          Icon(Icons.arrow_back,
                              color: AppColors.textPrimary, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Choose Type',
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
                ),
                const SizedBox(height: 32),

                // Segmented Toggle
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => isLogin = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color:
                                  isLogin ? AppColors.gold : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Sign In',
                              style: TextStyle(
                                color: isLogin
                                    ? Colors.black
                                    : AppColors.textMuted,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => isLogin = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !isLogin
                                  ? AppColors.gold
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Sign Up',
                              style: TextStyle(
                                color: !isLogin
                                    ? Colors.black
                                    : AppColors.textMuted,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Title & Subtitle (Left-aligned)
                Text(
                  isLogin ? 'Welcome Back' : 'Create Talent Account',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isLogin
                      ? 'Enter your credentials to access your CineConnect dashboard.'
                      : 'Join the premier cinema and entertainment network.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),

                // Success Banner (e.g. after email verification redirect)
                if (widget.successMessage != null && isLogin) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.gold, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.gold, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.successMessage!,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Form Fields
                if (!isLogin) ...[
                  // 1. Full Name
                  _buildInputField(
                    controller: _nameController,
                    label: 'Full Name',
                    hint: 'Full Name',
                  ),
                  const SizedBox(height: 20),

                  // 2. Username
                  _buildInputField(
                    controller: _usernameController,
                    label: 'Username',
                    hint: 'Username',
                  ),
                  const SizedBox(height: 20),

                  // 3. Email Address
                  _buildInputField(
                    controller: _emailController,
                    label: 'Email Address',
                    hint: 'Email Address',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),

                  // 4. Mobile Number
                  _buildInputField(
                    controller: _mobileController,
                    label: 'Mobile Number',
                    hint: 'Mobile Number',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 20),

                  // 5. Password
                  _buildInputField(
                    controller: _passwordController,
                    label: 'Password',
                    hint: 'Password',
                    isPassword: true,
                    obscureText: _obscurePassword,
                    onToggleVisibility: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  const SizedBox(height: 20),

                  // 6. Confirm Password
                  _buildInputField(
                    controller: _confirmPasswordController,
                    label: 'Confirm Password',
                    hint: 'Confirm Password',
                    isPassword: true,
                    obscureText: _obscureConfirmPassword,
                    onToggleVisibility: () => setState(() =>
                        _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                  const SizedBox(height: 32),
                ] else ...[
                  // Sign In Fields
                  _buildInputField(
                    controller: _emailController,
                    label: 'Email Address',
                    hint: 'Email Address',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),

                  _buildInputField(
                    controller: _passwordController,
                    label: 'Password',
                    hint: 'Password',
                    isPassword: true,
                    obscureText: _obscurePassword,
                    showForgotPassword: true,
                    onToggleVisibility: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    onForgotPasswordTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ForgotPasswordScreen(
                            selectedRole: widget.selectedRole,
                            initialEmail: _emailController.text.trim(),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                ],

                // Submit Button
                ElevatedButton(
                  onPressed: isLoading ? null : _handleAuth,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.gold,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.black,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLogin ? 'Sign In' : 'Create Account',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded,
                                color: Colors.black, size: 20),
                          ],
                        ),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isLogin
                          ? "Don't have an account? "
                          : "Already have an account? ",
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => isLogin = !isLogin),
                      child: Text(
                        isLogin ? 'Sign Up' : 'Sign In',
                        style: const TextStyle(
                            color: AppColors.goldLight,
                            fontWeight: FontWeight.bold),
                      ),
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool isPassword = false,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    bool showForgotPassword = false,
    VoidCallback? onToggleVisibility,
    VoidCallback? onForgotPasswordTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            if (showForgotPassword)
              GestureDetector(
                onTap: onForgotPasswordTap,
                child: const MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: AppColors.goldLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          obscureText: isPassword && obscureText,
          keyboardType: keyboardType,
          cursorColor: AppColors.gold,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
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
              borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
            suffixIcon: isPassword
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
