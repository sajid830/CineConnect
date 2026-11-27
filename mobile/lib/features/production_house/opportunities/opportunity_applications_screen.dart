import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cineconnect/app/theme.dart';
import 'package:cineconnect/features/production_house/data/models/application.dart';
import 'package:cineconnect/shared/widgets/async_body.dart';
import 'package:cineconnect/shared/widgets/empty_state.dart';
import 'package:cineconnect/features/production_house/applications/application_card.dart';
import 'package:cineconnect/features/production_house/applications/applications_provider.dart';
import 'opportunities_provider.dart';

class OpportunityApplicationsScreen extends ConsumerStatefulWidget {
  final String opportunityId;

  const OpportunityApplicationsScreen({super.key, required this.opportunityId});

  @override
  ConsumerState<OpportunityApplicationsScreen> createState() =>
      _OpportunityApplicationsScreenState();
}

class _OpportunityApplicationsScreenState
    extends ConsumerState<OpportunityApplicationsScreen> {
  Timer? _liveSyncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.invalidate(opportunityApplicationsProvider(widget.opportunityId));
      }
    });

    // Real-time asynchronous polling every 4 seconds to pick up new applications immediately
    _liveSyncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      ref.invalidate(opportunityApplicationsProvider(widget.opportunityId));
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
        ref.watch(opportunityApplicationsProvider(widget.opportunityId));
    final opportunity = ref
        .watch(opportunitiesProvider)
        .valueOrNull
        ?.where((o) => o.id == widget.opportunityId)
        .firstOrNull;
    final title = opportunity?.title ?? 'Job';

    return Scaffold(
      appBar: AppBar(title: Text('Applications: $title')),
      body: AsyncBody<List<JobApplication>>(
        value: applicationsAsync,
        errorMessage: 'Could not load applications',
        onRetry: () =>
            ref.invalidate(opportunityApplicationsProvider(widget.opportunityId)),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              message: 'No Talent users have applied to this job yet.',
              icon: Icons.assignment_outlined,
            );
          }
          return RefreshIndicator(
            color: AppColors.gold,
            onRefresh: () => ref.refresh(
                opportunityApplicationsProvider(widget.opportunityId).future),
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