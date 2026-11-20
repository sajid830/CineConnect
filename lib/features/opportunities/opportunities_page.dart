import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/opportunity.dart';
import '../../data/models/project.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/async_body.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/status_pill.dart';
import '../projects/projects_provider.dart';
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Casting call deleted')),
        );
      }
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
    final projects = ref.watch(projectsProvider).maybeWhen(
          data: (list) => list,
          orElse: () => <Project>[],
        );

    String projectName(String id) {
      return projects.where((p) => p.id == id).map((p) => p.title).firstOrNull ??
          'Unknown project';
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/opportunities/new'),
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.black,
        icon: const Icon(Icons.add),
        label: const Text('New casting call'),
      ),
      body: AsyncBody<List<Opportunity>>(
        value: opportunitiesAsync,
        errorMessage: 'Could not load casting calls',
        onRetry: () => ref.invalidate(opportunitiesProvider),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              message: 'No casting calls yet',
              icon: Icons.campaign_outlined,
              actionLabel: 'Create a casting call',
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
              separatorBuilder: (_, _) => const SizedBox(height: 12),
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
  final String projectName;
  final void Function(OpportunityStatus) onStatusChange;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  const _OpportunityCard({
    required this.opportunity,
    required this.projectName,
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
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  o.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gold,
                  ),
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
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        projectName,
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(o.requirements, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.event, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      'Apply by ${formatDate(o.deadline)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
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