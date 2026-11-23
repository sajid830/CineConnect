import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/opportunity.dart';

abstract class OpportunityRepository {
  Future<List<Opportunity>> getOpportunities();

  Future<Opportunity> createOpportunity({
    required String projectId,
    required String title,
    required String requirements,
    required DateTime deadline,
  });

  Future<void> updateOpportunity({
    required String id,
    required String projectId,
    required String title,
    required String requirements,
    required DateTime deadline,
  });

  Future<void> updateStatus(String id, OpportunityStatus status);

  Future<void> deleteOpportunity(String id);
}

class MockOpportunityRepository implements OpportunityRepository {
  final List<Opportunity> _items = [
    Opportunity(
      id: 'o1',
      projectId: 'p1',
      title: 'Lead Actress (25-32)',
      requirements:
          'Fluent in Hindi and English. Action sequences experience preferred.',
      deadline: DateTime(2026, 12, 20),
      status: OpportunityStatus.open,
    ),
    Opportunity(
      id: 'o2',
      projectId: 'p2',
      title: 'Cinematographer',
      requirements: '5+ years of experience. Showreel required.',
      deadline: DateTime(2027, 1, 5),
      status: OpportunityStatus.open,
    ),
  ];

  @override
  Future<List<Opportunity>> getOpportunities() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return List.of(_items);
  }

  @override
  Future<Opportunity> createOpportunity({
    required String projectId,
    required String title,
    required String requirements,
    required DateTime deadline,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final item = Opportunity(
      id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
      projectId: projectId,
      title: title,
      requirements: requirements,
      deadline: deadline,
      status: OpportunityStatus.draft,
    );
    _items.insert(0, item);
    return item;
  }

  @override
  Future<void> updateOpportunity({
    required String id,
    required String projectId,
    required String title,
    required String requirements,
    required DateTime deadline,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));
    final index = _items.indexWhere((o) => o.id == id);
    if (index == -1) return;
    _items[index] = Opportunity(
      id: id,
      projectId: projectId,
      title: title,
      requirements: requirements,
      deadline: deadline,
      status: _items[index].status,
    );
  }

  @override
  Future<void> updateStatus(String id, OpportunityStatus status) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _items.indexWhere((o) => o.id == id);
    if (index == -1) return;
    final old = _items[index];
    _items[index] = Opportunity(
      id: old.id,
      projectId: old.projectId,
      title: old.title,
      requirements: old.requirements,
      deadline: old.deadline,
      status: status,
    );
  }

  @override
  Future<void> deleteOpportunity(String id) async {
    await Future.delayed(const Duration(milliseconds: 600));
    _items.removeWhere((o) => o.id == id);
  }
}

class RemoteOpportunityRepository implements OpportunityRepository {
  final ApiClient _client;

  RemoteOpportunityRepository({ApiClient? client}) : _client = client ?? ApiClient();

  @override
  Future<List<Opportunity>> getOpportunities() async {
    try {
      final res = await _client.get(ApiEndpoints.myOpportunities);
      if (res is List) {
        return res.map((item) {
          if (item is Map) {
            return Opportunity.fromJson(Map<String, dynamic>.from(item));
          }
          throw const FormatException('Expected opportunity item to be a map');
        }).toList();
      }
      return [];
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        // Production house profile not found or no opportunities yet
        return [];
      }
      rethrow;
    } catch (e) {
      throw ApiException(statusCode: 0, message: 'Failed to load casting calls: $e');
    }
  }

  @override
  Future<Opportunity> createOpportunity({
    required String projectId,
    required String title,
    required String requirements,
    required DateTime deadline,
  }) async {
    final deadlineStr = deadline.toIso8601String().split('T').first;
    final body = {
      'project_id': projectId,
      'title': title,
      'requirements': requirements,
      'deadline': deadlineStr,
      'status': 'draft',
    };

    final res = await _client.post(ApiEndpoints.opportunities, body: body);
    if (res is Map) {
      return Opportunity.fromJson(Map<String, dynamic>.from(res));
    }
    throw ApiException(
      statusCode: 500,
      message: 'Invalid response from server on casting call creation',
    );
  }

  @override
  Future<void> updateOpportunity({
    required String id,
    required String projectId,
    required String title,
    required String requirements,
    required DateTime deadline,
  }) async {
    final deadlineStr = deadline.toIso8601String().split('T').first;
    final body = {
      'title': title,
      'requirements': requirements,
      'deadline': deadlineStr,
    };

    await _client.patch(ApiEndpoints.opportunityDetails(id), body: body);
  }

  @override
  Future<void> updateStatus(String id, OpportunityStatus status) async {
    final backendStatus = Opportunity.toBackendStatus(status);
    await _client.patch(
      ApiEndpoints.opportunityStatus(id),
      body: {'status': backendStatus},
    );
  }

  @override
  Future<void> deleteOpportunity(String id) async {
    await _client.delete(ApiEndpoints.opportunityDetails(id));
  }

  /// Optional helper to fetch single opportunity details by UUID
  Future<Opportunity?> getOpportunityById(String id) async {
    try {
      final res = await _client.get(ApiEndpoints.opportunityDetails(id));
      if (res is Map) {
        return Opportunity.fromJson(Map<String, dynamic>.from(res));
      }
      return null;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }
}

final opportunityRepositoryProvider = Provider<OpportunityRepository>((ref) {
  const useMock = bool.fromEnvironment('USE_MOCK_PH', defaultValue: true);
  return useMock ? MockOpportunityRepository() : RemoteOpportunityRepository();
});