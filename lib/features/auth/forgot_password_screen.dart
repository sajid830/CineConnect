import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repositories/password_reset_repository.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(passwordResetRepositoryProvider)
          .sendResetLink(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send the link. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _sent ? _buildSent() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter the email you signed up with and we will send you a link to set a new password.',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: const InputDecoration(labelText: 'Email Address'),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Enter your email';
              if (!value.contains('@') || !value.contains('.')) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _sending ? null : _submit,
              child: _sending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send reset link'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSent() {
    return Column(
      children: [
        const SizedBox(height: 32),
        const Icon(
          Icons.mark_email_read_outlined,
          size: 56,
          color: AppColors.gold,
        ),
        const SizedBox(height: 16),
        Text('Check your email', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'If an account exists for ${_email.text.trim()}, a reset link is on its way.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () => context.go('/login'),
          child: const Text('Back to sign in'),
        ),
      ],
    );
  }
}