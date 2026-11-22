import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cineconnect/app/theme.dart';
import 'package:cineconnect/features/production_house/data/models/collaboration.dart';
import 'collaborations_provider.dart';

class TeamSection extends ConsumerWidget {
  final String projectId;

  const TeamSection({super.key, required this.projectId});

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    Collaboration c, {
    required bool confirm,
  }) async {
    if (confirm) {
      final isInvite = c.status == CollaborationStatus.invited;
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(isInvite ? 'Cancel this invitation?' : 'Remove from team?'),
          content: Text(
            isInvite
                ? 'The invitation to ${c.talent.fullName} will be withdrawn.'
                : '${c.talent.fullName} will no longer be part of this project.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                isInvite ? 'Cancel invitation' : 'Remove',
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      await ref.read(collaborationsProvider.notifier).remove(c.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update the team')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(collaborationsProvider);

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Column(
        children: [
          const Text('Could not load the team'),
          TextButton(
            onPressed: () => ref.invalidate(collaborationsProvider),
            child: const Text('Try again'),
          ),
        ],
      ),
      data: (all) {
        final team = all.where((c) => c.projectId == projectId).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Team (${team.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (team.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text(
                  'No one has been invited yet. Open a profile in the Talent tab and tap "Invite to collaborate".',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              )
            else
              for (final c in team)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MemberTile(
                    collaboration: c,
                    onOpenProfile: () => context.push('/talent/${c.talent.id}'),
                    onSelected: (action) {
                      switch (action) {
                        case 'message':
                         context.push('/chat/${c.id}');
                        case 'cancel':
                        case 'remove':
                          _remove(context, ref, c, confirm: true);
                        case 'clear':
                          _remove(context, ref, c, confirm: false);
                      }
                    },
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _MemberTile extends StatelessWidget {
  final Collaboration collaboration;
  final VoidCallback onOpenProfile;
  final void Function(String action) onSelected;

  const _MemberTile({
    required this.collaboration,
    required this.onOpenProfile,
    required this.onSelected,
  });

  Color get _color {
    switch (collaboration.status) {
      case CollaborationStatus.invited:
        return AppColors.goldLight;
      case CollaborationStatus.accepted:
        return AppColors.gold;
      case CollaborationStatus.declined:
        return AppColors.textMuted;
    }
  }

  List<PopupMenuEntry<String>> _menu() {
    switch (collaboration.status) {
      case CollaborationStatus.invited:
        return const [
          PopupMenuItem(value: 'cancel', child: Text('Cancel invitation')),
        ];
      case CollaborationStatus.accepted:
        return const [
          PopupMenuItem(value: 'message', child: Text('Message')),
          PopupMenuItem(value: 'remove', child: Text('Remove from team')),
        ];
      case CollaborationStatus.declined:
        return const [
          PopupMenuItem(value: 'clear', child: Text('Remove from list')),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = collaboration.talent;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onOpenProfile,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.gold,
              child: Text(
                t.initials,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.fullName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    t.role,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _color),
              ),
              child: Text(
                collaboration.status.label,
                style: TextStyle(fontSize: 12, color: _color),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: onSelected,
              itemBuilder: (_) => _menu(),
            ),
          ],
        ),
      ),
    );
  }
}