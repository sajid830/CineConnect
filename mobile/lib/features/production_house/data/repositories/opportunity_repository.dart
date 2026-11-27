import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/opportunity.dart';

abstract class OpportunityRepository {
  Future<List<Opportunity>> getOpportunities();

  Future<Opportunity> createOpportunity({
    String? projectId,
    required String title,
    String? roleType,
    String? purpose,
    int requiredMembers = 1,
    DateTime? workStartDate,
    String? experience,
    required String requirements,
    required DateTime deadline,
  });

  Future<void> updateOpportunity({
    required String id,
    String? projectId,
    required String title,
    String? roleType,
    String? purpose,
    int? requiredMembers,
    DateTime? workStartDate,
    String? experience,
    required String requirements,
    required DateTime deadline,
  });

  Future<void> updateStatus(String id, OpportunityStatus status);

  Future<void> deleteOpportunity(String id);
}

class MockOpportunityRepository implements OpportunityRepository {
  final List<Opportunity> _items = [];

  @override
  Future<List<Opportunity>> getOpportunities() async {
    return List.of(_items);
  }

  @override
  Future<Opportunity> createOpportunity({
    String? projectId,
    required String title,
    String? roleType,
    String? purpose,
    int requiredMembers = 1,
    DateTime? workStartDate,
    String? experience,
    required String requirements,
    required DateTime deadline,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final item = Opportunity(
      id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
      projectId: projectId,
      title: title,
      roleType: roleType,
      purpose: purpose,
      requiredMembers: requiredMembers,
      workStartDate: workStartDate,
      experience: experience,
      requirements: requirements,
      deadline: deadline,
      status: OpportunityStatus.open,
    );
    _items.insert(0, item);
    return item;
  }

  @override
  Future<void> updateOpportunity({
    required String id,
    String? projectId,
    required String title,
    String? roleType,
    String? purpose,
    int? requiredMembers,
    DateTime? workStartDate,
    String? experience,
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
      roleType: roleType ?? _items[index].roleType,
      purpose: purpose ?? _items[index].purpose,
      requiredMembers: requiredMembers ?? _items[index].requiredMembers,
      workStartDate: workStartDate ?? _items[index].workStartDate,
      experience: experience ?? _items[index].experience,
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
      roleType: old.roleType,
      purpose: old.purpose,
      requiredMembers: old.requiredMembers,
      workStartDate: old.workStartDate,
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
        return [];
      }
      rethrow;
    } catch (e) {
      throw ApiException(statusCode: 0, message: 'Failed to load jobs: $e');
    }
  }

  @override
  Future<Opportunity> createOpportunity({
    String? projectId,
    required String title,
    String? roleType,
    String? purpose,
    int requiredMembers = 1,
    DateTime? workStartDate,
    String? experience,
    required String requirements,
    required DateTime deadline,
  }) async {
    final deadlineStr = deadline.toIso8601String().split('T').first;
    final workStartStr = workStartDate?.toIso8601String().split('T').first;
    final body = {
      if (projectId != null && projectId.isNotEmpty) 'project_id': projectId,
      'title': title,
      'role_type': roleType ?? title,
      if (purpose != null && purpose.isNotEmpty) 'purpose': purpose,
      'required_members': requiredMembers,
      if (workStartStr != null) 'work_start_date': workStartStr,
      if (experience != null && experience.isNotEmpty) 'experience': experience,
      'requirements': requirements,
      'deadline': deadlineStr,
      'status': 'open',
    };

    final res = await _client.post(ApiEndpoints.opportunities, body: body);
    if (res is Map) {
      return Opportunity.fromJson(Map<String, dynamic>.from(res));
    }
    throw ApiException(
      statusCode: 500,
      message: 'Invalid response from server on job creation',
    );
  }

  @override
  Future<void> updateOpportunity({
    required String id,
    String? projectId,
    required String title,
    String? roleType,
    String? purpose,
    int? requiredMembers,
    DateTime? workStartDate,
    String? experience,
    required String requirements,
    required DateTime deadline,
  }) async {
    final deadlineStr = deadline.toIso8601String().split('T').first;
    final workStartStr = workStartDate?.toIso8601String().split('T').first;
    final body = {
      'title': title,
      if (roleType != null) 'role_type': roleType,
      if (purpose != null) 'purpose': purpose,
      if (requiredMembers != null) 'required_members': requiredMembers,
      if (workStartStr != null) 'work_start_date': workStartStr,
      if (experience != null) 'experience': experience,
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
  return RemoteOpportunityRepository();
});