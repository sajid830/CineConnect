import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cineconnect/app/theme.dart';
import 'package:cineconnect/features/production_house/data/models/dashboard_summary.dart';
import 'package:cineconnect/shared/widgets/app_card.dart';
import 'package:cineconnect/shared/widgets/async_body.dart';
import 'package:cineconnect/features/production_house/applications/application_card.dart';
import 'package:cineconnect/features/production_house/opportunities/opportunities_provider.dart';
import 'home_provider.dart';

/// Tab positions in the dashboard's bottom bar.
const kProjectsTab = 1;
const kCastingTab = 2;
const kApplicationsTab = 3;

class HomePage extends ConsumerWidget {
  final void Function(int tabIndex) onOpenTab;

  const HomePage({super.key, required this.onOpenTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final opportunities = ref.watch(opportunitiesProvider).value ?? const [];

    String opportunityTitle(String id) =>
        opportunities.where((o) => o.id == id).map((o) => o.title).firstOrNull ??
        'Casting call';

    return AsyncBody<DashboardSummary>(
      value: summaryAsync,
      errorMessage: 'Could not load your summary',
      onRetry: () => ref.invalidate(dashboardSummaryProvider),
      data: (s) => RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () => ref.refresh(dashboardSummaryProvider.future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Welcome back',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Here is where things stand today.',
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.movie_creation_outlined,
                    value: s.activeProjects,
                    label: 'Active projects',
                    onTap: () => onOpenTab(kProjectsTab),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.campaign_outlined,
                    value: s.openCastingCalls,
                    label: 'Open casting calls',
                    onTap: () => onOpenTab(kCastingTab),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.mark_email_unread_outlined,
                    value: s.newApplications,
                    label: 'New applications',
                    onTap: () => onOpenTab(kApplicationsTab),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.star_outline,
                    value: s.shortlisted,
                    label: 'Shortlisted',
                    onTap: () => onOpenTab(kApplicationsTab),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Recent applications',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () => onOpenTab(kApplicationsTab),
                  child: const Text('See all'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (s.recentApplications.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No applications yet. Publish a casting call to start receiving them.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              )
            else
              for (final a in s.recentApplications) ...[
                ApplicationCard(
                  application: a,
                  opportunityTitle: opportunityTitle(a.opportunityId),
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.gold),
          const SizedBox(height: 12),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}