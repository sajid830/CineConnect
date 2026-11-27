import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cineconnect/app/theme.dart';
import 'package:cineconnect/core/utils/formatters.dart';
import 'package:cineconnect/features/production_house/data/models/opportunity.dart';
import 'package:cineconnect/features/production_house/data/models/project.dart';
import 'package:cineconnect/features/production_house/opportunities/opportunities_provider.dart';
import 'package:cineconnect/features/production_house/opportunities/opportunity_applications_screen.dart';
import 'package:cineconnect/features/production_house/projects/projects_provider.dart';
import 'package:cineconnect/features/production_house/projects/project_applications_screen.dart';
import 'package:cineconnect/shared/widgets/app_card.dart';
import 'package:cineconnect/shared/widgets/async_body.dart';
import 'package:cineconnect/shared/widgets/empty_state.dart';

class ApplicationsPage extends ConsumerStatefulWidget {
  const ApplicationsPage({super.key});

  @override
  ConsumerState<ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends ConsumerState<ApplicationsPage> {
  int _selectedTab = 0; // 0: Projects, 1: Jobs
  Timer? _liveSyncTimer;

  @override
  void initState() {
    super.initState();
    // Immediate asynchronous refresh upon entering applications view
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.invalidate(projectsProvider);
        ref.invalidate(opportunitiesProvider);
      }
    });

    // Real-time asynchronous polling every 4 seconds to pick up new applications/releases
    _liveSyncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (_selectedTab == 0) {
        ref.invalidate(projectsProvider);
      } else {
        ref.invalidate(opportunitiesProvider);
      }
    });
  }

  @override
  void dispose() {
    _liveSyncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Section Selector: Projects vs Jobs
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedTab = 0),
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedTab == 0
                            ? AppColors.gold.withValues(alpha: 0.18)
                            : Colors.transparent,
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
                        border: _selectedTab == 0
                            ? Border.all(color: AppColors.gold, width: 1.2)
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.movie_creation_outlined,
                            size: 18,
                            color: _selectedTab == 0 ? AppColors.gold : AppColors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Projects',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: _selectedTab == 0 ? FontWeight.bold : FontWeight.normal,
                              color: _selectedTab == 0 ? AppColors.gold : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedTab = 1),
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(11)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedTab == 1
                            ? AppColors.gold.withValues(alpha: 0.18)
                            : Colors.transparent,
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(11)),
                        border: _selectedTab == 1
                            ? Border.all(color: AppColors.gold, width: 1.2)
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.work_outline,
                            size: 18,
                            color: _selectedTab == 1 ? AppColors.gold : AppColors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Jobs',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: _selectedTab == 1 ? FontWeight.bold : FontWeight.normal,
                              color: _selectedTab == 1 ? AppColors.gold : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Content Area: Projects applications vs Jobs applications
        Expanded(
          child: _selectedTab == 0 ? const _ProjectsApplicationsTab() : const _JobsApplicationsTab(),
        ),
      ],
    );
  }
}

class _ProjectsApplicationsTab extends ConsumerWidget {
  const _ProjectsApplicationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);

    return AsyncBody<List<Project>>(
      value: projectsAsync,
      errorMessage: 'Could not load projects',
      onRetry: () => ref.invalidate(projectsProvider),
      data: (projects) {
        if (projects.isEmpty) {
          return const EmptyState(
            message: 'No projects published yet.\nCreate a project to start receiving applications.',
            icon: Icons.movie_outlined,
          );
        }

        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: () => ref.refresh(projectsProvider.future),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: projects.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final project = projects[index];
              return AppCard(
                padding: const EdgeInsets.all(16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProjectApplicationsScreen(projectId: project.id),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                project.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (project.projectType != null && project.projectType!.isNotEmpty) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.gold.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        project.projectType!,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.gold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Text(
                                      project.status.label,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Applicant Count Chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.people_outline, size: 14, color: AppColors.gold),
                              const SizedBox(width: 4),
                              Text(
                                '${project.applicationsCount} Applicants',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.gold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (project.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        project.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Divider(color: AppColors.border.withValues(alpha: 0.5), height: 1),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 5),
                        Text(
                          'Starts: ${formatDate(project.startDate)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                        if (project.budget != null && project.budget!.isNotEmpty) ...[
                          const Spacer(),
                          const Icon(Icons.currency_rupee, size: 13, color: AppColors.gold),
                          Text(
                            project.budget!,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.gold),
                          ),
                        ],
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.gold),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _JobsApplicationsTab extends ConsumerWidget {
  const _JobsApplicationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opportunitiesAsync = ref.watch(opportunitiesProvider);

    return AsyncBody<List<Opportunity>>(
      value: opportunitiesAsync,
      errorMessage: 'Could not load jobs',
      onRetry: () => ref.invalidate(opportunitiesProvider),
      data: (jobs) {
        if (jobs.isEmpty) {
          return const EmptyState(
            message: 'No jobs published yet.\nCreate a new job to start receiving applications.',
            icon: Icons.work_outline,
          );
        }

        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: () => ref.refresh(opportunitiesProvider.future),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: jobs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final job = jobs[index];
              final roleText = job.title.isNotEmpty ? job.title : 'Crew Role';
              final purposeText = job.purpose ?? 'Production';

              return AppCard(
                padding: const EdgeInsets.all(16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OpportunityApplicationsScreen(opportunityId: job.id),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                roleText,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.gold.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      purposeText,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.gold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Text(
                                      '${job.requiredMembers} needed',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Applicant Count Chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.people_outline, size: 14, color: AppColors.gold),
                              const SizedBox(width: 4),
                              Text(
                                '${job.applicationsCount} Applicants',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.gold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (job.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        job.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Divider(color: AppColors.border.withValues(alpha: 0.5), height: 1),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (job.workStartDate != null) ...[
                          const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.textMuted),
                          const SizedBox(width: 5),
                          Text(
                            'Starts: ${formatDate(job.workStartDate!)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ] else ...[
                          const Icon(Icons.schedule, size: 13, color: AppColors.textMuted),
                          const SizedBox(width: 5),
                          const Text(
                            'Immediate Start',
                            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                        const Spacer(),
                        const Text(
                          'View Applicants',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.gold),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.gold),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
