import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
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

class RemoteDashboardRepository implements DashboardRepository {
  final ApiClient _client;
  final ApplicationRepository _applications;

  RemoteDashboardRepository({ApiClient? client, ApplicationRepository? applications})
      : _client = client ?? ApiClient(),
        _applications = applications ?? RemoteApplicationRepository();

  @override
  Future<DashboardSummary> getSummary() async {
    try {
      final res = await _client.get(ApiEndpoints.productionHouseDashboard);
      if (res is Map<String, dynamic>) {
        final activeProjects = (res['active_projects'] as num?)?.toInt() ?? 0;
        final openCasting = ((res['open_casting_calls'] ?? res['open_opportunities']) as num?)?.toInt() ?? 0;
        final newApps = ((res['new_applications'] ?? res['pending_reviews']) as num?)?.toInt() ?? 0;
        final shortlisted = (res['shortlisted'] as num?)?.toInt() ?? 0;

        List<JobApplication> recent = [];
        if (res['recent_applications'] is List && (res['recent_applications'] as List).isNotEmpty) {
          recent = (res['recent_applications'] as List)
              .whereType<Map<String, dynamic>>()
              .map(JobApplication.fromJson)
              .toList();
        } else {
          final allApps = await _applications.getApplications();
          recent = List.of(allApps)..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
          recent = recent.take(3).toList();
        }

        return DashboardSummary(
          activeProjects: activeProjects,
          openCastingCalls: openCasting,
          newApplications: newApps,
          shortlisted: shortlisted,
          recentApplications: recent,
        );
      }
    } catch (_) {
      // Fall through to fallback
    }

    final allApps = await _applications.getApplications();
    final recent = List.of(allApps)..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
    return DashboardSummary(
      activeProjects: 0,
      openCastingCalls: 0,
      newApplications: 0,
      shortlisted: 0,
      recentApplications: recent.take(3).toList(),
    );
  }
}

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
  const useMock = bool.fromEnvironment('USE_MOCK_PH', defaultValue: true);
  if (useMock) {
    return MockDashboardRepository(
      ref.watch(projectRepositoryProvider),
      ref.watch(opportunityRepositoryProvider),
      ref.watch(applicationRepositoryProvider),
    );
  }
  return RemoteDashboardRepository(
    applications: ref.watch(applicationRepositoryProvider),
  );
});