import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cineconnect/features/production_house/data/models/dashboard_summary.dart';
import 'package:cineconnect/features/production_house/data/repositories/dashboard_repository.dart';
import 'package:cineconnect/features/production_house/applications/applications_provider.dart';
import 'package:cineconnect/features/production_house/opportunities/opportunities_provider.dart';
import 'package:cineconnect/features/production_house/projects/projects_provider.dart';

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) {
  // Watching these makes the summary reload when any of them changes,
  // so the counts never go stale while the app is open.
  ref.watch(projectsProvider);
  ref.watch(opportunitiesProvider);
  ref.watch(applicationsProvider);
  return ref.read(dashboardRepositoryProvider).getSummary();
});