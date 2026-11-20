import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/collaboration.dart';
import '../../data/models/project.dart';
import '../collaboration/collaborations_provider.dart';
import '../projects/projects_provider.dart';

class ChatPage extends ConsumerWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(collaborationsProvider);
    final projects = ref.watch(projectsProvider).maybeWhen(
          data: (list) => list,
          orElse: () => <Project>[],
        );

    String projectName(String id) =>
        projects.where((p) => p.id == id).map((p) => p.title).firstOrNull ?? '';

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load conversations'),
            TextButton(
              onPressed: () => ref.invalidate(collaborationsProvider),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
      data: (all) {
        final chats = all
            .where((c) => c.status == CollaborationStatus.accepted)
            .toList();
        if (chats.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No conversations yet. Once talent accepts an invitation, you can message them here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: chats.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final c = chats[index];
            final t = c.talent;
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push('/chat/${c.id}'),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.gold,
                      child: Text(
                        t.initials,
                        style: const TextStyle(
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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${t.role} · ${projectName(c.projectId)}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}