import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/talent.dart';
import '../../shared/widgets/async_body.dart';
import '../../shared/widgets/initials_avatar.dart';
import '../collaboration/invite_button.dart';
import 'portfolio_section.dart';
import 'talent_provider.dart';

class TalentDetailScreen extends ConsumerWidget {
  final String talentId;

  const TalentDetailScreen({super.key, required this.talentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final talentAsync = ref.watch(talentDetailProvider(talentId));

    return Scaffold(
      appBar: AppBar(title: const Text('Talent profile')),
      body: AsyncBody<Talent>(
        value: talentAsync,
        errorMessage: 'Could not load this profile',
        onRetry: () => ref.invalidate(talentDetailProvider(talentId)),
        data: (t) => _ProfileView(talent: t),
      ),
    );
  }
}

class _ProfileView extends StatelessWidget {
  final Talent talent;

  const _ProfileView({required this.talent});

  @override
  Widget build(BuildContext context) {
    final t = talent;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: InitialsAvatar(initials: t.initials, radius: 46)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    t.fullName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (t.isVerified) ...const [
                  SizedBox(width: 8),
                  Icon(Icons.verified, color: AppColors.gold),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              t.role,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: AppColors.gold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  t.location,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(width: 20),
                const Icon(
                  Icons.work_outline,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  '${t.experienceYears} yrs experience',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Text(
              'About',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(t.bio),
            if (t.skills.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Skills',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final s in t.skills) Chip(label: Text(s))],
              ),
            ],
            const SizedBox(height: 28),
            PortfolioSection(talentId: t.id),
            const SizedBox(height: 20),
            InviteButton(talent: t),
          ],
        ),
      ),
    );
  }
}