import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/project.dart';
import '../../shared/widgets/async_body.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/status_pill.dart';
import '../collaboration/team_section.dart';
import 'projects_provider.dart';

class ProjectDetailScreen extends ConsumerWidget {
  final String projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Project project,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete project?'),
        content: Text(
          '"${project.title}" will be removed. This cannot be undone.',
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
      await ref.read(projectsProvider.notifier).remove(project.id);
      if (context.mounted) context.pop();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete the project')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);
    final project = projectsAsync.value
        ?.where((x) => x.id == projectId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project'),
        actions: [
          if (project != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  context.push('/projects/${project.id}/edit');
                } else if (value == 'delete') {
                  _confirmDelete(context, ref, project);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
      body: AsyncBody<List<Project>>(
        value: projectsAsync,
        errorMessage: 'Could not load this project',
        onRetry: () => ref.invalidate(projectsProvider),
        data: (list) {
          final p = list.where((x) => x.id == projectId).firstOrNull;
          if (p == null) {
            return const EmptyState(
              message: 'Project not found',
              icon: Icons.search_off,
            );
          }
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      StatusPill(label: p.status.label, color: AppColors.gold),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Starts ${formatDate(p.startDate)}',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(p.description),
                  const SizedBox(height: 32),
                  TeamSection(projectId: p.id),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}