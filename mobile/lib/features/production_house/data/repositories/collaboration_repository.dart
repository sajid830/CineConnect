import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/collaboration.dart';
import 'talent_repository.dart';

class AlreadyInvitedException implements Exception {
  final String message;
  const AlreadyInvitedException([this.message = 'Talent is already invited or part of this project.']);

  @override
  String toString() => message;
}

abstract class CollaborationRepository {
  Future<List<Collaboration>> getCollaborations();

  Future<void> invite({
    required String projectId,
    required String talentId,
    String? role,
  });

  Future<void> remove(String id);

  Future<void> updateStatus({
    required String id,
    required String status,
  });

  Future<void> accept(String id);

  Future<void> reject(String id);
}

class RemoteCollaborationRepository implements CollaborationRepository {
  final ApiClient _client;

  RemoteCollaborationRepository({ApiClient? client})
      : _client = client ?? ApiClient();

  @override
  Future<List<Collaboration>> getCollaborations() async {
    final res = await _client.get(
      ApiEndpoints.myCollaborations,
      queryParams: {'limit': 100},
    );

    if (res is List) {
      final Map<String, Collaboration> deduplicated = {};
      for (final item in res) {
        if (item is Map) {
          try {
            final collab = Collaboration.fromJson(Map<String, dynamic>.from(item));
            if (collab.id.isNotEmpty) {
              deduplicated[collab.id] = collab;
            }
          } catch (_) {
            // Gracefully skip malformed entry
          }
        }
      }
      final list = deduplicated.values.toList();
      list.sort((a, b) => b.invitedAt.compareTo(a.invitedAt));
      return list;
    }
    return [];
  }

  @override
  Future<void> invite({
    required String projectId,
    required String talentId,
    String? role,
  }) async {
    try {
      final body = <String, dynamic>{
        'project_id': projectId,
        'talent_id': talentId,
        if (role != null && role.isNotEmpty) 'role': role,
      };
      await _client.post(ApiEndpoints.collaborationsCollection, body: body);
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        throw const AlreadyInvitedException();
      }
      rethrow;
    }
  }

  @override
  Future<void> remove(String id) async {
    await _client.delete(ApiEndpoints.collaborationDetails(id));
  }

  @override
  Future<void> updateStatus({
    required String id,
    required String status,
  }) async {
    await _client.patch(
      ApiEndpoints.updateCollaborationStatus(id),
      body: {'status': status},
    );
  }

  @override
  Future<void> accept(String id) async {
    await _client.patch(ApiEndpoints.acceptCollaboration(id));
  }

  @override
  Future<void> reject(String id) async {
    await _client.patch(ApiEndpoints.rejectCollaboration(id));
  }
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

  final List<_CollabRecord> _records = [];

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
    String? role,
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

  @override
  Future<void> updateStatus({
    required String id,
    required String status,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _records.indexWhere((r) => r.id == id);
    if (index != -1) {
      final old = _records[index];
      _records[index] = _CollabRecord(
        id: old.id,
        projectId: old.projectId,
        talentId: old.talentId,
        status: CollaborationStatus.fromApi(status),
        invitedAt: old.invitedAt,
      );
    }
  }

  @override
  Future<void> accept(String id) async {
    await updateStatus(id: id, status: 'accepted');
  }

  @override
  Future<void> reject(String id) async {
    await updateStatus(id: id, status: 'declined');
  }
}

final collaborationRepositoryProvider = Provider<CollaborationRepository>((ref) {
  return RemoteCollaborationRepository();
});

