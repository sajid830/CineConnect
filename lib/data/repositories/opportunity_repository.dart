import 'package:flutter_riverpod/flutter_riverpod.dart';
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

final opportunityRepositoryProvider = Provider<OpportunityRepository>((ref) {
  return MockOpportunityRepository();
});