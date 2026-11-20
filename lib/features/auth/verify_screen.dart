import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/production_house_user.dart';
import '../../data/repositories/auth_repository.dart';

class VerifyScreen extends ConsumerStatefulWidget {
  final String email;

  const VerifyScreen({super.key, required this.email});

  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<VerifyScreen> {
  static const _cooldownSeconds = 30;

  StreamSubscription<ProductionHouseUser>? _subscription;
  Timer? _timer;
  int _secondsLeft = _cooldownSeconds;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _subscription = ref
        .read(authRepositoryProvider)
        .watchEmailConfirmation(email: widget.email)
        .listen(_onConfirmed);
    _startCooldown();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  void _onConfirmed(ProductionHouseUser user) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Email confirmed. Welcome to CineConnect!')),
    );
    context.go('/dashboard');
  }

  void _startCooldown() {
    _timer?.cancel();
    _secondsLeft = _cooldownSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .resendConfirmationEmail(email: widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Confirmation email sent')),
      );
      setState(_startCooldown);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send the email. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.email.isEmpty ? 'your email address' : widget.email;
    final canResend = _secondsLeft == 0 && !_resending;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.goldGlow,
                    border: Border.all(color: AppColors.gold, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 40,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Confirm your email address',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(text: 'We sent a confirmation link to '),
                      TextSpan(
                        text: email,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const TextSpan(
                        text:
                            '. Open the email and tap Confirm. You will be signed in automatically.',
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Waiting for confirmation...',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: canResend ? _resend : null,
                    child: Text(
                      _secondsLeft > 0
                          ? 'Resend email in ${_secondsLeft}s'
                          : 'Resend email',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go('/signup'),
                  child: const Text('Use a different email'),
                ),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Back to sign in'),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Can't find it? Check your spam folder.",
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}