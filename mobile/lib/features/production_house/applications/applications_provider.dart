import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cineconnect/features/production_house/data/models/application.dart';
import 'package:cineconnect/features/production_house/data/repositories/application_repository.dart';

class ApplicationsNotifier extends AsyncNotifier<List<JobApplication>> {
  @override
  Future<List<JobApplication>> build() {
    return ref.read(applicationRepositoryProvider).getApplications();
  }

  Future<void> setStatus(String id, ApplicationStatus status) async {
    await ref.read(applicationRepositoryProvider).updateStatus(id, status);
    ref.invalidateSelf();
    await future;
  }
}

final applicationsProvider =
    AsyncNotifierProvider<ApplicationsNotifier, List<JobApplication>>(
  ApplicationsNotifier.new,
);

final projectApplicationsProvider =
    FutureProvider.family<List<JobApplication>, String>((ref, projectId) async {
  return ref.read(applicationRepositoryProvider).getApplicationsForProject(projectId);
});

final opportunityApplicationsProvider =
    FutureProvider.family<List<JobApplication>, String>((ref, oppId) async {
  return ref.read(applicationRepositoryProvider).getApplicationsForOpportunity(oppId);
});

typedef ApplicationFilter = ({ApplicationStatus? status, String? opportunityId});

class ApplicationFilterNotifier extends Notifier<ApplicationFilter> {
  @override
  ApplicationFilter build() => (status: null, opportunityId: null);

  void setStatus(ApplicationStatus? status) {
    state = (status: status, opportunityId: state.opportunityId);
  }

  void setOpportunity(String? opportunityId) {
    state = (status: state.status, opportunityId: opportunityId);
  }
}

final applicationFilterProvider =
    NotifierProvider<ApplicationFilterNotifier, ApplicationFilter>(
  ApplicationFilterNotifier.new,
);

final filteredApplicationsProvider =
    Provider<AsyncValue<List<JobApplication>>>((ref) {
  final filter = ref.watch(applicationFilterProvider);
  return ref.watch(applicationsProvider).whenData(
        (list) => list.where((a) {
          final matchesStatus =
              filter.status == null || a.status == filter.status;
          final matchesOpportunity = filter.opportunityId == null ||
              a.opportunityId == filter.opportunityId;
          return matchesStatus && matchesOpportunity;
        }).toList(),
      );
});