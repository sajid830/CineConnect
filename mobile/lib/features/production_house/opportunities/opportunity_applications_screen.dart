import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cineconnect/app/theme.dart';
import 'package:cineconnect/features/production_house/data/models/application.dart';
import 'package:cineconnect/shared/widgets/async_body.dart';
import 'package:cineconnect/shared/widgets/empty_state.dart';
import 'package:cineconnect/features/production_house/applications/application_card.dart';
import 'package:cineconnect/features/production_house/applications/applications_provider.dart';
import 'opportunities_provider.dart';

class OpportunityApplicationsScreen extends ConsumerWidget {
  final String opportunityId;

  const OpportunityApplicationsScreen({super.key, required this.opportunityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationsAsync = ref.watch(applicationsProvider);
    final opportunity = ref
        .watch(opportunitiesProvider)
        .value
        ?.where((o) => o.id == opportunityId)
        .firstOrNull;
    final title = opportunity?.title ?? 'Casting call';

    return Scaffold(
      appBar: AppBar(title: Text('Applications: $title')),
      body: AsyncBody<List<JobApplication>>(
        value: applicationsAsync,
        errorMessage: 'Could not load applications',
        onRetry: () => ref.invalidate(applicationsProvider),
        data: (all) {
          final items =
              all.where((a) => a.opportunityId == opportunityId).toList();
          if (items.isEmpty) {
            return const EmptyState(
              message: 'No one has applied to this casting call yet',
              icon: Icons.assignment_outlined,
            );
          }
          return RefreshIndicator(
            color: AppColors.gold,
            onRefresh: () => ref.refresh(applicationsProvider.future),
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