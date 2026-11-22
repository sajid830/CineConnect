import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cineconnect/features/production_house/data/models/opportunity.dart';
import 'package:cineconnect/features/production_house/data/repositories/opportunity_repository.dart';

class OpportunitiesNotifier extends AsyncNotifier<List<Opportunity>> {
  @override
  Future<List<Opportunity>> build() {
    return ref.read(opportunityRepositoryProvider).getOpportunities();
  }

  Future<void> add({
    required String projectId,
    required String title,
    required String requirements,
    required DateTime deadline,
  }) async {
    await ref.read(opportunityRepositoryProvider).createOpportunity(
          projectId: projectId,
          title: title,
          requirements: requirements,
          deadline: deadline,
        );
    ref.invalidateSelf();
    await future;
  }

  Future<void> edit({
    required String id,
    required String projectId,
    required String title,
    required String requirements,
    required DateTime deadline,
  }) async {
    await ref.read(opportunityRepositoryProvider).updateOpportunity(
          id: id,
          projectId: projectId,
          title: title,
          requirements: requirements,
          deadline: deadline,
        );
    ref.invalidateSelf();
    await future;
  }

  Future<void> setStatus(String id, OpportunityStatus status) async {
    await ref.read(opportunityRepositoryProvider).updateStatus(id, status);
    ref.invalidateSelf();
    await future;
  }

  Future<void> remove(String id) async {
    await ref.read(opportunityRepositoryProvider).deleteOpportunity(id);
    ref.invalidateSelf();
    await future;
  }
}

final opportunitiesProvider =
    AsyncNotifierProvider<OpportunitiesNotifier, List<Opportunity>>(
  OpportunitiesNotifier.new,
);