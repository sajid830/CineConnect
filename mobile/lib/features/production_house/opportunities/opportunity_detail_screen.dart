import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cineconnect/app/theme.dart';
import 'package:cineconnect/core/utils/formatters.dart';
import 'package:cineconnect/features/production_house/data/models/opportunity.dart';
import 'package:cineconnect/features/production_house/data/models/project.dart';
import 'package:cineconnect/shared/widgets/async_body.dart';
import 'package:cineconnect/shared/widgets/empty_state.dart';
import 'package:cineconnect/shared/widgets/status_pill.dart';
import 'package:cineconnect/features/production_house/applications/applications_provider.dart';
import 'package:cineconnect/features/production_house/projects/projects_provider.dart';
import 'opportunities_provider.dart';

class OpportunityDetailScreen extends ConsumerWidget {
  final String opportunityId;

  const OpportunityDetailScreen({super.key, required this.opportunityId});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Opportunity item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete casting call?'),
        content: Text(
          '"${item.title}" will be removed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(opportunitiesProvider.notifier).remove(item.id);
      if (context.mounted) context.pop();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete the casting call')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opportunitiesAsync = ref.watch(opportunitiesProvider);
    final item = opportunitiesAsync.valueOrNull
        ?.where((o) => o.id == opportunityId)
        .firstOrNull;
    final projects = ref.watch(projectsProvider).valueOrNull ?? const <Project>[];
    final applicationCount = ref
        .watch(applicationsProvider)
        .valueOrNull
        ?.where((a) => a.opportunityId == opportunityId)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
        actions: [
          if (item != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  context.push('/opportunities/${item.id}/edit');
                } else if (value == 'delete') {
                  _confirmDelete(context, ref, item);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
      body: AsyncBody<List<Opportunity>>(
        value: opportunitiesAsync,
        errorMessage: 'Could not load this casting call',
        onRetry: () => ref.invalidate(opportunitiesProvider),
        data: (list) {
          final o = list.where((x) => x.id == opportunityId).firstOrNull;
          if (o == null) {
            return const EmptyState(
              message: 'Casting call not found',
              icon: Icons.search_off,
            );
          }
          final project = projects.where((p) => p.id == o.projectId).firstOrNull;
          final isOpen = o.status == OpportunityStatus.open;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    o.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      StatusPill(
                        label: o.status.label,
                        color: isOpen ? AppColors.gold : AppColors.textMuted,
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.event,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Apply by ${formatDate(o.deadline)}',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: project == null
                        ? null
                        : () => context.push('/projects/${project.id}'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.movie_creation_outlined,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              project?.title ?? 'Unknown project',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          if (project != null)
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.textMuted,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (o.experience != null && o.experience!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.work_history_outlined, size: 16, color: AppColors.gold),
                        const SizedBox(width: 8),
                        Text(
                          'Required Experience: ${o.experience}',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.gold),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Requirements',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(o.requirements),
                  const SizedBox(height: 32),
                  if (o.status == OpportunityStatus.draft)
                    OutlinedButton(
                      onPressed: () => ref
                          .read(opportunitiesProvider.notifier)
                          .setStatus(o.id, OpportunityStatus.open),
                      child: const Text('Publish'),
                    ),
                  if (o.status == OpportunityStatus.open)
                    OutlinedButton(
                      onPressed: () => ref
                          .read(opportunitiesProvider.notifier)
                          .setStatus(o.id, OpportunityStatus.closed),
                      child: const Text('Close applications'),
                    ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () =>
                        context.push('/opportunities/${o.id}/applications'),
                    child: Text(
                      applicationCount == null
                          ? 'View applications'
                          : 'View applications ($applicationCount)',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}