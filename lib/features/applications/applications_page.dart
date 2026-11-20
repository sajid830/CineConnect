import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/application.dart';
import '../../data/models/opportunity.dart';
import '../../shared/widgets/async_body.dart';
import '../../shared/widgets/empty_state.dart';
import '../opportunities/opportunities_provider.dart';
import 'application_card.dart';
import 'applications_provider.dart';

class ApplicationsPage extends ConsumerWidget {
  const ApplicationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
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