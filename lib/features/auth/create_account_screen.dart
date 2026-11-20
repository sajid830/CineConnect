import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repositories/auth_repository.dart';
import '../../shared/widgets/gold_button.dart';

class CreateAccountScreen extends ConsumerStatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  ConsumerState<CreateAccountScreen> createState() =>
      _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hidePassword = true;
  bool _hideConfirm = true;
  bool _loading = false;
  final Set<String> _takenUsernames = {};

  @override
  void dispose() {
    for (final c in [_name, _username, _email, _phone, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final username = _username.text.trim().toLowerCase();
    final email = _email.text.trim();
    try {
      await ref.read(authRepositoryProvider).signUp(
            companyName: _name.text.trim(),
            username: username,
            email: email,
            phone: _phone.text.trim(),
            password: _password.text,
          );
      if (mounted) {
        context.go('/verify?email=${Uri.encodeQueryComponent(email)}');
      }
    } on UsernameTakenException {
      _takenUsernames.add(username);
      if (mounted) _formKey.currentState!.validate();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not create your account. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    Iterable<String>? autofill,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            inputFormatters: formatters,
            autofillHints: autofill,
            textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
            onFieldSubmitted: isLast ? (_) => _submit() : null,
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, color: AppColors.gold),
              suffixIcon: onToggleObscure == null
                  ? null
                  : IconButton(
                      tooltip: obscure ? 'Show password' : 'Hide password',
                      icon: Icon(
                        obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textMuted,
                      ),
                      onPressed: onToggleObscure,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Soft gold glow behind the header
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.75),
                  radius: 0.9,
                  colors: [AppColors.goldGlow, Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go('/login'),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Center(
                            child: Text(
                              'Create Your Profile',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Center(
                            child: Text(
                              'Register your studio, post casting calls, and discover film talent.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _field(
                            label: 'Studio Name',
                            controller: _name,
                            hint: 'e.g. Sunrise Films',
                            icon: Icons.badge_outlined,
                            autofill: const [AutofillHints.organizationName],
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Enter your studio name'
                                : null,
                          ),
                          _field(
                            label: 'Username',
                            controller: _username,
                            hint: 'e.g. sunrise_films',
                            icon: Icons.alternate_email,
                            formatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[a-zA-Z0-9_]'),
                              ),
                            ],
                            autofill: const [AutofillHints.newUsername],
                            validator: (v) {
                              final t = (v ?? '').trim().toLowerCase();
                              if (t.length < 3 || t.length > 20) {
                                return 'Use 3 to 20 letters, numbers or _';
                              }
                              if (_takenUsernames.contains(t)) {
                                return 'That username is already taken';
                              }
                              return null;
                            },
                          ),
                          _field(
                            label: 'Email Address',
                            controller: _email,
                            hint: 'studio@example.com',
                            icon: Icons.mail_outline,
                            keyboardType: TextInputType.emailAddress,
                            autofill: const [AutofillHints.email],
                            validator: (v) {
                              final t = v?.trim() ?? '';
                              if (t.isEmpty) return 'Enter your email';
                              if (!t.contains('@') || !t.contains('.')) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          _field(
                            label: 'Mobile Number',
                            controller: _phone,
                            hint: '+91 98765 43210',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            formatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9+ ()-]'),
                              ),
                            ],
                            autofill: const [AutofillHints.telephoneNumber],
                            validator: (v) {
                              final digits =
                                  (v ?? '').replaceAll(RegExp(r'\D'), '');
                              if (digits.length < 8 || digits.length > 15) {
                                return 'Enter a valid mobile number';
                              }
                              return null;
                            },
                          ),
                          _field(
                            label: 'Password',
                            controller: _password,
                            hint: 'At least 8 characters',
                            icon: Icons.lock_outline,
                            obscure: _hidePassword,
                            onToggleObscure: () =>
                                setState(() => _hidePassword = !_hidePassword),
                            autofill: const [AutofillHints.newPassword],
                            validator: (v) => (v == null || v.length < 8)
                                ? 'Use at least 8 characters'
                                : null,
                          ),
                          _field(
                            label: 'Confirm Password',
                            controller: _confirm,
                            hint: 'Re-enter your password',
                            icon: Icons.lock_reset,
                            obscure: _hideConfirm,
                            onToggleObscure: () =>
                                setState(() => _hideConfirm = !_hideConfirm),
                            isLast: true,
                            validator: (v) => v != _password.text
                                ? 'Passwords do not match'
                                : null,
                          ),
                          const SizedBox(height: 6),
                          GoldButton(
                            label: 'Create Account',
                            loading: _loading,
                            onPressed: _loading ? null : _submit,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Already have an account?',
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                              TextButton(
                                onPressed: () => context.go('/login'),
                                child: const Text(
                                  'Log In',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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