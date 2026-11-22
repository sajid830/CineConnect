import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/collaboration.dart';
import 'talent_repository.dart';

class AlreadyInvitedException implements Exception {
  const AlreadyInvitedException();
}

abstract class CollaborationRepository {
  Future<List<Collaboration>> getCollaborations();

  Future<void> invite({required String projectId, required String talentId});

  Future<void> remove(String id);
}

class _CollabRecord {
  final String id;
  final String projectId;
  final String talentId;
  final CollaborationStatus status;
  final DateTime invitedAt;

  const _CollabRecord({
    required this.id,
    required this.projectId,
    required this.talentId,
    required this.status,
    required this.invitedAt,
  });
}

class MockCollaborationRepository implements CollaborationRepository {
  final TalentRepository _talentRepository;

  MockCollaborationRepository(this._talentRepository);

  final List<_CollabRecord> _records = [
    _CollabRecord(
      id: 'c1',
      projectId: 'p1',
      talentId: 't3',
      status: CollaborationStatus.accepted,
      invitedAt: DateTime(2026, 10, 2),
    ),
    _CollabRecord(
      id: 'c2',
      projectId: 'p1',
      talentId: 't8',
      status: CollaborationStatus.accepted,
      invitedAt: DateTime(2026, 11, 13),
    ),
    _CollabRecord(
      id: 'c3',
      projectId: 'p1',
      talentId: 't7',
      status: CollaborationStatus.declined,
      invitedAt: DateTime(2026, 10, 20),
    ),
    _CollabRecord(
      id: 'c4',
      projectId: 'p2',
      talentId: 't4',
      status: CollaborationStatus.invited,
      invitedAt: DateTime(2026, 11, 15),
    ),
  ];

  @override
  Future<List<Collaboration>> getCollaborations() async {
    await Future.delayed(const Duration(milliseconds: 600));
    final result = await Future.wait(
      _records.map((r) async {
        final talent = await _talentRepository.getTalent(r.talentId);
        return Collaboration(
          id: r.id,
          projectId: r.projectId,
          status: r.status,
          invitedAt: r.invitedAt,
          talent: talent,
        );
      }),
    );
    result.sort((a, b) => b.invitedAt.compareTo(a.invitedAt));
    return result;
  }

  @override
  Future<void> invite({
    required String projectId,
    required String talentId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));
    final exists = _records.any(
      (r) => r.projectId == projectId && r.talentId == talentId,
    );
    if (exists) throw const AlreadyInvitedException();
    _records.add(
      _CollabRecord(
        id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
        projectId: projectId,
        talentId: talentId,
        status: CollaborationStatus.invited,
        invitedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> remove(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _records.removeWhere((r) => r.id == id);
  }
}

final collaborationRepositoryProvider = Provider<CollaborationRepository>((ref) {
  return MockCollaborationRepository(ref.watch(talentRepositoryProvider));
});
