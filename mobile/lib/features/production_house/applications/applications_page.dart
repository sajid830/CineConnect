
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cineconnect/app/theme.dart';
import 'package:cineconnect/features/production_house/data/models/application.dart';
import 'package:cineconnect/core/services/realtime_events_service.dart';
import 'package:cineconnect/core/utils/formatters.dart';
import 'package:cineconnect/features/production_house/data/models/opportunity.dart';
import 'package:cineconnect/shared/widgets/async_body.dart';
import 'package:cineconnect/shared/widgets/empty_state.dart';
import 'package:cineconnect/features/production_house/opportunities/opportunities_provider.dart';
import 'application_card.dart';
import 'applications_provider.dart';

class ApplicationsPage extends ConsumerStatefulWidget {
  const ApplicationsPage({super.key});

  @override
  ConsumerState<ApplicationsPage> createState() =>
      _ApplicationsPageState();
}

class _ApplicationsPageState extends ConsumerState<ApplicationsPage> {
  Timer? _liveSyncTimer;
  StreamSubscription<Map<String, dynamic>>? _realtimeSub;

  @override
  void initState() {
    super.initState();

    final realtime = ref.read(realtimeEventsServiceProvider);
    realtime.connect();

    _realtimeSub = realtime.releaseOrApplicationEventsStream.listen((data) {
      if (!mounted) return;

      final event = data['event']?.toString() ?? '';

      if (event.startsWith('application_') ||
          event.startsWith('opportunity_')) {
        ref.invalidate(applicationsProvider);
        ref.invalidate(opportunitiesProvider);
      }
    });

    _liveSyncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      ref.invalidate(applicationsProvider);
      ref.invalidate(opportunitiesProvider);
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _liveSyncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(applicationFilterProvider);
    final notifier = ref.read(applicationFilterProvider.notifier);
    final applicationsAsync = ref.watch(filteredApplicationsProvider);

    final opportunities = ref.watch(opportunitiesProvider).maybeWhen(
          data: (list) => list,
          orElse: () => <Opportunity>[],
        );

    String opportunityTitle(String id) {
      return opportunities
              .where((o) => o.id == id)
              .map((o) => o.title)
              .firstOrNull ??
          'Unknown casting call';
    }

    final selectedOpportunity =
        opportunities.any((o) => o.id == filter.opportunityId)
            ? filter.opportunityId
            : null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButton<String?>(
              value: selectedOpportunity,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All casting calls'),
                ),
                for (final o in opportunities)
                  DropdownMenuItem<String?>(
                    value: o.id,
                    child: Text(o.title, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: notifier.setOpportunity,
            ),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              _statusChip(
                'All',
                filter.status == null,
                () => notifier.setStatus(null),
              ),
              for (final s in ApplicationStatus.values)
                _statusChip(
                  s.label,
                  filter.status == s,
                  () => notifier.setStatus(s),
                ),
            ],
          ),
        ),
        Expanded(
          child: AsyncBody<List<JobApplication>>(
            value: applicationsAsync,
            errorMessage: 'Could not load applications',
            onRetry: () => ref.invalidate(applicationsProvider),
            data: (items) {
              if (items.isEmpty) {
                return const EmptyState(
                  message: 'No applications here yet',
                  icon: Icons.assignment_outlined,
                );
              }
              return RefreshIndicator(
                color: AppColors.gold,
                onRefresh: () => ref.refresh(applicationsProvider.future),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final a = items[index];
                    return ApplicationCard(
                      application: a,
                      opportunityTitle: opportunityTitle(a.opportunityId),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _statusChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: AppColors.gold,
        labelStyle: TextStyle(
          color: selected ? AppColors.black : AppColors.textPrimary,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }
}
