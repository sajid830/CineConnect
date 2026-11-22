import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cineconnect/app/theme.dart';
import 'package:cineconnect/features/production_house/data/models/project.dart';
import 'projects_provider.dart';

class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);

    return DefaultTabController(
      length: ProjectStatus.values.length,
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/projects/new'),
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.black,
          icon: const Icon(Icons.add),
          label: const Text('New project'),
        ),
        body: Column(
          children: [
            TabBar(
              tabs: [
                for (final s in ProjectStatus.values) Tab(text: s.label),
              ],
            ),
            Expanded(
              child: projectsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Could not load projects'),
                      TextButton(
                        onPressed: () => ref.invalidate(projectsProvider),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
                data: (projects) => TabBarView(
                  children: [
                    for (final s in ProjectStatus.values)
                      _ProjectList(
                        projects:
                            projects.where((p) => p.status == s).toList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectList extends StatelessWidget {
  final List<Project> projects;

  const _ProjectList({required this.projects});

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) {
      return const Center(
        child: Text(
          'No projects here yet',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: projects.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _ProjectCard(project: projects[index]),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;

  const _ProjectCard({required this.project});

  @override
  Widget build(BuildContext context) {
    final d = project.startDate;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push('/projects/${project.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              project.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              project.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Starts ${d.day}/${d.month}/${d.year}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}