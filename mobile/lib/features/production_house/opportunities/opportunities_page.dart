import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cineconnect/app/theme.dart';
import 'package:cineconnect/core/utils/formatters.dart';
import 'package:cineconnect/features/production_house/data/models/opportunity.dart';
import 'package:cineconnect/features/production_house/data/models/project.dart';
import 'package:cineconnect/shared/widgets/app_card.dart';
import 'package:cineconnect/shared/widgets/async_body.dart';
import 'package:cineconnect/shared/widgets/empty_state.dart';
import 'package:cineconnect/shared/widgets/status_pill.dart';
import 'package:cineconnect/features/production_house/projects/projects_provider.dart';
import 'opportunities_provider.dart';

class OpportunitiesPage extends ConsumerWidget {
  const OpportunitiesPage({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Opportunity item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete job?'),
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job deleted')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete the job')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opportunitiesAsync = ref.watch(opportunitiesProvider);
    final projects = ref.watch(projectsProvider).maybeWhen(
          data: (list) => list,
          orElse: () => <Project>[],
        );

    String? projectName(String? id) {
      if (id == null || id.isEmpty) return null;
      return projects.where((p) => p.id == id).map((p) => p.title).firstOrNull;
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/opportunities/new'),
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.black,
        icon: const Icon(Icons.add),
        label: const Text('Create New Job'),
      ),
      body: AsyncBody<List<Opportunity>>(
        value: opportunitiesAsync,
        errorMessage: 'Could not load jobs',
        onRetry: () => ref.invalidate(opportunitiesProvider),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              message: 'No jobs published yet',
              icon: Icons.work_outline,
              actionLabel: 'Create New Job',
              onAction: () => context.push('/opportunities/new'),
            );
          }
          return RefreshIndicator(
            color: AppColors.gold,
            onRefresh: () => ref.refresh(opportunitiesProvider.future),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                return _OpportunityCard(
                  opportunity: item,
                  projectName: projectName(item.projectId),
                  onStatusChange: (status) => ref
                      .read(opportunitiesProvider.notifier)
                      .setStatus(item.id, status),
                  onEdit: () => context.push('/opportunities/${item.id}/edit'),
                  onDelete: () => _confirmDelete(context, ref, item),
                  onOpen: () => context.push('/opportunities/${item.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  final Opportunity opportunity;
  final String? projectName;
  final void Function(OpportunityStatus) onStatusChange;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  const _OpportunityCard({
    required this.opportunity,
    this.projectName,
    required this.onStatusChange,
    required this.onEdit,
    required this.onDelete,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final o = opportunity;
    final isOpen = o.status == OpportunityStatus.open;

    return AppCard(
      onTap: onOpen,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.gold,
                      ),
                    ),
                    if (o.purpose != null && o.purpose!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Purpose: ${o.purpose}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              StatusPill(
                label: o.status.label,
                color: isOpen ? AppColors.gold : AppColors.textMuted,
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (projectName != null && projectName!.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.movie_creation_outlined,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          projectName!,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                if (o.requirements.isNotEmpty) ...[
                  Text(
                    o.requirements,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                ],
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_outline, size: 14, color: AppColors.gold),
                        const SizedBox(width: 4),
                        Text(
                          '${o.requiredMembers} ${o.requiredMembers == 1 ? 'member' : 'members'} required',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    if (o.workStartDate != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_month, size: 14, color: AppColors.gold),
                          const SizedBox(width: 4),
                          Text(
                            'Starts ${formatDate(o.workStartDate!)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    if (o.experience != null && o.experience!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.work_history_outlined, size: 14, color: AppColors.gold),
                          const SizedBox(width: 4),
                          Text(
                            'Exp: ${o.experience}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    if (o.applicationsCount > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.assignment_ind_outlined, size: 14, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(
                            '${o.applicationsCount} applicants',
                            style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.event, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      'Deadline: ${formatDate(o.deadline)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                    const Spacer(),
                    if (o.status == OpportunityStatus.draft)
                      TextButton(
                        onPressed: () => onStatusChange(OpportunityStatus.open),
                        child: const Text('Publish'),
                      ),
                    if (o.status == OpportunityStatus.open)
                      TextButton(
                        onPressed: () => onStatusChange(OpportunityStatus.closed),
                        child: const Text('Close'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}