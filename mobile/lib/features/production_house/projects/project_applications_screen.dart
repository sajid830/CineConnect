import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cineconnect/app/theme.dart';
import 'package:cineconnect/features/production_house/data/models/application.dart';
import 'package:cineconnect/shared/widgets/async_body.dart';
import 'package:cineconnect/shared/widgets/empty_state.dart';
import 'package:cineconnect/features/production_house/applications/application_card.dart';
import 'package:cineconnect/features/production_house/applications/applications_provider.dart';
import 'projects_provider.dart';

class ProjectApplicationsScreen extends ConsumerStatefulWidget {
  final String projectId;

  const ProjectApplicationsScreen({super.key, required this.projectId});

  @override
  ConsumerState<ProjectApplicationsScreen> createState() =>
      _ProjectApplicationsScreenState();
}

class _ProjectApplicationsScreenState
    extends ConsumerState<ProjectApplicationsScreen> {
  Timer? _liveSyncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.invalidate(projectApplicationsProvider(widget.projectId));
      }
    });

    // Real-time asynchronous polling every 4 seconds to pick up new applications immediately
    _liveSyncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      ref.invalidate(projectApplicationsProvider(widget.projectId));
    });
  }

  @override
  void dispose() {
    _liveSyncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final applicationsAsync =
        ref.watch(projectApplicationsProvider(widget.projectId));
    final project = ref
        .watch(projectsProvider)
        .valueOrNull
        ?.where((p) => p.id == widget.projectId)
        .firstOrNull;
    final title = project?.title ?? 'Project';

    return Scaffold(
      appBar: AppBar(title: Text('Applications: $title')),
      body: AsyncBody<List<JobApplication>>(
        value: applicationsAsync,
        errorMessage: 'Could not load project applications',
        onRetry: () =>
            ref.invalidate(projectApplicationsProvider(widget.projectId)),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              message: 'No Talent users have applied to this project yet.',
              icon: Icons.movie_outlined,
            );
          }
          return RefreshIndicator(
            color: AppColors.gold,
            onRefresh: () => ref.refresh(
                projectApplicationsProvider(widget.projectId).future),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => ApplicationCard(
                application: items[index],
                opportunityTitle: title,
              ),
            ),
          );
        },
      ),
    );
  }
}
