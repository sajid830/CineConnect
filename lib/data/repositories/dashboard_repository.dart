import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/application.dart';
import '../models/dashboard_summary.dart';
import '../models/opportunity.dart';
import '../models/project.dart';
import 'application_repository.dart';
import 'opportunity_repository.dart';
import 'project_repository.dart';

abstract class DashboardRepository {
  Future<DashboardSummary> getSummary();
}

/// The real backend returns these numbers from one endpoint. The mock
/// works them out from the other mock repositories, so what Home shows
/// always matches the other tabs.
class MockDashboardRepository implements DashboardRepository {
  final ProjectRepository _projects;
  final OpportunityRepository _opportunities;
  final ApplicationRepository _applications;

  MockDashboardRepository(this._projects, this._opportunities, this._applications);

  @override
  Future<DashboardSummary> getSummary() async {
    await Future.delayed(const Duration(milliseconds: 600));
    final projects = await _projects.getProjects();
    final opportunities = await _opportunities.getOpportunities();
    final applications = await _applications.getApplications();

    final recent = List.of(applications)
      ..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));

    return DashboardSummary(
      activeProjects:
          projects.where((p) => p.status != ProjectStatus.completed).length,
      openCastingCalls:
          opportunities.where((o) => o.status == OpportunityStatus.open).length,
      newApplications:
          applications.where((a) => a.status == ApplicationStatus.received).length,
      shortlisted:
          applications.where((a) => a.status == ApplicationStatus.shortlisted).length,
      recentApplications: recent.take(3).toList(),
    );
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return MockDashboardRepository(
    ref.watch(projectRepositoryProvider),
    ref.watch(opportunityRepositoryProvider),
    ref.watch(applicationRepositoryProvider),
  );
});