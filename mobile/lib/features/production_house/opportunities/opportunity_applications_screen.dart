
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cineconnect/app/theme.dart';
import 'package:cineconnect/core/services/realtime_events_service.dart';
import 'package:cineconnect/features/production_house/data/models/application.dart';
import 'package:cineconnect/shared/widgets/async_body.dart';
import 'package:cineconnect/shared/widgets/empty_state.dart';
import 'package:cineconnect/features/production_house/applications/application_card.dart';
import 'package:cineconnect/features/production_house/applications/applications_provider.dart';
import 'opportunities_provider.dart';

class OpportunityApplicationsScreen extends ConsumerStatefulWidget {
  final String opportunityId;

  const OpportunityApplicationsScreen({
    super.key,
    required this.opportunityId,
  });

  @override
  ConsumerState<OpportunityApplicationsScreen> createState() =>
      _OpportunityApplicationsScreenState();
}

class _OpportunityApplicationsScreenState
    extends ConsumerState<OpportunityApplicationsScreen> {
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
      final opportunityId = data['opportunity_id']?.toString();

      if (event.startsWith('application_') &&
          (opportunityId == null ||
              opportunityId == widget.opportunityId)) {
        ref.invalidate(applicationsProvider);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.invalidate(applicationsProvider);
      }
    });

    // Refresh periodically if realtime events are unavailable.
    _liveSyncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      ref.invalidate(applicationsProvider);
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
    final applicationsAsync = ref.watch(applicationsProvider);

    final opportunity = ref
        .watch(opportunitiesProvider)
        .valueOrNull
        ?.where((o) => o.id == widget.opportunityId)
        .firstOrNull;

    final title = opportunity?.title ?? 'Casting call';

    return Scaffold(
      appBar: AppBar(
        title: Text('Applications: $title'),
      ),
      body: AsyncBody<List<JobApplication>>(
        value: applicationsAsync,
        errorMessage: 'Could not load applications',
        onRetry: () => ref.invalidate(applicationsProvider),
        data: (all) {
          final items = all
              .where((a) => a.opportunityId == widget.opportunityId)
              .toList();

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
