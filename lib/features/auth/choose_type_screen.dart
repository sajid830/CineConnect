import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';

class ChooseTypeScreen extends StatelessWidget {
  const ChooseTypeScreen({super.key});

  void _otherPortal(BuildContext context, String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name has its own portal in the full CineConnect app'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              const Text(
                'CINECONNECT',
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Who are you?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose how you want to use CineConnect.',
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 32),
              _TypeCard(
                icon: Icons.movie_creation_outlined,
                title: 'Production House',
                subtitle: 'Post casting calls, discover talent, manage projects',
                highlighted: true,
                onTap: () => context.go('/login'),
              ),
              const SizedBox(height: 12),
              _TypeCard(
                icon: Icons.person_outline,
                title: 'Talent',
                subtitle: 'Find roles, build your portfolio, apply',
                onTap: () => _otherPortal(context, 'Talent'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool highlighted;
  final VoidCallback onTap;

  const _TypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      highlighted: highlighted,
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 32, color: AppColors.gold),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}