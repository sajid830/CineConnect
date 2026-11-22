import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cineconnect/features/production_house/data/models/collaboration.dart';
import 'package:cineconnect/features/production_house/data/repositories/collaboration_repository.dart';

class CollaborationsNotifier extends AsyncNotifier<List<Collaboration>> {
  @override
  Future<List<Collaboration>> build() {
    return ref.read(collaborationRepositoryProvider).getCollaborations();
  }

  Future<void> invite({
    required String projectId,
    required String talentId,
  }) async {
    await ref
        .read(collaborationRepositoryProvider)
        .invite(projectId: projectId, talentId: talentId);
    ref.invalidateSelf();
    await future;
  }

  Future<void> remove(String id) async {
    await ref.read(collaborationRepositoryProvider).remove(id);
    ref.invalidateSelf();
    await future;
  }
}

final collaborationsProvider =
    AsyncNotifierProvider<CollaborationsNotifier, List<Collaboration>>(
  CollaborationsNotifier.new,
);